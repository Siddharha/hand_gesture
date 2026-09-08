import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'hand_pipeline.dart';

/// Runs a [HandPipeline] on its own isolate.
///
/// Inference and the YUV sampling that feeds it are the two things that would
/// otherwise stall the UI thread for tens of milliseconds a frame, so both live
/// here. The interpreters are built inside the isolate from model bytes —
/// a native interpreter handle cannot be shared across isolates.
///
/// One frame is processed at a time: [process] returns null when the pipeline
/// is still busy, which is how frames get dropped rather than queued.
class HandPipelineIsolate {
  HandPipelineIsolate._(this._isolate, this._commands, this._responses);

  final Isolate _isolate;
  final SendPort _commands;
  final ReceivePort _responses;

  Completer<HandPipelineResult>? _pending;
  bool _closed = false;

  bool get isBusy => _pending != null;

  /// Spawns the isolate and waits until the models are loaded.
  static Future<HandPipelineIsolate> spawn({
    required Uint8List detectorModel,
    required Uint8List landmarkModel,
    HandPipelineConfig config = const HandPipelineConfig(),
  }) async {
    final responses = ReceivePort();
    final isolate = await Isolate.spawn(
      _entryPoint,
      _StartMessage(
        replyTo: responses.sendPort,
        detectorModel: detectorModel,
        landmarkModel: landmarkModel,
        config: config,
      ),
      debugName: 'hand-pipeline',
    );

    final stream = responses.asBroadcastStream();
    final ready = await stream.first;

    if (ready is _ErrorMessage) {
      isolate.kill(priority: Isolate.immediate);
      responses.close();
      throw StateError('Hand pipeline failed to start: ${ready.message}');
    }

    final pipeline = HandPipelineIsolate._(isolate, ready as SendPort, responses);
    stream.listen(pipeline._onResponse);
    return pipeline;
  }

  /// Sends a frame for analysis, or returns null if the previous one is still
  /// in flight. Dropping is deliberate: a queue would only add latency.
  Future<HandPipelineResult>? process(HandPipelineFrame frame) {
    if (_closed || _pending != null) return null;

    final completer = Completer<HandPipelineResult>();
    _pending = completer;
    _commands.send(_FrameMessage(frame));
    return completer.future;
  }

  /// Drops tracking state so the next frame re-runs the palm detector.
  void resetTracking() {
    if (!_closed) _commands.send(const _ResetMessage());
  }

  void _onResponse(dynamic message) {
    final pending = _pending;
    _pending = null;
    if (pending == null) return;

    switch (message) {
      case HandPipelineResult result:
        pending.complete(result);
      case _ErrorMessage error:
        pending.completeError(StateError(error.message), error.stackTrace);
      default:
        pending.completeError(
          StateError('Unexpected pipeline response: $message'),
        );
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;

    _commands.send(const _CloseMessage());
    // Let the isolate release its interpreters before it is torn down.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    _pending?.completeError(StateError('Hand pipeline closed.'));
    _pending = null;
    _responses.close();
    _isolate.kill(priority: Isolate.beforeNextEvent);
  }

  static Future<void> _entryPoint(_StartMessage start) async {
    final HandPipeline pipeline;
    try {
      pipeline = HandPipeline.fromBuffers(
        detectorModel: start.detectorModel,
        landmarkModel: start.landmarkModel,
        config: start.config,
      );
    } catch (error, stackTrace) {
      start.replyTo.send(_ErrorMessage('$error', stackTrace));
      return;
    }

    final commands = ReceivePort();
    start.replyTo.send(commands.sendPort);

    await for (final message in commands) {
      switch (message) {
        case _FrameMessage(:final frame):
          try {
            start.replyTo.send(pipeline.process(frame));
          } catch (error, stackTrace) {
            start.replyTo.send(_ErrorMessage('$error', stackTrace));
          }
        case _ResetMessage():
          pipeline.resetTracking();
        case _CloseMessage():
          pipeline.close();
          commands.close();
      }
    }
  }
}

class _StartMessage {
  const _StartMessage({
    required this.replyTo,
    required this.detectorModel,
    required this.landmarkModel,
    required this.config,
  });

  final SendPort replyTo;
  final Uint8List detectorModel;
  final Uint8List landmarkModel;
  final HandPipelineConfig config;
}

class _FrameMessage {
  const _FrameMessage(this.frame);

  final HandPipelineFrame frame;
}

class _ResetMessage {
  const _ResetMessage();
}

class _CloseMessage {
  const _CloseMessage();
}

class _ErrorMessage {
  const _ErrorMessage(this.message, [this.stackTrace]);

  final String message;
  final StackTrace? stackTrace;
}

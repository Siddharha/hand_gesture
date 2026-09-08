import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/di/home_di.dart';
import '../../domain/entity/hand_gesture_entity.dart';

/// Opens an alert on an open palm and closes it on a fist.
///
/// A worked example of driving an action from `gestureEventsProvider`: it
/// listens from *outside* the view model, so nothing in the camera pipeline
/// knows this exists, and deleting this widget removes the behaviour entirely.
///
/// The listener lives on a widget that stays mounted behind the dialog, which
/// is what lets a gesture close what a gesture opened — `ref.listen` only fires
/// while its widget is in the tree.
class GestureAlertListener extends ConsumerStatefulWidget {
  const GestureAlertListener({
    super.key,
    required this.child,
    this.openWith = HandGesture.openPalm,
    this.closeWith = HandGesture.fist,
  });

  final Widget child;
  final HandGesture openWith;
  final HandGesture closeWith;

  @override
  ConsumerState<GestureAlertListener> createState() =>
      _GestureAlertListenerState();
}

class _GestureAlertListenerState extends ConsumerState<GestureAlertListener> {
  /// Set the moment the dialog is requested, so a fist arriving in the frame
  /// before it has built cannot open a second one.
  bool _isOpen = false;

  /// The dialog's own context, so it is popped precisely rather than whatever
  /// route happens to be on top.
  BuildContext? _dialogContext;

  @override
  Widget build(BuildContext context) {
    ref.listen(gestureEventsProvider, (previous, next) {
      final event = next.value;
      // Act on the start of a shape only; `ended` fires for the same gesture
      // as the hand moves on, and would immediately undo the action.
      if (event == null || !event.isBegan) return;

      if (event.gesture == widget.openWith) {
        _open();
      } else if (event.gesture == widget.closeWith) {
        _close();
      }
    });

    return widget.child;
  }

  Future<void> _open() async {
    if (_isOpen || !mounted) return;
    _isOpen = true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        _dialogContext = dialogContext;
        return AlertDialog(
          icon: const Icon(Icons.back_hand_outlined, size: 32),
          title: const Text('Open palm detected'),
          content: Text(
            'Make a ${widget.closeWith.label.toLowerCase()} to dismiss this, '
            'or tap outside.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Dismiss'),
            ),
          ],
        );
      },
    );

    // Reached however the dialog closed - by gesture, by the button, by the
    // back button, or by tapping the barrier.
    _isOpen = false;
    _dialogContext = null;
  }

  void _close() {
    if (!_isOpen) return;

    final dialogContext = _dialogContext;
    // Null only in the frame between requesting the dialog and it building; the
    // next matching gesture closes it.
    if (dialogContext == null || !dialogContext.mounted) return;

    Navigator.of(dialogContext).pop();
  }
}

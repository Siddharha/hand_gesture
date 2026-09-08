import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/di/home_di.dart';
import '../viewmodel/home_state.dart';
import '../viewmodel/home_view_model.dart';
import '../widgets/detection_stats_bar.dart';
import '../widgets/gesture_alert_listener.dart';
import '../widgets/gesture_labels.dart';
import '../widgets/hand_overlay_painter.dart';

/// Live camera preview with the hand skeleton drawn over it.
///
/// The view reads state and fires intents; it never touches the pipeline. The
/// one exception is the preview texture, which needs the plugin's controller —
/// see `cameraDataSourceImplProvider`.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static const routeName = '/home';

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Providers must not be mutated during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeViewModelProvider.notifier).start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    final viewModel = ref.read(homeViewModelProvider.notifier);

    // Hand the camera back when we lose the foreground; Android will take it
    // away anyway, and resuming from a dead session is messier than restarting.
    switch (lifecycle) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        viewModel.stop();
      case AppLifecycleState.resumed:
        viewModel.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeViewModelProvider);

    // Wraps the screen rather than sitting inside it: the listener has to stay
    // mounted while the dialog is up, or a gesture could not close it.
    return GestureAlertListener(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _Preview(state: state),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (state.isRunning)
                      DetectionStatsBar(
                        detection: state.detection,
                        analysisFps: state.analysisFps,
                      ),
                    const Spacer(),
                    if (state.isRunning) const _Controls(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Preview extends ConsumerWidget {
  const _Preview({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (state.status) {
      CameraStatus.idle || CameraStatus.starting => const _Centered(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      CameraStatus.permissionDenied => _Message(
          icon: Icons.no_photography_outlined,
          title: 'Camera access needed',
          detail: state.failure?.message ??
              'Grant camera permission in system settings to track hands.',
        ),
      CameraStatus.failure => _Message(
          icon: Icons.error_outline,
          title: 'Something went wrong',
          detail: state.failure?.message ?? 'The camera stopped unexpectedly.',
          onRetry: () => ref.read(homeViewModelProvider.notifier).retry(),
        ),
      CameraStatus.running => _LivePreview(state: state),
    };
  }
}

class _LivePreview extends ConsumerWidget {
  const _LivePreview({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The only place the plugin's controller is touched outside the data layer:
    // a preview is a platform texture and cannot be rendered without it. Reads
    // are driven by state changes, which is why this is not watched directly.
    final controller = ref.read(cameraDataSourceImplProvider).previewController;
    final session = state.session;

    if (controller == null || !controller.value.isInitialized || session == null) {
      return const _Centered(child: CircularProgressIndicator(color: Colors.white));
    }

    final theme = Theme.of(context);

    return Center(
      // Preview and overlay share one box, so normalised landmarks map onto it
      // with a plain multiply.
      child: AspectRatio(
        aspectRatio: session.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(controller),
            if (state.showOverlay) ...[
              CustomPaint(
                painter: HandOverlayPainter(
                  hands: state.detection.hands,
                  leftHandColor: theme.colorScheme.primary,
                  rightHandColor: theme.colorScheme.tertiary,
                  jointColor: Colors.white,
                ),
              ),
              // Inside the same box as the preview, so a label anchored in
              // normalised coordinates lands on its hand.
              GestureLabels(hands: state.detection.hands, poses: state.poses),
            ],
          ],
        ),
      ),
    );
  }
}

class _Controls extends ConsumerWidget {
  const _Controls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.read(homeViewModelProvider.notifier);
    final showOverlay = ref.watch(
      homeViewModelProvider.select((state) => state.showOverlay),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CircleButton(
          icon: showOverlay ? Icons.visibility : Icons.visibility_off,
          tooltip: showOverlay ? 'Hide landmarks' : 'Show landmarks',
          onPressed: viewModel.toggleOverlay,
        ),
        const SizedBox(width: 20),
        _CircleButton(
          icon: Icons.cameraswitch_outlined,
          tooltip: 'Switch camera',
          onPressed: viewModel.switchCamera,
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: _InkCircle(icon: icon, onPressed: onPressed),
      ),
    );
  }
}

class _InkCircle extends StatelessWidget {
  const _InkCircle({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(child: child);
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.detail,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.tonal(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodel/splash_state.dart';
import '../viewmodel/splash_view_model.dart';

/// Intentionally empty screen. It starts the session bootstrap and hands over
/// to whatever route the view model resolves.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  static const routeName = '/';

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Providers must not be mutated during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(splashViewModelProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SplashState>(splashViewModelProvider, (previous, next) {
      if (!next.isReady) return;
      Navigator.of(context).pushReplacementNamed(next.nextRoute!);
    });

    return const Scaffold(body: SizedBox.expand());
  }
}

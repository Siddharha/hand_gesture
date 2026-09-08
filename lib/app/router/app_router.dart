import 'package:flutter/material.dart';

import '../../features/gesture/home/presentation/view/home_screen.dart';
import '../../features/gesture/splash/presentation/view/splash_screen.dart';
import 'app_routes.dart';

/// Maps route names to screens. Each module contributes its own entries here,
/// so no module needs to import another module's widgets.
abstract final class AppRouter {
  static const initialRoute = AppRoutes.splash;

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return switch (settings.name) {
      AppRoutes.splash => _page(const SplashScreen(), settings),
      AppRoutes.home => _page(const HomeScreen(), settings),
      _ => _page(_UnknownRouteScreen(routeName: settings.name), settings),
    };
  }

  static MaterialPageRoute<dynamic> _page(Widget child, RouteSettings settings) =>
      MaterialPageRoute<dynamic>(builder: (_) => child, settings: settings);
}

class _UnknownRouteScreen extends StatelessWidget {
  const _UnknownRouteScreen({this.routeName});

  final String? routeName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(child: Text('No route defined for "${routeName ?? ''}".')),
    );
  }
}

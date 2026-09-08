import 'package:flutter/material.dart';

/// Thin wrapper around [Scaffold] so screens share padding, safe-area and
/// app-bar behaviour instead of each rebuilding it.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title == null ? null : AppBar(title: Text(title!), actions: actions),
      body: SafeArea(child: Padding(padding: padding, child: body)),
      floatingActionButton: floatingActionButton,
    );
  }
}

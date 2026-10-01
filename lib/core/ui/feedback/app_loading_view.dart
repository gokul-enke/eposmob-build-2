import 'package:flutter/material.dart';

import '../layout/app_surface.dart';

/// Spinner inside an [AppSurface] — the loading state for a page body.
class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key, this.useSurface = true});

  final bool useSurface;

  @override
  Widget build(BuildContext context) {
    const spinner = Center(child: CircularProgressIndicator.adaptive());
    if (!useSurface) return spinner;
    return const AppSurface(child: spinner);
  }
}

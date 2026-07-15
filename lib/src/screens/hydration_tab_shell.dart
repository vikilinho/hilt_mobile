import 'package:flutter/material.dart';

import 'hydration_screen.dart';

class HydrationTabShell extends StatelessWidget {
  const HydrationTabShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: HydrationScreen(),
    );
  }
}

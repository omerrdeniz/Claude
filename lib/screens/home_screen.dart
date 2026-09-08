import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Placeholder entry screen.
///
/// It exists so the project runs end to end from the first commit; the real
/// song browser replaces it in a later step.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Piano Flow',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
            ),
            const SizedBox(height: 12),
            const Text(
              'kurulum tamam',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

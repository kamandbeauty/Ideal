import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/constants.dart';
import '../../core/errors.dart';
import '../../shared/theme/app_colors.dart';

/// Opens the database (running any pending migration) and routes onward.
/// A migration failure is shown instead of silently continuing with a
/// half-migrated database.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    try {
      await ref.read(appDatabaseProvider).database;
      final bool onboardingDone = await ref.read(onboardingDoneProvider.future);
      if (!mounted) return;
      context.go(onboardingDone ? '/home' : '/onboarding');
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() => _error = failure.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'راه‌اندازی دیتابیس ناموفق بود: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.subtitles_rounded, size: 46, color: Colors.white),
            ),
            const SizedBox(height: 22),
            Text(SubFlowInfo.appName,
                style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 6),
            Text(
              SubFlowInfo.tagline,
              textDirection: TextDirection.ltr,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 34),
            if (_error == null)
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

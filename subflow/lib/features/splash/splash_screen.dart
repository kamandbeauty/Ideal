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
      // No welcome screen: the database is the only thing worth waiting for,
      // and a first-run carousel in front of a one-screen editor is friction.
      if (!mounted) return;
      context.go('/home');
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
                child: Column(
                  children: <Widget>[
                    SelectableText(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.danger, fontSize: 12.5, height: 1.8),
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _error = null);
                        _boot();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('تلاش دوباره'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/constants.dart';
import '../../database/dao/settings_dao.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/sf_button.dart';
import '../../shared/widgets/sf_scaffold.dart';

class _OnboardingPage {
  const _OnboardingPage(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;
}

const List<_OnboardingPage> _pages = <_OnboardingPage>[
  _OnboardingPage(
    Icons.mic_rounded,
    'زیرنویس خودکار، کاملاً آفلاین',
    'گفتار ویدئو با Whisper روی خود گوشی به متن تبدیل می‌شود. هیچ فایل صوتی یا تصویری '
        'به هیچ سروری فرستاده نمی‌شود.',
  ),
  _OnboardingPage(
    Icons.text_fields_rounded,
    'فارسی و انگلیسی، درست و دقیق',
    'شکل‌دهی حروف فارسی، نیم‌فاصله، اعداد و علائم نگارشی با BiDi استاندارد یونیکد '
        'پردازش می‌شوند؛ نه فقط راست‌چین کردن ساده.',
  ),
  _OnboardingPage(
    Icons.high_quality_rounded,
    'کیفیت ویدئو دست‌نخورده',
    'اگر تغییری روی تصویر نداشته باشیم، ویدئو بدون کدگذاری مجدد کپی می‌شود و اگر '
        'زیرنویس روی تصویر بنشیند، با بالاترین تنظیمات سازگار با دستگاه رندر می‌شود.',
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final SettingsDao settings = await ref.read(settingsDaoProvider.future);
    await settings.setBool(SettingKeys.onboardingDone, true);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final bool isLast = _index == _pages.length - 1;
    return SfScaffold(
      child: Column(
        children: <Widget>[
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(onPressed: _finish, child: const Text('رد کردن')),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _pages.length,
              onPageChanged: (int index) => setState(() => _index = index),
              itemBuilder: (BuildContext context, int index) {
                final _OnboardingPage page = _pages[index];
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: Icon(page.icon, size: 48, color: AppColors.primarySoft),
                    ),
                    const SizedBox(height: 30),
                    Text(page.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 14),
                    Text(
                      page.body,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(_pages.length, (int index) {
              final bool active = index == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 26 : 8,
                height: 8,
                decoration: BoxDecoration(
                  gradient: active ? AppColors.accentGradient : null,
                  color: active ? null : AppColors.outline,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 22),
          SfPrimaryButton(
            label: isLast ? 'شروع کنیم' : 'بعدی',
            icon: isLast ? Icons.check_rounded : Icons.arrow_back_rounded,
            onPressed: () {
              if (isLast) {
                _finish();
              } else {
                _controller.nextPage(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                );
              }
            },
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants.dart';
import '../../core/platform/contracts.dart';
import '../../database/dao/settings_dao.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/sf_card.dart';
import '../../shared/widgets/sf_scaffold.dart';
import '../../shared/widgets/stat_chip.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool? _preferHardware;

  Future<void> _loadHardwarePref() async {
    final SettingsDao dao = await ref.read(settingsDaoProvider.future);
    final bool value = await dao.getBool(SettingKeys.preferHardwareEncoder, fallback: true);
    if (mounted) setState(() => _preferHardware = value);
  }

  Future<void> _setHardwarePref(bool value) async {
    final SettingsDao dao = await ref.read(settingsDaoProvider.future);
    await dao.setBool(SettingKeys.preferHardwareEncoder, value);
    if (mounted) setState(() => _preferHardware = value);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHardwarePref());
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<DeviceCapabilities> caps = ref.watch(deviceCapabilitiesProvider);
    return SfScaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 28),
        children: <Widget>[
          SfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('دستگاه', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                caps.when(
                  loading: () => const Text('در حال خواندن مشخصات سخت‌افزار…'),
                  error: (Object error, StackTrace stack) => Text('$error'),
                  data: (DeviceCapabilities data) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      StatChip(label: 'API ${data.sdkInt}'),
                      StatChip(label: data.abi),
                      StatChip(
                        label: data.hardwareH264 ? 'H.264 سخت‌افزاری' : 'H.264 نرم‌افزاری',
                        tint: data.hardwareH264 ? AppColors.success : AppColors.warning,
                      ),
                      StatChip(
                        label: data.hardwareHevc ? 'HEVC سخت‌افزاری' : 'بدون HEVC',
                        tint: data.hardwareHevc ? AppColors.success : AppColors.warning,
                      ),
                      StatChip(
                        label: data.nativeCoreReady ? 'هسته بومی آماده' : 'هسته بومی بارگذاری نشد',
                        tint: data.nativeCoreReady ? AppColors.success : AppColors.danger,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SfCard(
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _preferHardware ?? true,
              onChanged: _setHardwarePref,
              title: const Text('استفاده از کدگذار سخت‌افزاری',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                'سریع‌تر و کم‌مصرف‌تر؛ اگر دستگاه پشتیبانی نکند، خروجی به‌صورت نرم‌افزاری رندر می‌شود.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.7),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const SfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('وضعیت قابلیت‌ها', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                SizedBox(height: 10),
                _StatusRow(implemented: true, label: 'ورود ویدئو + خواندن دقیق مشخصات فنی'),
                _StatusRow(implemented: true, label: 'پروژه‌ها: ساخت، کپی، تغییر نام، حذف نرم'),
                _StatusRow(implemented: true, label: 'پخش ویدئو با Media3 (فایل اصلی)'),
                _StatusRow(implemented: true, label: 'موتور کیفیت خروجی و پلن رندر'),
                _StatusRow(implemented: true, label: 'کدک SRT/ASS در هسته بومی'),
                _StatusRow(implemented: false, label: 'تشخیص گفتار Whisper (فاز ۲)'),
                _StatusRow(implemented: false, label: 'ویرایشگر زیرنویس و استایل (فاز ۳ و ۴)'),
                _StatusRow(implemented: false, label: 'واترمارک، افکت، رندر خروجی (فاز ۵ و ۶)'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('درباره', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text(
                  '${SubFlowInfo.appName} — ${SubFlowInfo.tagline}\n'
                  'نسخه ۰.۱.۰ (فاز ۱) · حداقل اندروید ۸ (API 26) · بدون WebView · بدون ارسال داده',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.implemented, required this.label});

  final bool implemented;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Icon(
            implemented ? Icons.check_circle_rounded : Icons.schedule_rounded,
            size: 16,
            color: implemented ? AppColors.success : AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.6,
                color: implemented ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

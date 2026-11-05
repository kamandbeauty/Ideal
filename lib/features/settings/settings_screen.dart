/// Settings: language, theme, defaults, storage, device info, about.
library;

import 'package:flutter/material.dart' hide ValueSlider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/strings.dart';
import '../../app/providers.dart';
import '../../app/theme/app_theme.dart';
import '../../app/widgets/common.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/export_settings.dart';
import '../../core/models/motion_type.dart';
import '../../core/utils/ratio_utils.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int? _cacheBytes;

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  Future<void> _loadCache() async {
    final thumbs = ref.read(bootstrapProvider).thumbs;
    final size = await thumbs.cacheSizeBytes();
    if (mounted) setState(() => _cacheBytes = size);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final prefs = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final caps = ref.watch(capabilitiesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('settings_title'))),
      body: SafeArea(
        child: PageBody(
          child: ListView(
            children: <Widget>[
              SectionCard(
                title: l10n.t('settings_language'),
                icon: Icons.translate_rounded,
                child: SegmentedChoice<String>(
                  values: const <String>['fa', 'en'],
                  selected: prefs.localeCode,
                  labelBuilder: (String c) =>
                      c == 'fa' ? 'فارسی' : 'English',
                  onChanged: ctrl.setLocale,
                ),
              ),
              const SizedBox(height: AppTheme.s12),
              SectionCard(
                title: l10n.t('settings_theme'),
                icon: Icons.dark_mode_outlined,
                child: SegmentedChoice<ThemeMode>(
                  values: ThemeMode.values,
                  selected: prefs.themeMode,
                  labelBuilder: (ThemeMode m) => l10n.t(switch (m) {
                    ThemeMode.dark => 'settings_theme_dark',
                    ThemeMode.light => 'settings_theme_light',
                    ThemeMode.system => 'settings_theme_system',
                  }),
                  onChanged: ctrl.setTheme,
                ),
              ),
              const SizedBox(height: AppTheme.s12),
              SectionCard(
                title: l10n.t('settings_default_export'),
                icon: Icons.movie_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SegmentedChoice<ResolutionPreset>(
                      values: ResolutionPreset.values,
                      selected: prefs.defaultExport.resolution,
                      labelBuilder: (ResolutionPreset r) => r.label,
                      onChanged: (ResolutionPreset r) => ctrl
                          .setDefaultExport(prefs.defaultExport
                              .copyWith(resolution: r)),
                    ),
                    const SizedBox(height: 8),
                    SegmentedChoice<FpsPreset>(
                      values: FpsPreset.values,
                      selected: prefs.defaultExport.fps,
                      labelBuilder: (FpsPreset f) => '${f.value} fps',
                      onChanged: (FpsPreset f) => ctrl.setDefaultExport(
                          prefs.defaultExport.copyWith(fps: f)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final q in QualityPreset.values)
                          ChoiceChip(
                            label: Text(l10n.t('export_quality_${q.id}')),
                            selected: prefs.defaultExport.quality == q,
                            onSelected: (_) => ctrl.setDefaultExport(
                                prefs.defaultExport.copyWith(quality: q)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.s12),
              SectionCard(
                title: l10n.t('settings_default_motion'),
                icon: Icons.auto_awesome_rounded,
                subtitle: l10n.t('motion_intensity'),
                child: Column(
                  children: <Widget>[
                    ValueSlider(
                      label: l10n.t('settings_motion_intensity'),
                      value: prefs.defaultIntensity,
                      min: 0,
                      max: 1,
                      format: (double v) => '${(v * 100).round()}%',
                      onChanged: ctrl.setDefaultIntensity,
                    ),
                    ValueSlider(
                      label: l10n.t('settings_photo_duration'),
                      value: prefs.defaultPhotoDuration,
                      min: AppLimits.minPhotoDuration,
                      max: 15,
                      divisions: 140,
                      format: (double v) => '${v.toStringAsFixed(1)}s',
                      onChanged: ctrl.setDefaultPhotoDuration,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${MotionType.values.length} motion types · '
                        '9 transitions',
                        style: context.theme.textTheme.bodySmall?.copyWith(
                          color: context.theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.s12),
              SectionCard(
                title: l10n.t('settings_storage'),
                icon: Icons.sd_storage_outlined,
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '${l10n.t('settings_cache')}: '
                            '${_cacheBytes == null ? '…' : formatBytes(_cacheBytes!)}',
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final freed =
                                await ref.read(bootstrapProvider).clearCache();
                            await _loadCache();
                            if (context.mounted) {
                              context.snack(l10n
                                  .t('settings_cache_cleared')
                                  .replaceAll('{size}', formatBytes(freed)));
                            }
                          },
                          icon: const Icon(Icons.cleaning_services_outlined,
                              size: 18),
                          label: Text(l10n.t('settings_clear_cache')),
                        ),
                      ],
                    ),
                    Text(
                      l10n.t('settings_privacy'),
                      style: context.theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.mint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.s12),
              SectionCard(
                title: l10n.t('settings_device'),
                icon: Icons.phone_android_rounded,
                child: caps.when(
                  data: (c) => Column(
                    children: <Widget>[
                      _kv(context, l10n.t('settings_device_encoder'),
                          c.codecName),
                      _kv(context, l10n.t('settings_device_max'),
                          '${c.maxWidth}×${c.maxHeight} @ ${c.maxFps}fps'),
                      _kv(context, l10n.t('export_codec'),
                          'H.264${c.supportsHevc ? ' · HEVC' : ''}'),
                      _kv(context, l10n.t('settings_device_ram'),
                          '${c.totalRamMb} MB'),
                      _kv(context, l10n.t('settings_device_storage'),
                          formatBytes(c.availableStorageMb * 1024 * 1024)),
                    ],
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (Object e, StackTrace s) => Text(
                    l10n.t('export_blocked'),
                    style: TextStyle(color: context.theme.colorScheme.error),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.s12),
              SectionCard(
                title: l10n.t('settings_about'),
                icon: Icons.info_outline_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l10n.t('settings_about_body'),
                        style: context.theme.textTheme.bodySmall),
                    const SizedBox(height: AppTheme.s12),
                    Row(
                      children: <Widget>[
                        const MotionShotLogo(size: 32),
                        const SizedBox(width: 10),
                        Text(
                          '${l10n.t('settings_version')} 1.0.0 (1)',
                          style: context.theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.s32),
              Center(
                child: Text(
                  'MotionShot · offline by design',
                  style: context.theme.textTheme.bodySmall?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.s24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(k,
                  style: context.theme.textTheme.bodySmall?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  )),
            ),
            Flexible(child: Text(v, textAlign: TextAlign.end)),
          ],
        ),
      );
}

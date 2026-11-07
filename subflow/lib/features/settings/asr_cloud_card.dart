import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../models/asr_provider.dart';
import '../../services/asr_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/sf_card.dart';

/// Chooses between the on-device engine and an online Whisper service.
///
/// The on-device path is the default and needs no account. This card exists for
/// people who want the accuracy of a hosted large model and are willing to send
/// the audio off the phone for it - so the trade-off is spelled out, the key is
/// masked, and nothing is saved until the user presses save.
class AsrCloudCard extends ConsumerStatefulWidget {
  const AsrCloudCard({super.key});

  @override
  ConsumerState<AsrCloudCard> createState() => _AsrCloudCardState();
}

class _AsrCloudCardState extends ConsumerState<AsrCloudCard> {
  final TextEditingController _url = TextEditingController();
  final TextEditingController _model = TextEditingController();
  final TextEditingController _key = TextEditingController();

  AsrProviderMode _mode = AsrProviderMode.onDevice;
  String _preset = AsrCloudPreset.groq.id;
  bool _loaded = false;
  bool _busy = false;
  bool _obscure = true;
  String? _status;
  bool _statusOk = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _url.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final AsrProviderMode mode = await ref.read(asrProviderModeProvider.future);
    final AsrCloudConfig config = await ref.read(asrCloudConfigProvider.future);
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _preset = config.presetId;
      _url.text = config.baseUrl;
      _model.text = config.model;
      _key.text = config.apiKey;
      _loaded = true;
    });
  }

  void _applyPreset(AsrCloudPreset preset) {
    setState(() {
      _preset = preset.id;
      if (preset != AsrCloudPreset.custom) {
        _url.text = preset.baseUrl;
        _model.text = preset.model;
      }
      _status = null;
    });
  }

  AsrCloudConfig get _config => AsrCloudConfig(
        baseUrl: _url.text,
        model: _model.text,
        apiKey: _key.text,
        presetId: _preset,
      );

  Future<void> _setMode(AsrProviderMode mode) async {
    setState(() {
      _mode = mode;
      _status = null;
    });
    await ref.read(asrSettingsControllerProvider).setMode(mode);
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    await ref.read(asrSettingsControllerProvider).saveCloud(_config);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _statusOk = true;
      _status = 'ذخیره شد.';
    });
  }

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    await ref.read(asrSettingsControllerProvider).saveCloud(_config);
    final AsrCloudCheck check = await ref.read(asrServiceProvider).checkCloud(_config);
    if (!mounted) return;
    final bool matches = check.ok && check.models.isNotEmpty && _config.model.isNotEmpty
        ? check.models.any((String name) => name.contains(_config.model.trim()))
        : true;
    setState(() {
      _busy = false;
      _statusOk = check.ok;
      if (!check.ok) {
        _status = check.error.isEmpty ? 'اتصال برقرار نشد.' : check.error;
      } else if (!matches) {
        _status = 'اتصال برقرار است، اما مدل «${_config.model.trim()}» در فهرست این '
            'سرویس نیست. نام مدل را بررسی کنید.';
      } else {
        _status = 'اتصال و کلید درست است${check.models.isEmpty ? '' : ' (${check.models.length} مدل در دسترس)'}.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const SfCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    final bool cloud = _mode == AsrProviderMode.cloud;
    return SfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('تشخیص گفتار', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text(
            'پیش‌فرض روی گوشی و بدون اینترنت است. اگر دقت مدل بزرگ‌تر را می‌خواهید، '
            'می‌توانید صدای پروژه را به یک سرویس Whisper آنلاین بفرستید.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.9),
          ),
          const SizedBox(height: 12),
          _ModeSwitch(mode: _mode, onChanged: _busy ? null : _setMode),
          if (cloud) ...<Widget>[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AsrCloudPreset.all
                  .map((AsrCloudPreset preset) => _PresetChip(
                        preset: preset,
                        selected: preset.id == _preset,
                        onTap: _busy ? null : () => _applyPreset(preset),
                      ))
                  .toList(growable: false),
            ),
            const SizedBox(height: 6),
            Text(
              AsrCloudPreset.byId(_preset).note,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.8),
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _url,
              label: 'آدرس سرویس',
              hint: 'https://api.groq.com/openai/v1',
              enabled: !_busy,
              keyboard: TextInputType.url,
            ),
            const SizedBox(height: 10),
            _Field(
              controller: _model,
              label: 'نام مدل',
              hint: 'whisper-large-v3',
              enabled: !_busy,
            ),
            const SizedBox(height: 10),
            _Field(
              controller: _key,
              label: 'کلید API',
              hint: 'gsk_… یا sk-…',
              enabled: !_busy,
              obscure: _obscure,
              trailing: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'کلید فقط در همین دستگاه ذخیره می‌شود و جز برای همین سرویس جایی '
              'فرستاده نمی‌شود. صدا هم فقط قطعهٔ صوتی همان پروژه است، نه ویدئو.',
              style: TextStyle(fontSize: 10.5, color: AppColors.textMuted, height: 1.9),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _save,
                    child: const Text('ذخیره'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _test,
                    child: const Text('تست اتصال'),
                  ),
                ),
              ],
            ),
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _status!,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.9,
                  color: _statusOk ? AppColors.success : AppColors.danger,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  final AsrProviderMode mode;
  final ValueChanged<AsrProviderMode>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _Tile(
            label: 'روی گوشی (آفلاین)',
            icon: Icons.smartphone_rounded,
            selected: mode == AsrProviderMode.onDevice,
            onTap: onChanged == null ? null : () => onChanged!(AsrProviderMode.onDevice),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Tile(
            label: 'آنلاین (Whisper بزرگ)',
            icon: Icons.cloud_outlined,
            selected: mode == AsrProviderMode.cloud,
            onTap: onChanged == null ? null : () => onChanged!(AsrProviderMode.cloud),
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.accentGradient : null,
          color: selected ? null : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Colors.transparent : AppColors.outline),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 18, color: selected ? Colors.white : AppColors.textSecondary),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.preset, required this.selected, required this.onTap});

  final AsrCloudPreset preset;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.16) : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.primary : AppColors.outline),
        ),
        child: Text(
          preset.label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.enabled,
    this.obscure = false,
    this.keyboard,
    this.trailing,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool enabled;
  final bool obscure;
  final TextInputType? keyboard;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscure,
      keyboardType: keyboard,
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        hintStyle: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        suffixIcon: trailing,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        filled: true,
        fillColor: AppColors.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

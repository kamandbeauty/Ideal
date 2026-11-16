import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/service_providers.dart';
import '../../core/providers/settings_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../ui/widgets/section_header.dart';
import '../../ui/widgets/status_chip.dart';
import '../../data/repositories/settings_repository.dart';
import '../../services/secure_store.dart';

/// Cloud AI configuration (optional). Credentials live in the Android keystore.
class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final _baseUrl = TextEditingController();
  final _model = TextEditingController();
  final _apiKey = TextEditingController();
  String _provider = 'none';
  bool _loading = true;
  bool _saving = false;
  bool _hasKey = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = ref.read(settingsRepositoryProvider);
    final baseUrl = await settings.read(SettingsKeys.aiBaseUrl);
    final model = await settings.read(SettingsKeys.aiModel);
    final provider = await settings.read(SettingsKeys.aiProvider);
    final key = await ref.read(secureStoreProvider).readApiKey();
    if (!mounted) return;
    setState(() {
      _baseUrl.text = baseUrl ?? '';
      _model.text = model ?? '';
      _provider = provider ?? 'none';
      _hasKey = key != null && key.isNotEmpty;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final SettingsRepository settings = ref.read(settingsRepositoryProvider);
    await settings.write(SettingsKeys.aiProvider, _provider);
    await settings.write(SettingsKeys.aiBaseUrl, _baseUrl.text.trim());
    await settings.write(SettingsKeys.aiModel, _model.text.trim());
    if (_apiKey.text.trim().isNotEmpty) {
      await ref.read(secureStoreProvider).writeApiKey(_apiKey.text.trim());
      _apiKey.clear();
      _hasKey = true;
    }
    await ref
        .read(cloudAiEnabledProvider.notifier)
        .set(_provider != 'none' && _baseUrl.text.trim().isNotEmpty);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تنظیمات ذخیره شد.')),
    );
  }

  Future<void> _clearKey() async {
    await ref.read(secureStoreProvider).deleteApiKey();
    if (!mounted) return;
    setState(() => _hasKey = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('کلید API از حافظهٔ امن حذف شد.')),
    );
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cloudEnabled = ref.watch(cloudAiEnabledProvider);
    final sendNotifications = ref.watch(sendNotificationsToAiProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('هوش مصنوعی')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const SectionHeader(
                  title: 'حالت پیش‌فرض: محلی',
                  icon: Icons.lock_outline_rounded,
                ),
                Text(
                  'جویده بدون هیچ سرویس ابری هم کار می‌کند: تشخیص دستورها، یادداشت‌ها، '
                  'وظایف و خلاصهٔ پیام‌ها همه روی دستگاه انجام می‌شود. اتصال به یک '
                  'سرویس سازگار با OpenAI اختیاری است و فقط متن گفت‌وگو را ارسال می‌کند.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _provider,
                  decoration: const InputDecoration(labelText: 'سرویس‌دهنده'),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('بدون سرویس ابری')),
                    DropdownMenuItem(
                      value: 'openai_compatible',
                      child: Text('سازگار با OpenAI (LM Studio، Ollama، OpenRouter…)'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _provider = value ?? 'none'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _baseUrl,
                  decoration: const InputDecoration(
                    labelText: 'آدرس پایه (Base URL)',
                    hintText: 'http://192.168.1.10:1234/v1',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _model,
                  decoration: const InputDecoration(
                    labelText: 'نام مدل',
                    hintText: 'مثلاً llama-3.1-8b-instruct',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKey,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'کلید API (اختیاری)',
                    suffixIcon: _hasKey
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.mint)
                        : null,
                  ),
                ),
                if (_hasKey)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _clearKey,
                      child: const Text(
                        'حذف کلید ذخیره‌شده',
                        style: TextStyle(color: AppColors.coral),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'کلید API فقط در Keystore اندروید ذخیره می‌شود و هرگز در کد یا '
                    'پایگاه‌داده قرار نمی‌گیرد. اگر آدرس «http» روی شبکهٔ محلی است، '
                    'داده از شبکهٔ شما خارج نمی‌شود.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: cloudEnabled,
                  onChanged: (value) =>
                      ref.read(cloudAiEnabledProvider.notifier).set(value),
                  title: const Text('استفاده از سرویس ابری برای گفت‌وگوی آزاد'),
                  subtitle: const Text(
                    'در صورت خاموش‌بودن، فقط پردازش محلی انجام می‌شود.',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: sendNotifications,
                  onChanged: (value) =>
                      ref.read(sendNotificationsToAiProvider.notifier).set(value),
                  title: const Text('اجازهٔ ارسال متن پیام‌ها به سرویس ابری'),
                  subtitle: const Text(
                    'به‌صورت پیش‌فرض خاموش است. حتی با روشن‌بودن، پیام‌ها فقط برای '
                    'خلاصه‌سازی ارسال می‌شوند.',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    StatusChip(
                      label: cloudEnabled ? 'ابر فعال' : 'محلی و آفلاین',
                      color: cloudEnabled ? AppColors.amber : AppColors.mint,
                      icon: cloudEnabled ? Icons.cloud_outlined : Icons.shield_rounded,
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: const Text('ذخیره'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

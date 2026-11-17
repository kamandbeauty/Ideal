import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/service_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_date.dart';
import '../../data/models/job.dart';
import '../../services/job_service.dart';
import 'jobs_screen.dart';

/// Create or edit a job. Every field is functional and validated.
class JobEditorScreen extends ConsumerStatefulWidget {
  const JobEditorScreen({super.key, this.job});

  final Job? job;

  @override
  ConsumerState<JobEditorScreen> createState() => _JobEditorScreenState();
}

class _JobEditorScreenState extends ConsumerState<JobEditorScreen> {
  late final TextEditingController _title =
      TextEditingController(text: widget.job?.title ?? '');
  late final TextEditingController _prompt =
      TextEditingController(text: widget.job?.prompt ?? '');

  late JobScheduleKind _kind = widget.job?.schedule.kind == JobScheduleKind.interval
      ? JobScheduleKind.daily
      : (widget.job?.schedule.kind ?? JobScheduleKind.once);
  late TimeOfDay _time = TimeOfDay(
    hour: widget.job?.schedule.hour ?? 9,
    minute: widget.job?.schedule.minute ?? 0,
  );
  late DateTime _date = widget.job?.schedule.anchor ??
      DateTime.now().add(const Duration(hours: 1));
  late int _weekday = widget.job?.schedule.weekday ?? DateTime.saturday;
  late int _intervalMinutes = widget.job?.schedule.intervalMinutes ?? 60;
  late JobAction _action = widget.job?.action ?? JobAction.reminder;
  late bool _notify = widget.job?.notify ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _prompt.dispose();
    super.dispose();
  }

  JobSchedule _buildSchedule() {
    switch (_kind) {
      case JobScheduleKind.once:
        return JobSchedule.once(
          DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute),
        );
      case JobScheduleKind.daily:
        return JobSchedule(
          kind: JobScheduleKind.daily,
          hour: _time.hour,
          minute: _time.minute,
        );
      case JobScheduleKind.weekly:
        return JobSchedule(
          kind: JobScheduleKind.weekly,
          hour: _time.hour,
          minute: _time.minute,
          weekday: _weekday,
        );
      case JobScheduleKind.interval:
        return JobSchedule(
          kind: JobScheduleKind.interval,
          intervalMinutes: _intervalMinutes,
        );
    }
  }

  Future<void> _save() async {
    final service = ref.read(jobServiceProvider);
    final schedule = _buildSchedule();
    setState(() => _saving = true);
    try {
      if (widget.job == null) {
        await service.create(
          title: _title.text,
          prompt: _prompt.text.trim().isEmpty ? _title.text : _prompt.text,
          schedule: schedule,
          action: _action,
          kind: _actionToKind(_action),
          notify: _notify,
        );
      } else {
        final updated = widget.job!.copyWith(
          title: _title.text.trim(),
          prompt: _prompt.text.trim(),
          schedule: schedule,
          action: _action,
          notify: _notify,
        );
        await service.setEnabled(updated, true);
      }
      ref.read(jobsRevisionProvider.notifier).state++;
      ref.invalidate(jobsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on JobValidationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static JobKind _actionToKind(JobAction action) => switch (action) {
        JobAction.reminder => JobKind.reminder,
        JobAction.dailyBriefing => JobKind.briefing,
        JobAction.messageSummary => JobKind.summary,
        JobAction.assistantPrompt => JobKind.custom,
      };

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: 'تاریخ اجرای وظیفه',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'ساعت اجرا',
    );
    if (picked != null) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.job == null ? 'وظیفهٔ جدید' : 'ویرایش وظیفه')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                hintText: 'عنوان، مثلاً «خلاصهٔ صبح»',
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _prompt,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'دستور اجرا، مثلاً «خلاصهٔ پیام‌های امروز را بگو»',
              ),
            ),
            const SizedBox(height: 20),
            Text('نوع وظیفه', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final action in JobAction.values)
                  ChoiceChip(
                    label: Text(switch (action) {
                      JobAction.reminder => 'یادآوری',
                      JobAction.dailyBriefing => 'خلاصهٔ روزانه',
                      JobAction.messageSummary => 'خلاصهٔ پیام‌ها',
                      JobAction.assistantPrompt => 'دستور به دستیار',
                    }),
                    selected: _action == action,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _action = action),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('زمان‌بندی', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<JobScheduleKind>(
              segments: const [
                ButtonSegment(value: JobScheduleKind.once, label: Text('یک‌بار')),
                ButtonSegment(value: JobScheduleKind.daily, label: Text('هر روز')),
                ButtonSegment(value: JobScheduleKind.weekly, label: Text('هفتگی')),
                ButtonSegment(value: JobScheduleKind.interval, label: Text('دوره‌ای')),
              ],
              selected: {_kind},
              onSelectionChanged: (selection) =>
                  setState(() => _kind = selection.first),
            ),
            const SizedBox(height: 12),
            if (_kind == JobScheduleKind.once) ...[
              _PickerRow(
                icon: Icons.event_rounded,
                label: 'تاریخ',
                value: PersianDate.longDate(_date),
                onTap: _pickDate,
              ),
              _PickerRow(
                icon: Icons.access_time_rounded,
                label: 'ساعت',
                value: PersianDate.clock(
                  DateTime(2000, 1, 1, _time.hour, _time.minute),
                ),
                onTap: _pickTime,
              ),
            ],
            if (_kind == JobScheduleKind.daily)
              _PickerRow(
                icon: Icons.access_time_rounded,
                label: 'ساعت اجرا',
                value: PersianDate.clock(
                  DateTime(2000, 1, 1, _time.hour, _time.minute),
                ),
                onTap: _pickTime,
              ),
            if (_kind == JobScheduleKind.weekly) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: DropdownButtonFormField<int>(
                  initialValue: _weekday,
                  decoration: const InputDecoration(labelText: 'روز هفته'),
                  items: const [
                    DropdownMenuItem(value: DateTime.saturday, child: Text('شنبه')),
                    DropdownMenuItem(value: DateTime.sunday, child: Text('یکشنبه')),
                    DropdownMenuItem(value: DateTime.monday, child: Text('دوشنبه')),
                    DropdownMenuItem(value: DateTime.tuesday, child: Text('سه‌شنبه')),
                    DropdownMenuItem(value: DateTime.wednesday, child: Text('چهارشنبه')),
                    DropdownMenuItem(value: DateTime.thursday, child: Text('پنجشنبه')),
                    DropdownMenuItem(value: DateTime.friday, child: Text('جمعه')),
                  ],
                  onChanged: (value) =>
                      setState(() => _weekday = value ?? DateTime.saturday),
                ),
              ),
              _PickerRow(
                icon: Icons.access_time_rounded,
                label: 'ساعت اجرا',
                value: PersianDate.clock(
                  DateTime(2000, 1, 1, _time.hour, _time.minute),
                ),
                onTap: _pickTime,
              ),
            ],
            if (_kind == JobScheduleKind.interval)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: DropdownButtonFormField<int>(
                  initialValue: _intervalMinutes,
                  decoration: const InputDecoration(labelText: 'هر چند دقیقه'),
                  items: const [
                    DropdownMenuItem(value: 15, child: Text('هر ۱۵ دقیقه')),
                    DropdownMenuItem(value: 30, child: Text('هر ۳۰ دقیقه')),
                    DropdownMenuItem(value: 60, child: Text('هر ۱ ساعت')),
                    DropdownMenuItem(value: 180, child: Text('هر ۳ ساعت')),
                    DropdownMenuItem(value: 720, child: Text('هر ۱۲ ساعت')),
                  ],
                  onChanged: (value) => setState(() => _intervalMinutes = value ?? 60),
                ),
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _notify,
              onChanged: (value) => setState(() => _notify = value),
              title: const Text('نمایش اعلان هنگام اجرا'),
              subtitle: const Text('نتیجهٔ اجرا در نوار اعلان هم نشان داده می‌شود.'),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'یادآور: اندروید برای صرفه‌جویی باتری ممکن است اجرای وظایف را تا چند '
                'دقیقه به تأخیر بیندازد. اجرای دقیق ثانیه‌ای تضمین نمی‌شود.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(_saving ? 'در حال ذخیره…' : 'ذخیرهٔ وظیفه'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      trailing: Text(
        value,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
      onTap: onTap,
    );
  }
}

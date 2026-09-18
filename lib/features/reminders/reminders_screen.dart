import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_budget_manager/di/providers.dart';
import 'package:expense_budget_manager/domain/model/reminder.dart';
import 'package:expense_budget_manager/l10n/generated/app_localizations.dart';
import 'package:expense_budget_manager/work/notifications.dart';

/// Re-reads all reminders and (re)schedules them. Called after any change so
/// the OS-level schedule always matches the stored reminders.
Future<void> resyncReminders(WidgetRef ref, String title) async {
  final all = await ref.read(reminderRepositoryProvider).getAll();
  await AppNotifications.instance.syncReminders(all, title: title);
}

String weekdayLabel(BuildContext context, int weekday) =>
    MaterialLocalizations.of(context).narrowWeekdays[weekday % 7];

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final reminders = ref.watch(remindersStreamProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.reminders)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEdit(context, null),
        child: const Icon(Icons.add),
      ),
      body: reminders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? Center(child: Text(l.noRemindersYet))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (c, i) {
                  final r = list[i];
                  final time = MaterialLocalizations.of(context)
                      .formatTimeOfDay(TimeOfDay(hour: r.hour, minute: r.minute));
                  final freq = r.frequency == ReminderFrequency.daily
                      ? l.frequencyDaily
                      : (r.weekdays.toList()..sort())
                          .map((w) => weekdayLabel(context, w))
                          .join(' ');
                  return ListTile(
                    leading: const Icon(Icons.alarm),
                    title: Text(r.message,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('$time • $freq'),
                    trailing: Switch(
                      value: r.enabled,
                      onChanged: (v) async {
                        await ref
                            .read(reminderRepositoryProvider)
                            .setEnabled(r.id, v);
                        await resyncReminders(ref, l.reminderTitle);
                      },
                    ),
                    onTap: () => _showEdit(context, r),
                  );
                },
              ),
      ),
    );
  }

  void _showEdit(BuildContext context, Reminder? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReminderEditSheet(existing: existing),
    );
  }
}

class _ReminderEditSheet extends ConsumerStatefulWidget {
  const _ReminderEditSheet({this.existing});
  final Reminder? existing;
  @override
  ConsumerState<_ReminderEditSheet> createState() => _ReminderEditSheetState();
}

class _ReminderEditSheetState extends ConsumerState<_ReminderEditSheet> {
  final _message = TextEditingController();
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  ReminderFrequency _freq = ReminderFrequency.daily;
  final Set<int> _weekdays = {};

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _message.text = e.message;
      _time = TimeOfDay(hour: e.hour, minute: e.minute);
      _freq = e.frequency;
      _weekdays.addAll(e.weekdays);
    }
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _message.text.trim().isNotEmpty &&
      (_freq == ReminderFrequency.daily || _weekdays.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isEditing = widget.existing != null;
    final timeLabel = MaterialLocalizations.of(context).formatTimeOfDay(_time);

    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _message,
            decoration: InputDecoration(labelText: l.reminderMessage),
            maxLines: 2,
            onChanged: (_) => setState(() {}),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(l.time),
            subtitle: Text(timeLabel),
            onTap: () async {
              final picked =
                  await showTimePicker(context: context, initialTime: _time);
              if (picked != null) setState(() => _time = picked);
            },
          ),
          const SizedBox(height: 8),
          SegmentedButton<ReminderFrequency>(
            segments: [
              ButtonSegment(
                  value: ReminderFrequency.daily, label: Text(l.frequencyDaily)),
              ButtonSegment(
                  value: ReminderFrequency.weekly, label: Text(l.frequencyWeekly)),
            ],
            selected: {_freq},
            onSelectionChanged: (s) => setState(() => _freq = s.first),
          ),
          if (_freq == ReminderFrequency.weekly) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (var wd = 1; wd <= 7; wd++)
                  FilterChip(
                    label: Text(weekdayLabel(context, wd)),
                    selected: _weekdays.contains(wd),
                    onSelected: (sel) => setState(() {
                      sel ? _weekdays.add(wd) : _weekdays.remove(wd);
                    }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(children: [
            if (isEditing)
              TextButton.icon(
                onPressed: _confirmDelete,
                icon: const Icon(Icons.delete_outline),
                label: Text(l.delete),
                style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error),
              ),
            const Spacer(),
            FilledButton(
              onPressed: _canSave ? _save : null,
              child: Text(l.save),
            ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    await ref.read(reminderRepositoryProvider).upsert(
          id: widget.existing?.id,
          message: _message.text.trim(),
          hour: _time.hour,
          minute: _time.minute,
          frequency: _freq,
          weekdays: _weekdays.toList(),
          enabled: widget.existing?.enabled ?? true,
        );
    await resyncReminders(ref, l.reminderTitle);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _confirmDelete() async {
    final l = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.deleteReminder),
        content: Text(l.deleteIrreversible),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel)),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.delete)),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(reminderRepositoryProvider).delete(widget.existing!.id);
      await resyncReminders(ref, l.reminderTitle);
      if (mounted) Navigator.pop(context);
    }
  }
}

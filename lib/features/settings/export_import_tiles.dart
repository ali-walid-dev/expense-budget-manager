import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_budget_manager/data/backup/local_backup_repository.dart';
import 'package:expense_budget_manager/di/providers.dart';
import 'package:expense_budget_manager/domain/backup/backup_failure.dart';
import 'package:expense_budget_manager/l10n/generated/app_localizations.dart';

/// Export everything to a file, and import one back — the offline counterpart
/// to the Google Drive backup, using the identical file format.
class ExportImportTiles extends ConsumerStatefulWidget {
  const ExportImportTiles({super.key});

  @override
  ConsumerState<ExportImportTiles> createState() => _ExportImportTilesState();
}

class _ExportImportTilesState extends ConsumerState<ExportImportTiles> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.save_alt),
          title: Text(l.exportData),
          subtitle: Text(l.exportDataSubtitle),
          enabled: !_busy,
          onTap: _export,
        ),
        ListTile(
          leading: const Icon(Icons.restore_page_outlined),
          title: Text(l.importData),
          subtitle: Text(l.importDataSubtitle),
          enabled: !_busy,
          onTap: _import,
        ),
      ],
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _export() async {
    final l = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    _toast(l.exporting);
    try {
      final bytes = await ref.read(localBackupRepositoryProvider).exportBytes();
      await ref.read(localBackupFilesProvider).shareExport(bytes);
    } catch (_) {
      _toast(l.exportFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final l = AppLocalizations.of(context)!;
    final repo = ref.read(localBackupRepositoryProvider);
    setState(() => _busy = true);
    try {
      final bytes = await ref.read(localBackupFilesProvider).pickBackup();
      if (bytes == null) {
        _toast(l.importNoFile);
        return;
      }

      // Parsed and validated before the user is asked anything — a damaged
      // file must never reach a confirmation dialog that implies it is usable.
      final doc = await repo.read(bytes);
      if (!mounted) return;

      final choice = await _askWhatToDo(repo.preview(doc));
      if (choice == null) return;

      if (choice.replace) {
        await repo.replaceAll(doc);
        _toast(l.importReplaceDone);
        return;
      }

      final report =
          await repo.merge(doc, applySettings: choice.applySettings);
      _toast(l.importDone(report.totalInserted, report.totalSkipped));
    } on BackupFailure catch (e) {
      _toast(_failureText(l, e));
    } catch (_) {
      _toast(l.importFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<_ImportChoice?> _askWhatToDo(ImportPreview preview) async {
    final dateF = ref.read(dateFormatterProvider);
    return showDialog<_ImportChoice>(
      context: context,
      builder: (_) => _ImportDialog(
        preview: preview,
        formattedDate: dateF.full(preview.createdAt.toLocal()),
      ),
    );
  }

  String _failureText(AppLocalizations l, BackupFailure e) => switch (e) {
        CorruptBackupFailure() => l.errCorruptBackup,
        UnsupportedVersionFailure() => l.errUnsupportedBackup,
        _ => l.importFailed,
      };
}

class _ImportChoice {
  const _ImportChoice({required this.replace, required this.applySettings});
  final bool replace;
  final bool applySettings;
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog({required this.preview, required this.formattedDate});
  final ImportPreview preview;
  final String formattedDate;

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  // Off by default: settings are live preferences, not rows to be filled in.
  bool _applySettings = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final p = widget.preview;

    return AlertDialog(
      title: Text(l.importTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.importFileSummary(widget.formattedDate, p.appVersion)),
          const SizedBox(height: 8),
          Text(l.importCounts(
            p.counts['transactions'] ?? 0,
            p.counts['accounts'] ?? 0,
            p.counts['categories'] ?? 0,
          )),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _applySettings,
            onChanged: (v) => setState(() => _applySettings = v ?? false),
            title: Text(l.importApplySettings),
            subtitle: Text(l.importApplySettingsHint),
          ),
          const SizedBox(height: 4),
          Text(
            l.importReplaceWarning,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        TextButton(
          onPressed: () async {
            // Replace is destructive and irreversible — confirm separately.
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                content: Text(l.importReplaceConfirm),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l.importReplaceAction),
                  ),
                ],
              ),
            );
            if (ok == true && context.mounted) {
              Navigator.pop(
                context,
                const _ImportChoice(replace: true, applySettings: true),
              );
            }
          },
          child: Text(l.importReplaceAction),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _ImportChoice(replace: false, applySettings: _applySettings),
          ),
          child: Text(l.importMergeAction),
        ),
      ],
    );
  }
}

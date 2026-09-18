import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_budget_manager/data/import/transaction_import_service.dart';
import 'package:expense_budget_manager/di/providers.dart';
import 'package:expense_budget_manager/l10n/generated/app_localizations.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});
  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  ImportPreview? _preview;
  bool _busy = false;

  Future<void> _pick() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
    );
    if (res == null || res.files.isEmpty) return;
    final path = res.files.first.path;
    if (path == null) return;
    setState(() => _busy = true);
    final preview = await ref.read(transactionImportServiceProvider).parse(path);
    if (!mounted) return;
    setState(() {
      _preview = preview;
      _busy = false;
    });
  }

  Future<void> _commit({required bool skipDuplicates}) async {
    final preview = _preview;
    if (preview == null) return;
    setState(() => _busy = true);
    final result = await ref
        .read(transactionImportServiceProvider)
        .commit(preview.rows, skipDuplicates: skipDuplicates);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _preview = null;
    });
    final l = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.importedToast(result.imported, result.skipped))),
    );
  }

  String _fatalMessage(AppLocalizations l, ImportFatal f) => switch (f) {
        ImportFatal.unsupported => l.importUnsupported,
        ImportFatal.unreadable => l.importUnreadable,
        ImportFatal.empty => l.importEmpty,
        ImportFatal.columnMismatch => l.importColumnMismatch,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final preview = _preview;

    return Scaffold(
      appBar: AppBar(title: Text(l.importTransactions)),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : preview == null
              ? _PickPrompt(onPick: _pick)
              : preview.fatal != null
                  ? _Message(
                      icon: Icons.error_outline,
                      text: _fatalMessage(l, preview.fatal!),
                      onRetry: _pick,
                      retryLabel: l.pickFile,
                    )
                  : _PreviewBody(preview: preview, onCommit: _commit),
    );
  }
}

class _PickPrompt extends StatelessWidget {
  const _PickPrompt({required this.onPick});
  final VoidCallback onPick;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.upload_file, size: 64),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(l.importColumnsHint, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.folder_open),
            label: Text(l.pickFile),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    required this.onRetry,
    required this.retryLabel,
  });
  final IconData icon;
  final String text;
  final VoidCallback onRetry;
  final String retryLabel;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(text, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({required this.preview, required this.onCommit});
  final ImportPreview preview;
  final void Function({required bool skipDuplicates}) onCommit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(spacing: 16, runSpacing: 4, children: [
            Text(l.validRows(preview.validCount)),
            Text(l.duplicateRows(preview.duplicateCount)),
            Text(l.errorRows(preview.errorCount)),
          ]),
        ),
        const Divider(height: 0),
        Expanded(
          child: ListView.builder(
            itemCount: preview.rows.length,
            itemBuilder: (c, i) {
              final r = preview.rows[i];
              final Color? color = !r.valid
                  ? Theme.of(context).colorScheme.error
                  : r.duplicate
                      ? Theme.of(context).colorScheme.tertiary
                      : null;
              final subtitle = !r.valid
                  ? r.error!
                  : r.duplicate
                      ? l.duplicate
                      : '${r.categoryName.isEmpty ? '—' : r.categoryName} • ${r.accountName}';
              return ListTile(
                dense: true,
                leading: Icon(
                  !r.valid
                      ? Icons.error_outline
                      : r.duplicate
                          ? Icons.copy
                          : Icons.check_circle_outline,
                  color: color,
                ),
                title: Text(l.rowLabel(r.rowNumber)),
                subtitle: Text(subtitle, style: TextStyle(color: color)),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: preview.validCount == 0
                        ? null
                        : () => onCommit(skipDuplicates: true),
                    child: Text(l.skipDuplicates),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: preview.validCount == 0
                        ? null
                        : () => onCommit(skipDuplicates: false),
                    child: Text(l.importAll),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

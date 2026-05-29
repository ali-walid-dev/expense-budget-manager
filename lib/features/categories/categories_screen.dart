import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_budget_manager/di/providers.dart';
import 'package:expense_budget_manager/domain/model/category.dart' as dom;
import 'package:expense_budget_manager/l10n/generated/app_localizations.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final tree = ref.watch(categoryTreeStreamProvider);
    final repo = ref.read(categoryRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.categories)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEdit(context, repo, null),
        child: const Icon(Icons.add),
      ),
      body: tree.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (nodes) => ListView(
          children: [
            for (final node in nodes)
              ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: node.category.color,
                  child: Icon(node.category.icon, color: Colors.white, size: 18),
                ),
                title: Text(node.category.name),
                subtitle: Text(node.category.type.name),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showEdit(context, repo, node.category),
                ),
                children: [
                  for (final child in node.children)
                    ListTile(
                      contentPadding: const EdgeInsetsDirectional.only(start: 56, end: 8),
                      leading: CircleAvatar(
                        backgroundColor: child.color,
                        radius: 14,
                        child: Icon(child.icon, color: Colors.white, size: 14),
                      ),
                      title: Text(child.name),
                      trailing: child.isDefault
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => repo.delete(child.id),
                            ),
                      onTap: () => _showEdit(context, repo, child),
                    ),
                  ListTile(
                    contentPadding: const EdgeInsetsDirectional.only(start: 56),
                    leading: const Icon(Icons.add),
                    title: Text(l.addTransaction),
                    onTap: () => _showEdit(context, repo, null, parentId: node.category.id, type: node.category.type),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showEdit(BuildContext context, dynamic repo, dom.Category? existing, {int? parentId, dom.CategoryType? type}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CategoryEditSheet(existing: existing, parentId: parentId, type: type),
    );
  }
}

class _CategoryEditSheet extends ConsumerStatefulWidget {
  const _CategoryEditSheet({this.existing, this.parentId, this.type});
  final dom.Category? existing;
  final int? parentId;
  final dom.CategoryType? type;
  @override
  ConsumerState<_CategoryEditSheet> createState() => _CategoryEditSheetState();
}

class _CategoryEditSheetState extends ConsumerState<_CategoryEditSheet> {
  late final TextEditingController _name;
  late dom.CategoryType _type;
  late Color _color;
  late IconData _icon;

  static const _palette = [
    Color(0xFF16B981), Color(0xFFD85A30), Color(0xFF185FA5), Color(0xFFBA7517),
    Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFF14B8A6), Color(0xFFEAB308),
  ];
  static const _icons = [
    Icons.restaurant, Icons.local_cafe, Icons.shopping_basket, Icons.directions_car,
    Icons.shopping_bag, Icons.movie, Icons.local_hospital, Icons.receipt_long,
    Icons.school, Icons.home, Icons.attach_money, Icons.work, Icons.savings,
  ];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _type = widget.existing?.type ?? widget.type ?? dom.CategoryType.expense;
    _color = widget.existing?.color ?? _palette.first;
    _icon = widget.existing?.icon ?? _icons.first;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(controller: _name, decoration: InputDecoration(labelText: l.category)),
          const SizedBox(height: 12),
          SegmentedButton<dom.CategoryType>(
            segments: [
              ButtonSegment(value: dom.CategoryType.expense, label: Text(l.typeExpense)),
              ButtonSegment(value: dom.CategoryType.income, label: Text(l.typeIncome)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final c in _palette)
              GestureDetector(
                onTap: () => setState(() => _color = c),
                child: CircleAvatar(
                  backgroundColor: c, radius: 16,
                  child: _color == c ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                ),
              ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final i in _icons)
              GestureDetector(
                onTap: () => setState(() => _icon = i),
                child: CircleAvatar(
                  backgroundColor: _icon == i
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  radius: 18,
                  child: Icon(i, size: 18, color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              final repo = ref.read(categoryRepositoryProvider);
              await repo.upsert(
                id: widget.existing?.id,
                name: _name.text.trim(),
                type: _type,
                color: _color,
                icon: _icon,
                parentId: widget.parentId ?? widget.existing?.parentId,
              );
              if (mounted) Navigator.pop(context);
            },
            child: Text(l.save),
          ),
        ],
      ),
    );
  }
}

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:expense_budget_manager/di/providers.dart';
import 'package:expense_budget_manager/domain/model/account.dart';
import 'package:expense_budget_manager/domain/model/category.dart';
import 'package:expense_budget_manager/domain/model/recurring_interval.dart';
import 'package:expense_budget_manager/domain/model/transaction_type.dart';

class AddEditState {
  const AddEditState({
    required this.id,
    required this.amountMinor,
    required this.type,
    required this.accountId,
    required this.toAccountId,
    required this.parentCategoryId,
    required this.categoryId,
    required this.dateTime,
    required this.note,
    required this.recurring,
    required this.recurringInterval,
    required this.accounts,
    required this.categories,
  });

  final int? id;
  final int amountMinor;
  final TransactionType type;
  final int? accountId;
  final int? toAccountId;
  // The chosen top-level (parent) category. Required for non-transfers.
  final int? parentCategoryId;
  // The category actually saved on the transaction: the child when one is
  // chosen, otherwise the parent. Reports roll children up to the parent.
  final int? categoryId;
  final DateTime dateTime;
  final String? note;
  final bool recurring;
  final RecurringInterval? recurringInterval;
  final List<Account> accounts;
  final List<Category> categories;

  /// Top-level categories of the current type.
  List<Category> get parents =>
      categories.where((c) => c.parentId == null).toList();

  /// Children of the chosen parent (empty if none / no parent chosen).
  List<Category> get childrenOfParent => parentCategoryId == null
      ? const []
      : categories.where((c) => c.parentId == parentCategoryId).toList();

  /// The chosen child id, or null when the parent itself is the category.
  int? get childCategoryId =>
      (categoryId != null && categoryId != parentCategoryId) ? categoryId : null;

  bool get canSave =>
      amountMinor > 0 &&
      accountId != null &&
      (type != TransactionType.transfer
          ? parentCategoryId != null
          : toAccountId != null && toAccountId != accountId);

  AddEditState copyWith({
    int? amountMinor,
    TransactionType? type,
    int? accountId,
    int? toAccountId,
    Object? parentCategoryId = _sentinel,
    Object? categoryId = _sentinel,
    DateTime? dateTime,
    Object? note = _sentinel,
    bool? recurring,
    RecurringInterval? recurringInterval,
    List<Account>? accounts,
    List<Category>? categories,
  }) =>
      AddEditState(
        id: id,
        amountMinor: amountMinor ?? this.amountMinor,
        type: type ?? this.type,
        accountId: accountId ?? this.accountId,
        toAccountId: toAccountId ?? this.toAccountId,
        parentCategoryId: parentCategoryId == _sentinel
            ? this.parentCategoryId
            : parentCategoryId as int?,
        categoryId:
            categoryId == _sentinel ? this.categoryId : categoryId as int?,
        dateTime: dateTime ?? this.dateTime,
        note: note == _sentinel ? this.note : note as String?,
        recurring: recurring ?? this.recurring,
        recurringInterval: recurringInterval ?? this.recurringInterval,
        accounts: accounts ?? this.accounts,
        categories: categories ?? this.categories,
      );

  static const _sentinel = Object();
}

class AddEditNotifier extends FamilyAsyncNotifier<AddEditState, int?> {
  @override
  Future<AddEditState> build(int? txId) async {
    final accounts = await ref.watch(accountsStreamProvider.future);
    final categories = await ref.watch(allCategoriesStreamProvider.future);

    if (txId != null) {
      final repo = ref.watch(transactionRepositoryProvider);
      // Load directly by id — the old getPage(limit:500).firstWhere threw a
      // StateError (blank screen) for any transaction outside the latest 500
      // (Bug 3).
      final tx = await repo.getById(txId);
      if (tx == null) {
        throw StateError('Transaction $txId no longer exists');
      }
      final scoped = _filterCategories(categories, tx.type);
      return AddEditState(
        id: txId,
        amountMinor: tx.amountMinor,
        type: tx.type,
        accountId: tx.accountId,
        toAccountId: tx.toAccountId,
        parentCategoryId: _parentOf(scoped, tx.categoryId),
        categoryId: tx.categoryId,
        dateTime: tx.dateTime,
        note: tx.note,
        recurring: false,
        recurringInterval: null,
        accounts: accounts,
        categories: scoped,
      );
    }

    return AddEditState(
      id: null,
      amountMinor: 0,
      type: TransactionType.expense,
      accountId: accounts.isNotEmpty ? accounts.first.id : null,
      toAccountId: null,
      parentCategoryId: null,
      categoryId: null,
      dateTime: DateTime.now(),
      note: null,
      recurring: false,
      recurringInterval: null,
      accounts: accounts,
      categories: _filterCategories(categories, TransactionType.expense),
    );
  }

  List<Category> _filterCategories(List<Category> all, TransactionType type) {
    final wanted = type == TransactionType.income
        ? CategoryType.income
        : CategoryType.expense;
    return all.where((c) => c.type == wanted).toList();
  }

  /// Resolves the parent of a saved category id: if it's a child, its parent;
  /// if it's already top-level, itself; null if unset/unknown.
  int? _parentOf(List<Category> scoped, int? categoryId) {
    if (categoryId == null) return null;
    final match = scoped.where((c) => c.id == categoryId).firstOrNull;
    if (match == null) return null;
    return match.parentId ?? match.id;
  }

  Future<void> init() async {
    // build() does the work — keep for ergonomics if needed later.
  }

  void setAmount(int minor) =>
      state = AsyncData(state.value!.copyWith(amountMinor: minor));

  void setType(TransactionType t) {
    final all = ref.read(allCategoriesStreamProvider).valueOrNull ?? <Category>[];
    state = AsyncData(state.value!.copyWith(
      type: t,
      parentCategoryId: null,
      categoryId: null,
      categories: _filterCategories(all, t),
    ));
  }

  /// Choose the (required) top-level category. Defaults the saved category to
  /// the parent and clears any previously chosen child.
  void setParentCategory(int? id) {
    state = AsyncData(state.value!.copyWith(
      parentCategoryId: id,
      categoryId: id,
    ));
  }

  /// Choose an optional child. Passing null reverts the saved category to the
  /// parent.
  void setChildCategory(int? id) {
    final s = state.value!;
    state = AsyncData(s.copyWith(
      categoryId: id ?? s.parentCategoryId,
    ));
  }

  void setAccount(int? id) =>
      state = AsyncData(state.value!.copyWith(accountId: id));
  void setToAccount(int? id) =>
      state = AsyncData(state.value!.copyWith(toAccountId: id));
  void setDate(DateTime dt) =>
      state = AsyncData(state.value!.copyWith(dateTime: dt));
  void setNote(String? n) => state = AsyncData(state.value!.copyWith(note: n));
  void setRecurring(bool v) => state = AsyncData(state.value!.copyWith(
        recurring: v,
        recurringInterval: v ? RecurringInterval.monthly : null,
      ));
  void setRecurringInterval(RecurringInterval i) =>
      state = AsyncData(state.value!.copyWith(recurringInterval: i));

  Future<void> save() async {
    final s = state.value!;
    if (!s.canSave) return;
    final repo = ref.read(transactionRepositoryProvider);
    if (s.id == null) {
      await repo.insert(
        amountMinor: s.amountMinor,
        type: s.type,
        accountId: s.accountId!,
        toAccountId: s.toAccountId,
        categoryId: s.type == TransactionType.transfer ? null : s.categoryId,
        dateTime: s.dateTime,
        note: s.note,
      );
    } else {
      await repo.update(
        id: s.id!,
        amountMinor: s.amountMinor,
        type: s.type,
        accountId: s.accountId!,
        toAccountId: s.toAccountId,
        categoryId: s.type == TransactionType.transfer ? null : s.categoryId,
        dateTime: s.dateTime,
        note: s.note,
      );
    }
  }

  Future<void> delete() async {
    final s = state.value!;
    if (s.id == null) return;
    await ref.read(transactionRepositoryProvider).delete(s.id!);
  }
}

final addEditNotifierProvider =
    AsyncNotifierProvider.family<AddEditNotifier, AddEditState, int?>(
        AddEditNotifier.new);

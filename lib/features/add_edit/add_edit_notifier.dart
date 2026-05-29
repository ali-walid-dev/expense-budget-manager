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
  final int? categoryId;
  final DateTime dateTime;
  final String? note;
  final bool recurring;
  final RecurringInterval? recurringInterval;
  final List<Account> accounts;
  final List<Category> categories;

  bool get canSave =>
      amountMinor > 0 &&
      accountId != null &&
      (type != TransactionType.transfer
          ? categoryId != null
          : toAccountId != null && toAccountId != accountId);

  AddEditState copyWith({
    int? amountMinor,
    TransactionType? type,
    int? accountId,
    int? toAccountId,
    int? categoryId,
    DateTime? dateTime,
    String? note,
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
        categoryId: categoryId ?? this.categoryId,
        dateTime: dateTime ?? this.dateTime,
        note: note ?? this.note,
        recurring: recurring ?? this.recurring,
        recurringInterval: recurringInterval ?? this.recurringInterval,
        accounts: accounts ?? this.accounts,
        categories: categories ?? this.categories,
      );
}

class AddEditNotifier extends FamilyAsyncNotifier<AddEditState, int?> {
  @override
  Future<AddEditState> build(int? txId) async {
    final accounts = await ref.watch(accountsStreamProvider.future);
    final categories = await ref.watch(allCategoriesStreamProvider.future);

    if (txId != null) {
      final repo = ref.watch(transactionRepositoryProvider);
      final all = await repo.getPage(offset: 0, limit: 500);
      final tx = all.firstWhere((t) => t.id == txId);
      return AddEditState(
        id: txId,
        amountMinor: tx.amountMinor,
        type: tx.type,
        accountId: tx.accountId,
        toAccountId: tx.toAccountId,
        categoryId: tx.categoryId,
        dateTime: tx.dateTime,
        note: tx.note,
        recurring: false,
        recurringInterval: null,
        accounts: accounts,
        categories: _filterCategories(categories, tx.type),
      );
    }

    return AddEditState(
      id: null,
      amountMinor: 0,
      type: TransactionType.expense,
      accountId: accounts.isNotEmpty ? accounts.first.id : null,
      toAccountId: null,
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

  Future<void> init() async {
    // build() does the work — keep for ergonomics if needed later.
  }

  void setAmount(int minor) => state = AsyncData(state.value!.copyWith(amountMinor: minor));
  void setType(TransactionType t) {
    final s = state.value!;
    final all = ref.read(allCategoriesStreamProvider).valueOrNull ?? <Category>[];
    state = AsyncData(AddEditState(
      id: s.id,
      amountMinor: s.amountMinor,
      type: t,
      accountId: s.accountId,
      toAccountId: s.toAccountId,
      categoryId: null,
      dateTime: s.dateTime,
      note: s.note,
      recurring: s.recurring,
      recurringInterval: s.recurringInterval,
      accounts: s.accounts,
      categories: _filterCategories(all, t),
    ));
  }
  void setCategory(int? id) {
    final s = state.value!;
    state = AsyncData(AddEditState(
      id: s.id, amountMinor: s.amountMinor, type: s.type,
      accountId: s.accountId, toAccountId: s.toAccountId, categoryId: id,
      dateTime: s.dateTime, note: s.note, recurring: s.recurring,
      recurringInterval: s.recurringInterval, accounts: s.accounts,
      categories: s.categories,
    ));
  }
  void setAccount(int? id) => state = AsyncData(state.value!.copyWith(accountId: id));
  void setToAccount(int? id) {
    final s = state.value!;
    state = AsyncData(AddEditState(
      id: s.id, amountMinor: s.amountMinor, type: s.type,
      accountId: s.accountId, toAccountId: id, categoryId: s.categoryId,
      dateTime: s.dateTime, note: s.note, recurring: s.recurring,
      recurringInterval: s.recurringInterval, accounts: s.accounts,
      categories: s.categories,
    ));
  }
  void setDate(DateTime dt) => state = AsyncData(state.value!.copyWith(dateTime: dt));
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
        categoryId: s.categoryId,
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
        categoryId: s.categoryId,
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

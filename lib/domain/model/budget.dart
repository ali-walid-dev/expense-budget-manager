enum BudgetPeriod { weekly, monthly, custom }

class Budget {
  const Budget({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.carryOver,
  });

  final int id;
  final int? categoryId;
  final int amount;
  final BudgetPeriod period;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool carryOver;
}

class BudgetProgress {
  const BudgetProgress({
    required this.budget,
    required this.spentMinor,
    required this.categoryName,
  });
  final Budget budget;
  final int spentMinor;
  final String? categoryName;

  bool get overBudget => spentMinor > budget.amount;
  double get progress => budget.amount <= 0 ? 0 : spentMinor / budget.amount;
  int get remaining => budget.amount - spentMinor;
}

enum DebtStatus { active, completed }

class Debt {
  const Debt({
    required this.id,
    required this.name,
    required this.creditor,
    required this.totalAmount,
    required this.monthlyPayment,
    required this.startDate,
    required this.dueDate,
    required this.note,
    required this.accountId,
    required this.categoryId,
    required this.status,
    required this.lastGeneratedDate,
  });

  final int id;
  final String name;
  final String? creditor;
  final int totalAmount; // minor units
  final int monthlyPayment; // minor units
  final DateTime startDate;
  final DateTime? dueDate;
  final String? note;
  final int accountId;
  final int? categoryId;
  final DebtStatus status;
  final DateTime? lastGeneratedDate;
}

/// A debt plus its computed payment progress.
class DebtProgress {
  const DebtProgress({
    required this.debt,
    required this.paidMinor,
    required this.nextPaymentDate,
  });

  final Debt debt;
  final int paidMinor;
  final DateTime? nextPaymentDate;

  int get remainingMinor =>
      (debt.totalAmount - paidMinor).clamp(0, debt.totalAmount);
  double get progress =>
      debt.totalAmount <= 0 ? 1 : (paidMinor / debt.totalAmount).clamp(0, 1);
  bool get isCompleted => debt.status == DebtStatus.completed;
}

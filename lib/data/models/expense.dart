import '../json_helpers.dart';

class ExpenseCategory {
  ExpenseCategory({
    required this.id,
    required this.name,
    this.color,
    required this.isActive,
    this.expensesCount = 0,
  });

  final int id;
  final String name;
  final String? color;
  final bool isActive;
  final int expensesCount;

  factory ExpenseCategory.fromJson(Map<String, dynamic> j) => ExpenseCategory(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['name']?.toString() ?? '',
        color: j['color']?.toString(),
        isActive: j['is_active'] as bool? ?? true,
        expensesCount: (j['expenses_count'] as num?)?.toInt() ?? 0,
      );
}

class Expense {
  Expense({
    required this.id,
    required this.expenseNumber,
    required this.amount,
    required this.expenseDate,
    this.description,
    this.vendorName,
    this.category,
  });

  final int id;
  final String expenseNumber;
  final double amount;
  final String expenseDate;
  final String? description;
  final String? vendorName;
  final ExpenseCategory? category;

  factory Expense.fromJson(Map<String, dynamic> j) {
    ExpenseCategory? c;
    if (j['category'] is Map) {
      c = ExpenseCategory.fromJson(
        Map<String, dynamic>.from(j['category'] as Map),
      );
    }
    return Expense(
      id: (j['id'] as num?)?.toInt() ?? 0,
      expenseNumber: j['expense_number']?.toString() ?? '',
      amount: (j['amount'] as num?)?.toDouble() ?? 0,
      expenseDate: formatApiDate(j['expense_date']?.toString()),
      description: j['description']?.toString(),
      vendorName: j['vendor_name']?.toString(),
      category: c,
    );
  }
}

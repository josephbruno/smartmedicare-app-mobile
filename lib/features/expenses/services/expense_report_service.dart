import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../data/json_helpers.dart';

/// Expense summary report
class ExpenseSummary {
  final double totalExpenses;
  final double totalByCategory;
  final int transactionCount;
  final double averageExpense;
  final double highestExpense;
  final String period; // daily, weekly, monthly, yearly

  ExpenseSummary({
    required this.totalExpenses,
    required this.totalByCategory,
    required this.transactionCount,
    required this.averageExpense,
    required this.highestExpense,
    required this.period,
  });
}

/// Category breakdown
class CategoryBreakdown {
  final String category;
  final double amount;
  final int count;
  final double percentage;

  CategoryBreakdown({
    required this.category,
    required this.amount,
    required this.count,
    required this.percentage,
  });
}

/// Monthly trend data
class MonthlyTrend {
  final String month;
  final double amount;
  final int count;
  final Map<String, double> byCategory;

  MonthlyTrend({
    required this.month,
    required this.amount,
    required this.count,
    required this.byCategory,
  });
}

/// Budget tracking
class BudgetTracker {
  final String category;
  final double budgetLimit;
  final double spent;
  final double remaining;
  final double percentageUsed;
  final bool isExceeded;

  BudgetTracker({
    required this.category,
    required this.budgetLimit,
    required this.spent,
  })  : remaining = budgetLimit - spent,
        percentageUsed = (spent / budgetLimit) * 100,
        isExceeded = spent > budgetLimit;
}

/// Expense report service
class ExpenseReportService {
  final ApiClient _apiClient;

  ExpenseReportService(this._apiClient);

  /// Get expense summary for a date range.
  Future<ExpenseSummary> getExpenseSummary({
    required DateTime fromDate,
    required DateTime toDate,
    String? category,
  }) async {
    try {
      final params = <String, dynamic>{
        'from_date': fromDate.toIso8601String(),
        'to_date': toDate.toIso8601String(),
        if (category != null) 'category': category,
      };

      final response = await _apiClient.get(
        '/expenses/summary',
        queryParameters: params,
      );

      final data = response.data as Map<String, dynamic>;

      return ExpenseSummary(
        totalExpenses: (numOrNull(data['total_expenses']) ?? 0).toDouble(),
        totalByCategory: (numOrNull(data['total_by_category']) ?? 0).toDouble(),
        transactionCount: intOrNull(data['transaction_count']) ?? 0,
        averageExpense: (numOrNull(data['average_expense']) ?? 0).toDouble(),
        highestExpense: (numOrNull(data['highest_expense']) ?? 0).toDouble(),
        period: data['period']?.toString() ?? 'custom',
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Get category-wise breakdown.
  Future<List<CategoryBreakdown>> getCategoryBreakdown({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      final params = <String, dynamic>{
        'from_date': fromDate.toIso8601String(),
        'to_date': toDate.toIso8601String(),
      };

      final response = await _apiClient.get(
        '/expenses/category-breakdown',
        queryParameters: params,
      );

      final data = response.data as Map<String, dynamic>;
      final items = (data['data'] ?? data['breakdown'] ?? []) as List;

      return items
          .map((e) {
            final m = Map<String, dynamic>.from(e);
            return CategoryBreakdown(
              category: m['category']?.toString() ?? '',
              amount: (numOrNull(m['amount']) ?? 0).toDouble(),
              count: intOrNull(m['count']) ?? 0,
              percentage: (numOrNull(m['percentage']) ?? 0).toDouble(),
            );
          })
          .toList();
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Get monthly trend analysis.
  Future<List<MonthlyTrend>> getMonthlyTrends({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      final params = <String, dynamic>{
        'from_date': fromDate.toIso8601String(),
        'to_date': toDate.toIso8601String(),
      };

      final response = await _apiClient.get(
        '/expenses/monthly-trends',
        queryParameters: params,
      );

      final data = response.data as Map<String, dynamic>;
      final items = (data['data'] ?? data['trends'] ?? []) as List;

      return items
          .map((e) {
            final m = Map<String, dynamic>.from(e);
            final byCategoryData = m['by_category'] as Map? ?? {};
            return MonthlyTrend(
              month: m['month']?.toString() ?? '',
              amount: (numOrNull(m['amount']) ?? 0).toDouble(),
              count: intOrNull(m['count']) ?? 0,
              byCategory: Map<String, double>.from(
                byCategoryData.map(
                  (k, v) => MapEntry(k.toString(), (numOrNull(v) ?? 0).toDouble()),
                ),
              ),
            );
          })
          .toList();
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Get budget tracking for all categories.
  Future<List<BudgetTracker>> getBudgetTracking({
    required DateTime month,
  }) async {
    try {
      final params = <String, dynamic>{
        'month': DateFormat('yyyy-MM').format(month),
      };

      final response = await _apiClient.get(
        '/expenses/budget-tracking',
        queryParameters: params,
      );

      final data = response.data as Map<String, dynamic>;
      final items = (data['data'] ?? data['budgets'] ?? []) as List;

      return items
          .map((e) {
            final m = Map<String, dynamic>.from(e);
            return BudgetTracker(
              category: m['category']?.toString() ?? '',
              budgetLimit: (numOrNull(m['budget_limit']) ?? 0).toDouble(),
              spent: (numOrNull(m['spent']) ?? 0).toDouble(),
            );
          })
          .toList();
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Get comparison between two periods.
  Future<Map<String, dynamic>> comparePeriods({
    required DateTime period1From,
    required DateTime period1To,
    required DateTime period2From,
    required DateTime period2To,
  }) async {
    try {
      final params = <String, dynamic>{
        'period1_from': period1From.toIso8601String(),
        'period1_to': period1To.toIso8601String(),
        'period2_from': period2From.toIso8601String(),
        'period2_to': period2To.toIso8601String(),
      };

      final response = await _apiClient.get(
        '/expenses/comparison',
        queryParameters: params,
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Export expenses as PDF.
  Future<List<int>> exportExpensesAsPDF({
    required DateTime fromDate,
    required DateTime toDate,
    String? category,
  }) async {
    try {
      final params = <String, dynamic>{
        'from_date': fromDate.toIso8601String(),
        'to_date': toDate.toIso8601String(),
        'format': 'pdf',
        if (category != null) 'category': category,
      };

      final response = await _apiClient.get(
        '/expenses/export',
        queryParameters: params,
      );

      return response.data as List<int>;
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Export expenses as CSV.
  Future<String> exportExpensesAsCSV({
    required DateTime fromDate,
    required DateTime toDate,
    String? category,
  }) async {
    try {
      final params = <String, dynamic>{
        'from_date': fromDate.toIso8601String(),
        'to_date': toDate.toIso8601String(),
        'format': 'csv',
        if (category != null) 'category': category,
      };

      final response = await _apiClient.get(
        '/expenses/export',
        queryParameters: params,
      );

      return response.data as String;
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Export expenses as Excel.
  Future<List<int>> exportExpensesAsExcel({
    required DateTime fromDate,
    required DateTime toDate,
    String? category,
  }) async {
    try {
      final params = <String, dynamic>{
        'from_date': fromDate.toIso8601String(),
        'to_date': toDate.toIso8601String(),
        'format': 'xlsx',
        if (category != null) 'category': category,
      };

      final response = await _apiClient.get(
        '/expenses/export',
        queryParameters: params,
      );

      return response.data as List<int>;
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Get top expenses for a period.
  Future<List<Map<String, dynamic>>> getTopExpenses({
    required DateTime fromDate,
    required DateTime toDate,
    int limit = 10,
  }) async {
    try {
      final params = <String, dynamic>{
        'from_date': fromDate.toIso8601String(),
        'to_date': toDate.toIso8601String(),
        'limit': limit,
      };

      final response = await _apiClient.get(
        '/expenses/top',
        queryParameters: params,
      );

      final data = response.data as Map<String, dynamic>;
      return (data['data'] ?? data['expenses'] ?? []) as List<Map<String, dynamic>>;
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Get expenses by payment method.
  Future<Map<String, double>> getExpensesByPaymentMethod({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      final params = <String, dynamic>{
        'from_date': fromDate.toIso8601String(),
        'to_date': toDate.toIso8601String(),
      };

      final response = await _apiClient.get(
        '/expenses/by-payment-method',
        queryParameters: params,
      );

      final data = response.data as Map<String, dynamic>;
      final byMethod = (data['data'] ?? {}) as Map;

      return Map<String, double>.from(
        byMethod.map(
          (k, v) => MapEntry(k.toString(), (numOrNull(v) ?? 0).toDouble()),
        ),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}

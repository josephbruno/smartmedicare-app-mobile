import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../json_helpers.dart';
import '../models/api_response.dart';
import '../models/expense.dart';

class ExpenseService {
  ExpenseService(this._client);

  final ApiClient _client;

  Future<List<Expense>> list({Map<String, dynamic>? query}) async {
    final result = await listPaginated(
      page: int.tryParse(query?['page']?.toString() ?? '') ?? 1,
      perPage: int.tryParse(query?['per_page']?.toString() ?? '') ?? 20,
    );
    return result.items;
  }

  Future<({List<Expense> items, PaginationMeta? meta})> listPaginated({
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final res = await _client.get('/expenses', queryParameters: {
        'page': page,
        'per_page': perPage,
      });
      return parseEnvelopeList(res, Expense.fromJson);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<ExpenseCategory>> categories() async {
    try {
      final res = await _client.get('/expense-categories');
      return parseEnvelopeData(
        res,
        (data) => listFromData(data, ExpenseCategory.fromJson),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}

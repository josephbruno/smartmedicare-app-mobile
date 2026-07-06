import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../json_helpers.dart';
import '../models/expense.dart';

class ExpenseService {
  ExpenseService(this._client);

  final ApiClient _client;

  Future<List<Expense>> list({Map<String, dynamic>? query}) async {
    try {
      final res = await _client.get('/expenses', queryParameters: query);
      return parseEnvelopeData(res, (data) => listFromData(data, Expense.fromJson));
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

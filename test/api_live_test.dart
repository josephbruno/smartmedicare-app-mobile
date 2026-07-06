import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/app_config.dart';
import 'package:mobile/data/json_helpers.dart';
import 'package:mobile/data/models/dashboard_data.dart';
import 'package:mobile/data/models/invoice.dart';
import 'package:mobile/data/models/product.dart';

/// Optional live checks against the deployed API.
///
/// Run with:
/// flutter test test/api_live_test.dart \
///   --dart-define=API_TOKEN=your-token \
///   --dart-define=API_BASE_URL=https://api-maran.biapps.cloud/api/v1
const _apiToken = String.fromEnvironment('API_TOKEN');
const _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: AppConfig.apiBaseUrl,
);

void main() {
  final skipLive = _apiToken.isEmpty;

  group('live API', () {
    late Dio dio;

    setUp(() {
      dio = Dio(
        BaseOptions(
          baseUrl: _apiBaseUrl,
          headers: {
            'Authorization': 'Bearer $_apiToken',
            'Accept': 'application/json',
          },
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
    });

    test('GET /auth/me returns user envelope', () async {
      final res = await dio.get('/auth/me');
      final user = parseEnvelopeData(
        res,
        (data) => Map<String, dynamic>.from(data as Map),
      );
      expect(user['email'], isNotEmpty);
      expect(user['roles'], isA<List>());
    }, skip: skipLive);

    test('GET /reports/dashboard returns dashboard metrics', () async {
      final res = await dio.get('/reports/dashboard');
      final data = parseEnvelopeData(
        res,
        (d) => DashboardData.fromJson(Map<String, dynamic>.from(d as Map)),
      );
      expect(data.todaySales, isNotNull);
      expect(data.lowStockCount, greaterThanOrEqualTo(0));
    }, skip: skipLive);

    test('GET /invoices returns paginated list envelope', () async {
      final res = await dio.get('/invoices', queryParameters: {'per_page': 5});
      final parsed = parseEnvelopeList(res, Invoice.fromJson);
      expect(parsed.items, isA<List<Invoice>>());
      expect(parsed.meta?.perPage, greaterThan(0));
    }, skip: skipLive);

    test('GET /products/search returns product list', () async {
      final res = await dio.get('/products/search', queryParameters: {'q': 'a'});
      final products = parseEnvelopeData(
        res,
        (data) => listFromData(data, Product.fromJson),
      );
      expect(products, isA<List<Product>>());
    }, skip: skipLive);
  });
}

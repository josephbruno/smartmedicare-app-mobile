import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../json_helpers.dart';
import '../models/product.dart';
import '../models/product_datasheet.dart';

class ProductDatasheetService {
  ProductDatasheetService(this._client);

  final ApiClient _client;

  Future<ProductDatasheet> current() async {
    try {
      final res = await _client.get('/product-datasheets/current');
      return parseEnvelopeData(
        res,
        (data) => ProductDatasheet.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<ProductDatasheet> create({String? title, int emptyRows = 10}) async {
    try {
      final res = await _client.post('/product-datasheets', data: {
        if (title != null) 'title': title,
        'empty_rows': emptyRows,
      });
      return parseEnvelopeData(
        res,
        (data) => ProductDatasheet.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<ProductDatasheet> get(int id) async {
    try {
      final res = await _client.get('/product-datasheets/$id');
      return parseEnvelopeData(
        res,
        (data) => ProductDatasheet.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<ProductDatasheet> addRows(int datasheetId, {int count = 5}) async {
    try {
      final res = await _client.post('/product-datasheets/$datasheetId/rows', data: {
        'count': count,
      });
      return parseEnvelopeData(
        res,
        (data) => ProductDatasheet.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<ProductDatasheetRow> updateRow(
    int datasheetId,
    int rowId,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _client.put(
        '/product-datasheets/$datasheetId/rows/$rowId',
        data: body,
      );
      return parseEnvelopeData(
        res,
        (data) =>
            ProductDatasheetRow.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<ProductDatasheetRow> resolveCatalog({
    required int datasheetId,
    required int rowId,
    required String type,
    required String name,
  }) async {
    try {
      final res = await _client.post(
        '/product-datasheets/$datasheetId/rows/$rowId/resolve-catalog',
        data: {'type': type, 'name': name},
      );
      return parseEnvelopeData(res, (data) {
        final map = Map<String, dynamic>.from(data as Map);
        final row = map['row'];
        return ProductDatasheetRow.fromJson(Map<String, dynamic>.from(row as Map));
      });
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Product?> lookupProduct({String? barcode, String? sku}) async {
    try {
      final res = await _client.get('/product-datasheets/lookup-product', queryParameters: {
        if (barcode != null && barcode.isNotEmpty) 'barcode': barcode,
        if (sku != null && sku.isNotEmpty) 'sku': sku,
      });
      return parseEnvelopeData(
        res,
        (data) => Product.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      ApiClient.throwFromDio(e);
    }
  }

  Future<ProductDatasheetRow> applyMatch({
    required int datasheetId,
    required int rowId,
    int? productId,
    String? barcode,
    String? sku,
  }) async {
    try {
      final res = await _client.post(
        '/product-datasheets/$datasheetId/rows/$rowId/apply-match',
        data: {
          if (productId != null) 'product_id': productId,
          if (barcode != null) 'barcode': barcode,
          if (sku != null) 'sku': sku,
        },
      );
      return parseEnvelopeData(
        res,
        (data) =>
            ProductDatasheetRow.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<ProductDatasheetRow> syncRow(int datasheetId, int rowId) async {
    try {
      final res = await _client.post(
        '/product-datasheets/$datasheetId/rows/$rowId/sync',
      );
      return parseEnvelopeData(
        res,
        (data) =>
            ProductDatasheetRow.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<({Map<String, dynamic> result, ProductDatasheet sheet})> syncAll(
    int datasheetId,
  ) async {
    try {
      final res = await _client.post('/product-datasheets/$datasheetId/sync-all');
      return parseEnvelopeData(res, (data) {
        final map = Map<String, dynamic>.from(data as Map);
        return (
          result: Map<String, dynamic>.from(map['result'] as Map? ?? {}),
          sheet: ProductDatasheet.fromJson(
            Map<String, dynamic>.from(map['sheet'] as Map),
          ),
        );
      });
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> deleteRow(int datasheetId, int rowId) async {
    try {
      await _client.delete('/product-datasheets/$datasheetId/rows/$rowId');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}

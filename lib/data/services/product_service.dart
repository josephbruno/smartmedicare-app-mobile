import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../json_helpers.dart';
import '../models/api_response.dart';
import '../models/product.dart';

class ProductService {
  ProductService(this._client);

  final ApiClient _client;

  Future<List<Product>> list({Map<String, dynamic>? query}) async {
    try {
      final res = await _client.get('/products', queryParameters: query);
      return parseEnvelopeData(res, (data) => listFromData(data, Product.fromJson));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<Product>> posList({Map<String, dynamic>? query}) async {
    final result = await posPaginated(
      page: int.tryParse(query?['page']?.toString() ?? '') ?? 1,
      perPage: int.tryParse(query?['per_page']?.toString() ?? '') ?? 50,
      categoryId: int.tryParse(query?['category_id']?.toString() ?? ''),
      search: query?['search']?.toString(),
    );
    return result.items;
  }

  Future<({List<Product> items, PaginationMeta? meta})> posPaginated({
    int page = 1,
    int perPage = 50,
    int? categoryId,
    String? search,
  }) async {
    try {
      final res = await _client.get('/products/pos', queryParameters: {
        'page': page,
        'per_page': perPage,
        if (categoryId != null) 'category_id': categoryId,
        if (search != null && search.isNotEmpty) 'search': search,
      });
      return parseEnvelopeList(res, Product.fromJson);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<Product>> posSync({required String since}) async {
    try {
      final res = await _client.get('/products/pos-sync', queryParameters: {
        'since': since,
      });
      return parseEnvelopeData(res, (data) => listFromData(data, Product.fromJson));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Product> get(int id) async {
    try {
      final res = await _client.get('/products/$id');
      return parseEnvelopeData(
        res,
        (data) => Product.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Product> create(Map<String, dynamic> body) async {
    try {
      final res = await _client.post('/products', data: body);
      return parseEnvelopeData(
        res,
        (data) => Product.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Product> update(int id, Map<String, dynamic> body) async {
    try {
      final res = await _client.put('/products/$id', data: body);
      return parseEnvelopeData(
        res,
        (data) => Product.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<Product>> search(String q) async {
    try {
      final res = await _client.get('/products/search', queryParameters: {'q': q});
      return parseEnvelopeData(res, (data) => listFromData(data, Product.fromJson));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Product?> findByBarcode(String barcode) async {
    try {
      final res = await _client.get('/products/barcode', queryParameters: {
        'barcode': barcode,
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

  Future<List<Category>> listCategories({Map<String, dynamic>? query}) async {
    try {
      final res = await _client.get('/categories', queryParameters: query);
      return parseEnvelopeData(res, (data) => listFromData(data, Category.fromJson));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<Brand>> listBrands({Map<String, dynamic>? query}) async {
    try {
      final res = await _client.get('/brands', queryParameters: query);
      return parseEnvelopeData(res, (data) => listFromData(data, Brand.fromJson));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}

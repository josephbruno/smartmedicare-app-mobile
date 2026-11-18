import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../json_helpers.dart';
import '../models/api_response.dart';
import '../models/product.dart';

class ProductService {
  ProductService(this._client);

  final ApiClient _client;

  Future<List<Product>> list({Map<String, dynamic>? query}) async {
    bool? isActive;
    final rawActive = query?['is_active'];
    if (rawActive is bool) {
      isActive = rawActive;
    } else if (rawActive != null) {
      final s = rawActive.toString().toLowerCase();
      if (s == 'true' || s == '1') isActive = true;
      if (s == 'false' || s == '0') isActive = false;
    }
    final result = await listPaginated(
      page: int.tryParse(query?['page']?.toString() ?? '') ?? 1,
      perPage: int.tryParse(query?['per_page']?.toString() ?? '') ?? 20,
      search: query?['search']?.toString(),
      type: query?['type']?.toString(),
      isActive: isActive,
      treatmentUnderCategory: query?['treatment_under_category']?.toString(),
      prescriptionUnderCategory: query?['prescription_under_category']?.toString(),
      investigationUnderCategory: query?['investigation_under_category']?.toString(),
    );
    return result.items;
  }

  /// Loads every page of matching products (the index API is paginated).
  Future<List<Product>> listAll({
    String? search,
    String? type,
    bool? isActive,
    int perPage = 100,
  }) async {
    final all = <Product>[];
    var page = 1;
    var lastPage = 1;
    const maxPages = 100;
    do {
      final result = await listPaginated(
        page: page,
        perPage: perPage,
        search: search,
        type: type,
        isActive: isActive,
      );
      all.addAll(result.items);
      lastPage = result.meta?.lastPage ?? 1;
      if (result.items.isEmpty) break;
      page++;
    } while (page <= lastPage && page <= maxPages);
    return all;
  }

  Future<({List<Product> items, PaginationMeta? meta})> listPaginated({
    int page = 1,
    int perPage = 20,
    String? search,
    String? type,
    int? categoryId,
    bool? isActive,
    String? treatmentUnderCategory,
    String? prescriptionUnderCategory,
    String? investigationUnderCategory,
    Map<String, dynamic> filters = const {},
  }) async {
    try {
      final res = await _client.get('/products', queryParameters: {
        'page': page,
        'per_page': perPage,
        for (final e in filters.entries)
          if (e.value != null && e.value.toString().isNotEmpty) e.key: e.value,
        if (search != null && search.isNotEmpty) 'search': search,
        if (type != null && type.isNotEmpty) 'type': type,
        if (categoryId != null) 'category_id': categoryId,
        if (isActive != null) 'is_active': isActive,
        if (treatmentUnderCategory != null && treatmentUnderCategory.isNotEmpty)
          'treatment_under_category': treatmentUnderCategory,
        if (prescriptionUnderCategory != null &&
            prescriptionUnderCategory.isNotEmpty)
          'prescription_under_category': prescriptionUnderCategory,
        if (investigationUnderCategory != null &&
            investigationUnderCategory.isNotEmpty)
          'investigation_under_category': investigationUnderCategory,
      });
      return parseEnvelopeList(res, Product.fromJson);
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

  /// Catalogue-wide stock counts for the Products KPI cards.
  Future<Map<String, int>> stats() async {
    try {
      final res = await _client.get('/products/stats');
      return parseEnvelopeData(res, (data) {
        final m = data is Map ? data : const {};
        return {
          for (final k in ['total', 'in_stock', 'low_stock', 'out_of_stock'])
            k: (m[k] as num?)?.toInt() ?? 0,
        };
      });
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _client.delete('/products/$id');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Sample import sheet (xlsx bytes).
  Future<List<int>> importTemplateBytes() async {
    try {
      final res = await _client.get<List<int>>(
        '/products/import/template',
        options: Options(responseType: ResponseType.bytes),
      );
      return res.data ?? const [];
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Imports products from an Excel/CSV file. Returns
  /// `{created, updated, failed, total, errors}`.
  Future<Map<String, dynamic>> importFile({
    required String fileName,
    String? path,
    List<int>? bytes,
  }) async {
    try {
      final file = bytes != null
          ? MultipartFile.fromBytes(bytes, filename: fileName)
          : await MultipartFile.fromFile(path!, filename: fileName);
      final res = await _client.post('/products/import', data: FormData.fromMap({'file': file}));
      return parseEnvelopeData(res, (data) => Map<String, dynamic>.from(data as Map));
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

  Future<List<Unit>> listUnits({Map<String, dynamic>? query}) async {
    try {
      final res = await _client.get('/units', queryParameters: query);
      return parseEnvelopeData(res, (data) => listFromData(data, Unit.fromJson));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  // --- Categories ---
  Future<Category> createCategory(Map<String, dynamic> body) async {
    try {
      final res = await _client.post('/categories', data: body);
      return parseEnvelopeData(
        res,
        (data) => Category.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Category> updateCategory(int id, Map<String, dynamic> body) async {
    try {
      final res = await _client.put('/categories/$id', data: body);
      return parseEnvelopeData(
        res,
        (data) => Category.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      await _client.delete('/categories/$id');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  // --- Brands ---
  Future<Brand> createBrand(Map<String, dynamic> body) async {
    try {
      final res = await _client.post('/brands', data: body);
      return parseEnvelopeData(
        res,
        (data) => Brand.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Brand> updateBrand(int id, Map<String, dynamic> body) async {
    try {
      final res = await _client.put('/brands/$id', data: body);
      return parseEnvelopeData(
        res,
        (data) => Brand.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> deleteBrand(int id) async {
    try {
      await _client.delete('/brands/$id');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  // --- Units ---
  Future<Unit> createUnit(Map<String, dynamic> body) async {
    try {
      final res = await _client.post('/units', data: body);
      return parseEnvelopeData(
        res,
        (data) => Unit.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Unit> updateUnit(int id, Map<String, dynamic> body) async {
    try {
      final res = await _client.put('/units/$id', data: body);
      return parseEnvelopeData(
        res,
        (data) => Unit.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> deleteUnit(int id) async {
    try {
      await _client.delete('/units/$id');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}

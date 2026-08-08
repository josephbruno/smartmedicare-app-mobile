import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../json_helpers.dart';
import '../models/advance_transaction.dart';
import '../models/api_response.dart';
import '../models/customer.dart';

class CustomerService {
  CustomerService(this._client);

  final ApiClient _client;

  Future<List<Customer>> list({Map<String, dynamic>? query}) async {
    final result = await listPaginated(
      page: int.tryParse(query?['page']?.toString() ?? '') ?? 1,
      perPage: int.tryParse(query?['per_page']?.toString() ?? '') ?? 20,
      search: query?['search']?.toString(),
    );
    return result.items;
  }

  Future<({List<Customer> items, PaginationMeta? meta})> listPaginated({
    int page = 1,
    int perPage = 50,
    String? search,
  }) async {
    try {
      final res = await _client.get('/customers', queryParameters: {
        'page': page,
        'per_page': perPage,
        if (search != null && search.isNotEmpty) 'search': search,
      });
      return parseEnvelopeList(res, Customer.fromJson);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Customer> get(int id) async {
    try {
      final res = await _client.get('/customers/$id');
      return parseEnvelopeData(
        res,
        (data) => Customer.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<Customer>> search(String q) async {
    try {
      final res =
          await _client.get('/customers/search', queryParameters: {'q': q});
      return parseEnvelopeData(res, (data) => listFromData(data, Customer.fromJson));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Customer> create(Map<String, dynamic> body) async {
    try {
      final res = await _client.post('/customers', data: body);
      return parseEnvelopeData(
        res,
        (data) => Customer.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Customer> update(int id, Map<String, dynamic> body) async {
    try {
      final res = await _client.put('/customers/$id', data: body);
      return parseEnvelopeData(
        res,
        (data) => Customer.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Pet> createPet(Map<String, dynamic> body) async {
    try {
      final res = await _client.post('/pets', data: body);
      return parseEnvelopeData(
        res,
        (data) => Pet.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Pet> updatePet(int id, Map<String, dynamic> body) async {
    try {
      final res = await _client.put('/pets/$id', data: body);
      return parseEnvelopeData(
        res,
        (data) => Pet.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<PetSpecies>> listPetSpecies({String? search}) async {
    try {
      final res = await _client.get('/pet-species', queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
      });
      return parseEnvelopeData(
        res,
        (data) => listFromData(data, PetSpecies.fromJson),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<PetBreed>> listPetBreeds({
    int? speciesId,
    String? species,
    String? search,
  }) async {
    try {
      final res = await _client.get('/pet-breeds', queryParameters: {
        if (speciesId != null) 'species_id': speciesId,
        if (species != null && species.isNotEmpty) 'species': species,
        if (search != null && search.isNotEmpty) 'search': search,
      });
      return parseEnvelopeData(
        res,
        (data) => listFromData(data, PetBreed.fromJson),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<PetSpecies>> adminListPetSpecies({String? search}) async {
    try {
      final res = await _client.get('/pets/master-data/species', queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
      });
      return parseEnvelopeData(
        res,
        (data) => listFromData(data, PetSpecies.fromJson),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<PetSpecies> createPetSpecies(Map<String, dynamic> body) async {
    try {
      final res = await _client.post('/pets/master-data/species', data: body);
      return parseEnvelopeData(
        res,
        (data) => PetSpecies.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<PetSpecies> updatePetSpecies(int id, Map<String, dynamic> body) async {
    try {
      final res = await _client.put('/pets/master-data/species/$id', data: body);
      return parseEnvelopeData(
        res,
        (data) => PetSpecies.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> deactivatePetSpecies(int id) async {
    try {
      await _client.delete('/pets/master-data/species/$id');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<PetBreed>> adminListPetBreeds({
    int? speciesId,
    String? search,
  }) async {
    try {
      final res = await _client.get('/pets/master-data/breeds', queryParameters: {
        if (speciesId != null) 'species_id': speciesId,
        if (search != null && search.isNotEmpty) 'search': search,
      });
      return parseEnvelopeData(
        res,
        (data) => listFromData(data, PetBreed.fromJson),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<PetBreed> createPetBreed(Map<String, dynamic> body) async {
    try {
      final res = await _client.post('/pets/master-data/breeds', data: body);
      return parseEnvelopeData(
        res,
        (data) => PetBreed.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<PetBreed> updatePetBreed(int id, Map<String, dynamic> body) async {
    try {
      final res = await _client.put('/pets/master-data/breeds/$id', data: body);
      return parseEnvelopeData(
        res,
        (data) => PetBreed.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> deactivatePetBreed(int id) async {
    try {
      await _client.delete('/pets/master-data/breeds/$id');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<({List<AdvanceTransaction> items, double advanceBalance})>
      listAdvances(int customerId, {int page = 1}) async {
    try {
      final res = await _client.get(
        '/customers/$customerId/advances',
        queryParameters: {'page': page, 'per_page': 30},
      );
      final map = responseAsMap(res);
      final meta = map['meta'] is Map
          ? Map<String, dynamic>.from(map['meta'] as Map)
          : <String, dynamic>{};
      final items = listFromData(map['data'], AdvanceTransaction.fromJson);
      return (
        items: items,
        advanceBalance: numOrNull(meta['advance_balance']) ?? 0,
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<({AdvanceTransaction txn, double advanceBalance})> recordAdvance(
    int customerId,
    Map<String, dynamic> body,
  ) async {
    try {
      final res =
          await _client.post('/customers/$customerId/advances', data: body);
      final map = responseAsMap(res);
      final meta = map['meta'] is Map
          ? Map<String, dynamic>.from(map['meta'] as Map)
          : <String, dynamic>{};
      final txn = AdvanceTransaction.fromJson(
        Map<String, dynamic>.from(map['data'] as Map),
      );
      return (
        txn: txn,
        advanceBalance: numOrNull(meta['advance_balance']) ?? 0,
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<({AdvanceTransaction txn, double advanceBalance})> refundAdvance(
    int customerId,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _client
          .post('/customers/$customerId/advances/refund', data: body);
      final map = responseAsMap(res);
      final meta = map['meta'] is Map
          ? Map<String, dynamic>.from(map['meta'] as Map)
          : <String, dynamic>{};
      final txn = AdvanceTransaction.fromJson(
        Map<String, dynamic>.from(map['data'] as Map),
      );
      return (
        txn: txn,
        advanceBalance: numOrNull(meta['advance_balance']) ?? 0,
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}

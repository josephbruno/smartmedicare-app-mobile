import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../data/json_helpers.dart';
import '../../../data/models/customer.dart';

/// Service for customer operations with search and CRUD.
class CustomerService {
  final ApiClient _apiClient;

  CustomerService(this._apiClient);

  /// Get all customers with optional filters.
  Future<List<Customer>> getCustomers({
    String? searchQuery,
    Map<String, dynamic>? filters,
    int? page,
    int? limit,
  }) async {
    try {
      final params = <String, dynamic>{
        if (searchQuery != null) 'q': searchQuery,
        if (page != null) 'page': page,
        if (limit != null) 'limit': limit,
        ...?filters,
      };

      final response = await _apiClient.get(
        '/customers',
        queryParameters: params,
      );

      final data = response.data as Map<String, dynamic>;
      final items = (data['data'] ?? data['customers'] ?? []) as List;
      return items.map((e) => Customer.fromJson(Map<String, dynamic>.from(e))).toList();
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Search customers by name, phone, or email.
  Future<List<Customer>> searchCustomers({
    required String query,
    Map<String, dynamic>? filters,
  }) async {
    if (query.isEmpty) {
      return getCustomers(filters: filters);
    }

    try {
      final params = <String, dynamic>{
        'q': query,
        ...?filters,
      };

      final response = await _apiClient.get(
        '/customers/search',
        queryParameters: params,
      );

      final data = response.data as Map<String, dynamic>;
      final items = (data['data'] ?? data['customers'] ?? []) as List;
      return items.map((e) => Customer.fromJson(Map<String, dynamic>.from(e))).toList();
    } on DioException catch (e) {
      // Fallback to client-side search if endpoint not available
      return _clientSideSearch(query, filters: filters);
    }
  }

  /// Client-side search (fallback).
  Future<List<Customer>> _clientSideSearch(
    String query, {
    Map<String, dynamic>? filters,
  }) async {
    final customers = await getCustomers(filters: filters);
    final lowerQuery = query.toLowerCase();

    return customers.where((customer) {
      return customer.name.toLowerCase().contains(lowerQuery) ||
          customer.phone.toLowerCase().contains(lowerQuery) ||
          (customer.email?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  /// Get a single customer by ID.
  Future<Customer?> getCustomer(int id) async {
    try {
      final response = await _apiClient.get('/customers/$id');
      return Customer.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      ApiClient.throwFromDio(e);
    }
  }

  /// Create a new customer.
  Future<Customer> createCustomer({
    required String name,
    required String phone,
    String? email,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? gstin,
    String? panNumber,
    bool isActive = true,
  }) async {
    try {
      final response = await _apiClient.post(
        '/customers',
        data: {
          'name': name,
          'phone': phone,
          if (email != null) 'email': email,
          if (address != null) 'address': address,
          if (city != null) 'city': city,
          if (state != null) 'state': state,
          if (pincode != null) 'pincode': pincode,
          if (gstin != null) 'gstin': gstin,
          if (panNumber != null) 'pan_number': panNumber,
          'is_active': isActive,
        },
      );

      return Customer.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Update an existing customer.
  Future<Customer> updateCustomer({
    required int id,
    required String name,
    required String phone,
    String? email,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? gstin,
    String? panNumber,
    bool? isActive,
  }) async {
    try {
      final response = await _apiClient.put(
        '/customers/$id',
        data: {
          'name': name,
          'phone': phone,
          if (email != null) 'email': email,
          if (address != null) 'address': address,
          if (city != null) 'city': city,
          if (state != null) 'state': state,
          if (pincode != null) 'pincode': pincode,
          if (gstin != null) 'gstin': gstin,
          if (panNumber != null) 'pan_number': panNumber,
          if (isActive != null) 'is_active': isActive,
        },
      );

      return Customer.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Delete a customer.
  Future<void> deleteCustomer(int id) async {
    try {
      await _apiClient.delete('/customers/$id');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Get customer transaction history.
  Future<List<Map<String, dynamic>>> getCustomerTransactions(int customerId) async {
    try {
      final response = await _apiClient.get(
        '/customers/$customerId/transactions',
      );

      final data = response.data as Map<String, dynamic>;
      return (data['data'] ?? []) as List<Map<String, dynamic>>;
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Get customer lifetime value.
  Future<double> getCustomerLifetimeValue(int customerId) async {
    try {
      final response = await _apiClient.get(
        '/customers/$customerId/lifetime-value',
      );

      final data = response.data as Map<String, dynamic>;
      return (numOrNull(data['lifetime_value']) ?? 0).toDouble();
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Add notes to a customer.
  Future<void> addCustomerNote(
    int customerId,
    String note,
  ) async {
    try {
      await _apiClient.post(
        '/customers/$customerId/notes',
        data: {'note': note},
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Get customer notes.
  Future<List<Map<String, dynamic>>> getCustomerNotes(int customerId) async {
    try {
      final response = await _apiClient.get(
        '/customers/$customerId/notes',
      );

      final data = response.data as Map<String, dynamic>;
      return (data['data'] ?? []) as List<Map<String, dynamic>>;
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Get active customers only.
  Future<List<Customer>> getActiveCustomers({String? searchQuery}) async {
    return getCustomers(
      searchQuery: searchQuery,
      filters: {'is_active': true},
    );
  }

  /// Get customers by city.
  Future<List<Customer>> getCustomersByCity(String city) async {
    return getCustomers(
      filters: {'city': city},
    );
  }

  /// Check if online for data sync decision.
  Future<bool> isOnline() async {
    final connectivity = await Connectivity().checkConnectivity();
    return connectivity != ConnectivityResult.none;
  }
}

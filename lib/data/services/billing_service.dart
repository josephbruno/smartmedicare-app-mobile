import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../json_helpers.dart';
import '../models/invoice.dart';

class BillingService {
  BillingService(this._client);

  final ApiClient _client;

  Future<InvoiceListResult> list({Map<String, dynamic>? query}) async {
    try {
      final res = await _client.get('/invoices', queryParameters: query);
      final parsed = parseEnvelopeList(res, Invoice.fromJson);
      InvoiceListSummary? summary;
      final map = responseAsMap(res);
      if (map['meta'] is Map) {
        final meta = Map<String, dynamic>.from(map['meta'] as Map);
        if (meta['summary'] is Map) {
          summary = InvoiceListSummary.fromJson(
            Map<String, dynamic>.from(meta['summary'] as Map),
          );
        }
      }
      return InvoiceListResult(
        items: parsed.items,
        pagination: parsed.meta,
        summary: summary,
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<Invoice>> listSimple({Map<String, dynamic>? query}) async {
    final result = await list(query: query);
    return result.items;
  }

  Future<Invoice> get(int id) async {
    try {
      final res = await _client.get('/invoices/$id');
      return parseEnvelopeData(
        res,
        (data) => Invoice.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Invoice> create(Map<String, dynamic> payload) async {
    try {
      final res = await _client.post('/invoices', data: payload);
      return parseEnvelopeData(
        res,
        (data) => Invoice.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<Invoice> recordPayment(
    int id, {
    required String mode,
    required double amount,
    double? tenderedAmount,
    String? reference,
    String? upiId,
  }) async {
    try {
      final res = await _client.post('/invoices/$id/payments', data: {
        'mode': mode,
        'amount': amount,
        if (tenderedAmount != null) 'tendered_amount': tenderedAmount,
        if (reference != null && reference.isNotEmpty) 'reference': reference,
        if (upiId != null && upiId.isNotEmpty) 'upi_id': upiId,
      });
      return parseEnvelopeData(
        res,
        (data) => Invoice.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<void> cancel(int id) async {
    try {
      await _client.post('/invoices/$id/cancel');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<bool> sendWhatsApp(int id, {String? phone}) async {
    try {
      final payload = phone != null ? {'phone': phone} : <String, dynamic>{};
      final res = await _client.post('/invoices/$id/send-whatsapp', data: payload);
      final map = res.data;
      if (map is Map) {
        return map['success'] == true;
      }
      return false;
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<dynamic>> syncOffline(List<Map<String, dynamic>> invoices) async {
    try {
      final res =
          await _client.post('/invoices/sync-offline', data: {'invoices': invoices});
      return parseEnvelopeData(res, (data) {
        if (data is List) return data;
        return <dynamic>[];
      });
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<List<int>> getPdfBytes(int id) async {
    try {
      final res = await _client.get<List<int>>(
        '/invoices/$id/pdf',
        options: Options(responseType: ResponseType.bytes),
      );
      return res.data ?? [];
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}

import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../json_helpers.dart';
import '../models/plan_catalog.dart';
import '../models/subscription_info.dart';

/// Plan / validity and the website billing-portal handoff. These endpoints stay
/// available after the subscription lapses so users can renew.
class SubscriptionService {
  SubscriptionService(this._client);

  final ApiClient _client;

  Future<SubscriptionInfo> get() async {
    try {
      final res = await _client.get('/subscription');
      return parseEnvelopeData(
        res,
        (data) =>
            SubscriptionInfo.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Current plan features and upgrade options (organization owner only).
  Future<PlanCatalog> plans() async {
    try {
      final res = await _client.get('/subscription/plans');
      return parseEnvelopeData(
        res,
        (data) => PlanCatalog.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// One-time signed-in link to the billing portal ([page]: account, plans, payments, history).
  /// [planSlug] / [billingCycle] preselect a plan on the portal's plan page.
  Future<String> manageLink(
      {String page = 'plans', String? planSlug, String? billingCycle}) async {
    try {
      final res = await _client.post('/subscription/manage-link', data: {
        'redirect': page,
        if (planSlug != null) 'plan_slug': planSlug,
        if (billingCycle != null) 'billing_cycle': billingCycle,
      });
      return parseEnvelopeData(
          res, (data) => mapOrNull(data)!['url'].toString());
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}

import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../json_helpers.dart';
import '../models/api_response.dart';

class WhatsAppPack {
  WhatsAppPack({required this.slug, required this.name, required this.points, required this.priceInr});

  final String slug;
  final String name;
  final int points;
  final double priceInr;

  factory WhatsAppPack.fromJson(Map<String, dynamic> j) => WhatsAppPack(
        slug: j['slug']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        points: intOrNull(j['points']) ?? 0,
        priceInr: numOrNull(j['price_inr']) ?? 0,
      );
}

class WhatsAppTransaction {
  WhatsAppTransaction({
    required this.id,
    required this.type,
    required this.points,
    this.packSlug,
    this.referenceType,
    this.reason,
    this.createdAt,
  });

  final int id;

  /// bonus | purchase | usage | refund | adjustment
  final String type;
  final int points;
  final String? packSlug;
  final String? referenceType;
  final String? reason;
  final String? createdAt;

  factory WhatsAppTransaction.fromJson(Map<String, dynamic> j) => WhatsAppTransaction(
        id: intOrNull(j['id']) ?? 0,
        type: j['type']?.toString() ?? '',
        points: intOrNull(j['points']) ?? 0,
        packSlug: j['pack_slug']?.toString(),
        referenceType: j['reference_type']?.toString(),
        reason: j['meta'] is Map ? (j['meta'] as Map)['reason']?.toString() : null,
        createdAt: j['created_at']?.toString(),
      );

  String get description => switch (type) {
        'bonus' => 'Welcome bonus',
        'purchase' => (packSlug ?? '').isEmpty
            ? 'Bought points'
            : 'Bought ${packSlug![0].toUpperCase()}${packSlug!.substring(1)} pack',
        'usage' => referenceType == 'visit' ? 'Visit record sent' : 'Invoice sent',
        'refund' => 'Refund (message not delivered)',
        _ => reason ?? 'Adjustment',
      };
}

class WhatsAppWallet {
  WhatsAppWallet({
    required this.balance,
    required this.canManage,
    required this.costPerMessage,
    required this.packs,
  });

  final int balance;
  final bool canManage;
  final int costPerMessage;
  final List<WhatsAppPack> packs;

  factory WhatsAppWallet.fromJson(Map<String, dynamic> j) => WhatsAppWallet(
        balance: intOrNull(j['balance']) ?? 0,
        canManage: j['can_manage'] == true,
        costPerMessage: intOrNull(j['cost_per_message']) ?? 1,
        packs: listFromData(j['packs'], WhatsAppPack.fromJson),
      );
}

/// WhatsApp points wallet (`/whatsapp/*`). 1 point per message; the API
/// answers HTTP 402 when the balance is zero.
class WhatsAppService {
  WhatsAppService(this._client);

  final ApiClient _client;

  Future<WhatsAppWallet> wallet() async {
    try {
      final res = await _client.get('/whatsapp/wallet');
      return parseEnvelopeData(res, (d) => WhatsAppWallet.fromJson(Map<String, dynamic>.from(d as Map)));
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  Future<({List<WhatsAppTransaction> items, PaginationMeta? meta})> transactions({int page = 1, int perPage = 10}) async {
    try {
      final res = await _client.get('/whatsapp/transactions', queryParameters: {'page': page, 'per_page': perPage});
      return parseEnvelopeList(res, WhatsAppTransaction.fromJson);
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }

  /// Single-use link to the website checkout for a points pack (owner only).
  Future<String> checkoutLink(String packSlug) async {
    try {
      final res = await _client.post('/whatsapp/checkout-link', data: {'pack_slug': packSlug});
      return parseEnvelopeData(res, (d) => (d as Map)['url']?.toString() ?? '');
    } on DioException catch (e) {
      ApiClient.throwFromDio(e);
    }
  }
}

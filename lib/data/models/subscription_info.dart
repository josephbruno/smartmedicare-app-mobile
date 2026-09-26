/// A plan module (config/plan_modules.php) and whether this organization's plan has it.
class PlanModuleInfo {
  const PlanModuleInfo({
    required this.key,
    required this.label,
    this.core = false,
    this.included = false,
    this.capabilities = const [],
  });

  final String key;
  final String label;
  final bool core;
  final bool included;
  final List<String> capabilities;

  factory PlanModuleInfo.fromJson(Map<String, dynamic> j) => PlanModuleInfo(
        key: j['key']?.toString() ?? '',
        label: j['label']?.toString() ?? '',
        core: j['core'] == true,
        included: j['included'] == true,
        capabilities: (j['capabilities'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );

  Map<String, dynamic> toJson() =>
      {'key': key, 'label': label, 'core': core, 'included': included, 'capabilities': capabilities};
}

/// The organization's SmartMediCare plan and validity (GET /subscription, or
/// `shop.subscription` on /auth/me).
class SubscriptionInfo {
  SubscriptionInfo({
    this.status,
    required this.state,
    this.billingCycle,
    this.amount,
    this.startsAt,
    this.expiresAt,
    this.graceEndsAt,
    this.daysRemaining = 0,
    this.reminderDays = 7,
    this.planName,
    this.planSlug,
    this.maxBranches,
    this.maxUsers,
    this.maxProducts,
    this.canManage,
    this.modules = const [],
    this.usage = const {},
    this.limits = const {},
  });

  /// Raw status: trial | active | expired | cancelled | suspended.
  final String? status;

  /// Effective state from the server: trial | active | grace | expired | inactive.
  final String state;
  final String? billingCycle;
  final double? amount;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final DateTime? graceEndsAt;
  final int daysRemaining;
  final int reminderDays;
  final String? planName;
  final String? planSlug;
  final int? maxBranches;
  final int? maxUsers;
  final int? maxProducts;

  /// Only present on GET /subscription.
  final bool? canManage;

  /// Every plan module, flagged by whether the plan includes it (GET /subscription).
  final List<PlanModuleInfo> modules;

  /// Current counts: users / branches / products (GET /subscription).
  final Map<String, int> usage;

  /// Plan limits; a missing or null value means unlimited.
  final Map<String, int?> limits;

  /// True when `resource` (users / branches / products) is at its plan limit.
  bool atLimit(String resource) {
    final max = limits[resource];
    final used = usage[resource];
    return max != null && used != null && used >= max;
  }

  /// State recomputed from the dates, since a cached session can be days old.
  String get liveState {
    final end = expiresAt;
    if (end == null || !const ['trial', 'active', 'grace'].contains(state)) {
      return state;
    }
    final now = DateTime.now();
    if (end.isAfter(now)) return status == 'trial' ? 'trial' : 'active';
    final grace = graceEndsAt;
    return grace != null && grace.isAfter(now) ? 'grace' : 'expired';
  }

  int get liveDaysRemaining {
    final end = expiresAt;
    if (end == null) return daysRemaining;
    final seconds = end.difference(DateTime.now()).inSeconds;
    return seconds <= 0 ? 0 : (seconds / 86400).ceil();
  }

  bool get nearEnd => expiresAt != null && liveDaysRemaining <= reminderDays;

  bool get isUsable => const ['trial', 'active', 'grace'].contains(liveState);

  /// Show the banner: for the whole trial, close to expiry, or during grace.
  bool get needsAttention {
    final s = liveState;
    if (s == 'grace' || s == 'trial') return true;
    return (s == 'active' || s == 'trial') &&
        expiresAt != null &&
        liveDaysRemaining <= reminderDays;
  }

  String get stateLabel => switch (liveState) {
        'trial' => 'Free trial',
        'active' => 'Active',
        'grace' => 'Expired — grace period',
        'expired' => 'Expired',
        _ => 'Inactive',
      };

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  static int? _int(dynamic v) => (v as num?)?.toInt();

  factory SubscriptionInfo.fromJson(Map<String, dynamic> j) {
    final plan = j['plan'] is Map ? Map<String, dynamic>.from(j['plan'] as Map) : null;
    return SubscriptionInfo(
      status: j['status']?.toString(),
      state: j['state']?.toString() ?? 'inactive',
      billingCycle: j['billing_cycle']?.toString(),
      amount: (j['amount'] as num?)?.toDouble(),
      startsAt: _date(j['starts_at']),
      expiresAt: _date(j['expires_at']),
      graceEndsAt: _date(j['grace_ends_at']),
      daysRemaining: _int(j['days_remaining']) ?? 0,
      reminderDays: _int(j['reminder_days']) ?? 7,
      planName: plan?['name']?.toString(),
      planSlug: plan?['slug']?.toString(),
      maxBranches: _int(plan?['max_branches']),
      maxUsers: _int(plan?['max_users']),
      maxProducts: _int(plan?['max_products']),
      canManage: j['can_manage'] as bool?,
      modules: (j['modules'] as List?)
              ?.whereType<Map>()
              .map((m) => PlanModuleInfo.fromJson(Map<String, dynamic>.from(m)))
              .toList() ??
          const [],
      usage: j['usage'] is Map
          ? (j['usage'] as Map).map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0))
          : const {},
      limits: j['limits'] is Map
          ? (j['limits'] as Map).map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt()))
          : const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'state': state,
        'billing_cycle': billingCycle,
        'amount': amount,
        'starts_at': startsAt?.toUtc().toIso8601String(),
        'expires_at': expiresAt?.toUtc().toIso8601String(),
        'grace_ends_at': graceEndsAt?.toUtc().toIso8601String(),
        'days_remaining': daysRemaining,
        'reminder_days': reminderDays,
        if (planName != null)
          'plan': {
            'name': planName,
            'slug': planSlug,
            'max_branches': maxBranches,
            'max_users': maxUsers,
            'max_products': maxProducts,
          },
        if (canManage != null) 'can_manage': canManage,
        if (modules.isNotEmpty) 'modules': modules.map((m) => m.toJson()).toList(),
        if (usage.isNotEmpty) 'usage': usage,
        if (limits.isNotEmpty) 'limits': limits,
      };
}

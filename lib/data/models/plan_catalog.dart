/// A plan as sold on the website, with the app's limits (GET /subscription/plans).
class PlanCatalogItem {
  PlanCatalogItem({
    required this.slug,
    required this.name,
    this.description,
    required this.priceMonthly,
    required this.priceYearly,
    required this.features,
    this.isHighlighted = false,
    this.badgeText,
    this.maxBranches,
    this.maxUsers,
    this.maxProducts,
    this.modules = const [],
  });

  final String slug;
  final String name;
  final String? description;
  final int priceMonthly;
  final int priceYearly;
  final List<String> features;
  final bool isHighlighted;
  final String? badgeText;
  final int? maxBranches;
  final int? maxUsers;
  final int? maxProducts;

  /// Module keys the plan includes (lets the upgrade screen name the plans that unlock one).
  final List<String> modules;

  int priceFor(String cycle) => cycle == 'yearly' ? priceYearly : priceMonthly;

  factory PlanCatalogItem.fromJson(Map<String, dynamic> j) => PlanCatalogItem(
        slug: j['slug']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        description: j['description']?.toString(),
        priceMonthly: (j['price_monthly'] as num?)?.toInt() ?? 0,
        priceYearly: (j['price_yearly'] as num?)?.toInt() ?? 0,
        features: (j['features'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        isHighlighted: j['is_highlighted'] as bool? ?? false,
        badgeText: j['badge_text']?.toString(),
        maxBranches: (j['max_branches'] as num?)?.toInt(),
        maxUsers: (j['max_users'] as num?)?.toInt(),
        maxProducts: (j['max_products'] as num?)?.toInt(),
        modules: (j['modules'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
      );
}

class PlanCatalog {
  PlanCatalog(
      {this.currentSlug, this.billingCycle, this.current, required this.plans});

  final String? currentSlug;
  final String? billingCycle;
  final PlanCatalogItem? current;
  final List<PlanCatalogItem> plans;

  factory PlanCatalog.fromJson(Map<String, dynamic> j) => PlanCatalog(
        currentSlug: j['current_slug']?.toString(),
        billingCycle: j['billing_cycle']?.toString(),
        current: j['current'] is Map
            ? PlanCatalogItem.fromJson(
                Map<String, dynamic>.from(j['current'] as Map))
            : null,
        plans: (j['plans'] as List? ?? const [])
            .whereType<Map>()
            .map((p) => PlanCatalogItem.fromJson(Map<String, dynamic>.from(p)))
            .toList(),
      );
}

/// Subscription-plan capabilities a screen needs, by route path.
///
/// Mirrors the API's `capability:` route middleware (see
/// app/backend/config/plan_modules.php). The router sends a plan-locked path to
/// the Upgrade screen; the API refuses the same data with PLAN_UPGRADE_REQUIRED.
const Map<String, List<String>> _planCapabilitiesByPrefix = {
  '/products': ['inventory'], // Products page (POS / visit lookups use the API directly)
  '/inventory': ['inventory'],
  '/stock-alerts': ['inventory'],
  '/stock-ageing': ['inventory', 'advanced_reports'],
  '/stock-transfers': ['multi_branch'],
  '/purchases': ['purchases'],
  '/purchase-returns': ['purchases'],
  '/suppliers': ['purchases'],
  '/expenses': ['expenses'],
  '/emr/visits': ['clinical_visits'],
  '/emr/reminders': ['animal_vaccinations'],
  '/emr/appointments': ['appointments'],
  '/reports/sales': ['reports'],
  '/reports/payments': ['reports'],
  '/reports/visits': ['reports'],
  '/reports/gst': ['advanced_reports'],
  '/reports/stock-transfers': ['multi_branch'],
  '/settings/doctors': ['staff_management'],
};

/// Pet sub-pages that belong to medical records.
final RegExp _petRecordsPath = RegExp(r'^/emr/pets/[^/]+/(surgeries|lab-reports|documents)');

List<String> planCapabilitiesForPath(String path) {
  if (_petRecordsPath.hasMatch(path)) return const ['clinical_visits'];
  for (final entry in _planCapabilitiesByPrefix.entries) {
    if (path == entry.key || path.startsWith('${entry.key}/')) return entry.value;
  }
  return const [];
}

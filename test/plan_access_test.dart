import 'package:flutter_test/flutter_test.dart';
import 'package:maran/core/network/api_exception.dart';
import 'package:maran/core/router/plan_access.dart';
import 'package:maran/data/models/subscription_info.dart';

void main() {
  group('planCapabilitiesForPath', () {
    test('maps module screens to their plan capabilities', () {
      expect(planCapabilitiesForPath('/purchases'), ['purchases']);
      expect(planCapabilitiesForPath('/purchases/12'), ['purchases']);
      expect(planCapabilitiesForPath('/suppliers'), ['purchases']);
      expect(planCapabilitiesForPath('/stock-ageing'), ['inventory', 'advanced_reports']);
      expect(planCapabilitiesForPath('/stock-transfers/new'), ['multi_branch']);
      expect(planCapabilitiesForPath('/reports/gst'), ['advanced_reports']);
      expect(planCapabilitiesForPath('/emr/pets/7/lab-reports'), ['clinical_visits']);
      expect(planCapabilitiesForPath('/products'), ['inventory']);
      expect(planCapabilitiesForPath('/products/datasheet'), ['inventory']);
      expect(planCapabilitiesForPath('/emr/reminders'), ['animal_vaccinations']);
    });

    test('core screens need no plan capability', () {
      expect(planCapabilitiesForPath('/pos'), isEmpty);
      expect(planCapabilitiesForPath('/invoices/3'), isEmpty);
      expect(planCapabilitiesForPath('/pos/visits'), isEmpty);
      expect(planCapabilitiesForPath('/dashboard'), isEmpty);
    });

    test('prefix match does not bleed into similar paths', () {
      expect(planCapabilitiesForPath('/inventory-report-x'), isEmpty);
    });
  });

  test('ApiException recognises plan error codes', () {
    expect(ApiException('x', code: 'PLAN_UPGRADE_REQUIRED').isPlanError, isTrue);
    expect(ApiException('x', code: 'PLAN_LIMIT_REACHED').isPlanError, isTrue);
    expect(ApiException('x', code: 'CAPABILITY_NOT_AVAILABLE').isPlanError, isFalse);
  });

  test('SubscriptionInfo parses modules, usage and limits', () {
    final s = SubscriptionInfo.fromJson({
      'state': 'active',
      'modules': [
        {'key': 'purchases', 'label': 'Purchases', 'included': false, 'capabilities': ['purchases']},
      ],
      'usage': {'users': 3, 'branches': 1, 'products': 10},
      'limits': {'users': 3, 'branches': null, 'products': 500},
    });
    expect(s.modules.single.included, isFalse);
    expect(s.atLimit('users'), isTrue);
    expect(s.atLimit('branches'), isFalse); // unlimited
    expect(s.atLimit('products'), isFalse);
  });
}

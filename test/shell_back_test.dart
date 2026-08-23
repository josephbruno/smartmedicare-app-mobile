import 'package:flutter_test/flutter_test.dart';
import 'package:maran/core/navigation/shell_back.dart';

void main() {
  group('shellParentPath', () {
    test('list roots have no parent', () {
      expect(shellParentPath('/emr/visits'), isNull);
      expect(shellParentPath('/invoices'), isNull);
      expect(shellParentPath('/customers'), isNull);
      expect(shellParentPath('/settings'), isNull);
    });

    test('detail and edit routes map to parents', () {
      expect(shellParentPath('/emr/visits/12'), '/emr/visits');
      expect(shellParentPath('/emr/visits/12/edit'), '/emr/visits/12');
      expect(shellParentPath('/emr/visits/new'), '/emr/visits');
      expect(shellParentPath('/invoices/5'), '/invoices');
      expect(shellParentPath('/invoices/5/return'), '/invoices/5');
      expect(shellParentPath('/customers/3'), '/customers');
      expect(shellParentPath('/products/9/edit'), '/products');
      expect(shellParentPath('/products/datasheet'), '/products');
      expect(shellParentPath('/settings/security'), '/settings');
      expect(
        shellParentPath('/emr/pets/4/visit-summary'),
        '/patients',
      );
    });
  });
}

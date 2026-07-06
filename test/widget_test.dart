import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/maran_billing_app.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const MaranBillingApp());
    await tester.pump();
    expect(find.text('Sign in'), findsOneWidget);
  });
}

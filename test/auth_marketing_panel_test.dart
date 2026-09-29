import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maran/features/auth/widgets/auth_marketing_panel.dart';

void main() {
  testWidgets('marketing panel has no layout exception at mobile width',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: AuthMarketingPanel(compact: true),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('marketing panel has no layout exception at desktop width',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 708,
            height: 680,
            child: AuthMarketingPanel(),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}

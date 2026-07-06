import 'package:flutter/material.dart';

import 'data/local/database_init.dart';
import 'maran_billing_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initLocalDatabase();
  runApp(const MaranBillingApp());
}

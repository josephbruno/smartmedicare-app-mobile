import 'dart:async';

import 'package:flutter/material.dart';

import 'core/app_config.dart';
import 'core/network/network_resilience.dart';
import 'data/local/database_init.dart';
import 'maran_billing_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initLocalDatabase();
  // Best-effort DNS warm-up so the first login is less flaky on Windows.
  unawaited(warmApiDns(AppConfig.apiBaseUrl));
  runApp(const MaranBillingApp());
}

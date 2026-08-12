import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app_services.dart';
import 'core/app_config.dart';
import 'core/connectivity/connectivity_notifier.dart';
import 'core/messaging/app_messenger.dart';
import 'core/router/app_router.dart';
import 'core/session/auth_session.dart';
import 'core/theme/app_theme.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/notifications/visit_billing_poll_service.dart';
import 'core/connectivity/offline_sync_listener.dart';
import 'core/update/update_flow.dart';
import 'core/update/windows_update_gate.dart';
import 'data/local/customer_local_dao.dart';
import 'data/local/customer_sync_service.dart';
import 'data/local/offline_billing_coordinator.dart';
import 'data/local/offline_invoice_queue.dart';
import 'data/local/product_local_dao.dart';
import 'data/local/product_sync_service.dart';
import 'data/local/sync_coordinator.dart';
import 'data/local/sync_meta_dao.dart';
import 'data/local/app_database.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/pos_product_repository.dart';
import 'core/network/api_client.dart';
import 'data/services/auth_service.dart';
import 'features/pos/pos_cart_notifier.dart';
import 'features/emr/visit_billing_queue_notifier.dart';

class MaranBillingApp extends StatefulWidget {
  const MaranBillingApp({super.key});

  @override
  State<MaranBillingApp> createState() => _MaranBillingAppState();
}

class _MaranBillingAppState extends State<MaranBillingApp> {
  final GlobalKey<NavigatorState> _rootKey = GlobalKey<NavigatorState>();
  bool _windowsUpdateStarted = false;
  late final AuthSession _session;
  late final ApiClient _api;
  late final AppServices _services;
  late GoRouter _router;
  late final AuthRepository _authRepository;
  late final OfflineInvoiceQueue _offlineQueue;
  late final ProductLocalDao _productDao;
  late final CustomerLocalDao _customerDao;
  late final SyncMetaDao _syncMeta;
  late final ProductSyncService _productSync;
  late final CustomerSyncService _customerSync;
  late final OfflineBillingCoordinator _billingCoordinator;
  late final SyncCoordinator _syncCoordinator;
  late final PosProductRepository _posProducts;
  late final PushNotificationService _pushService;
  late final VisitBillingPollService _visitPollService;

  @override
  void initState() {
    super.initState();
    _session = AuthSession();
    _router = createAppRouter(auth: _session, rootNavigatorKey: _rootKey);
    _api = ApiClient(
      getToken: () => _session.token,
      getBranchId: () => _session.currentBranchId,
      isSuperAdmin: () => _session.isSuperAdmin,
      onUnauthorized: () {
        _session.logout();
        _router.go('/');
      },
      onSubscriptionExpired: () {
        _router.go('/subscription-expired');
      },
    );
    _services = AppServices(_api);
    _authRepository = AuthRepository(AuthService(_api));
    _offlineQueue = OfflineInvoiceQueue();
    _productDao = ProductLocalDao();
    _customerDao = CustomerLocalDao();
    _syncMeta = SyncMetaDao();
    _productSync = ProductSyncService(_services.products, _productDao, _syncMeta);
    _customerSync = CustomerSyncService(_services.customers, _customerDao, _syncMeta);
    _billingCoordinator = OfflineBillingCoordinator(_services.billing, _offlineQueue);
    _syncCoordinator = SyncCoordinator(
      productSync: _productSync,
      customerSync: _customerSync,
      billingCoordinator: _billingCoordinator,
    );
    _posProducts = PosProductRepository(_services.products, _productDao);
    _pushService = PushNotificationService(
      deviceTokens: _services.deviceTokens,
      auth: _session,
    );
    _visitPollService = VisitBillingPollService(
      emr: _services.emr,
      auth: _session,
      push: _pushService,
    );
    _session.bindRepository(_authRepository);
    _session.addListener(_onAuthSessionChanged);
    _session.restore().then((_) async {
      await _pushService.initialize(
        onTap: (data) => _pushService.handleRouterNavigation(_router, data),
      );
      _onAuthSessionChanged();
    });
    unawaited(AppDatabase.instance());
  }

  /// Hot reload keeps the old [GoRouter] instance (routes registered at start).
  /// Rebuild it in debug so newly added routes like Visit summary resolve.
  @override
  void reassemble() {
    super.reassemble();
    if (!kDebugMode) return;
    final loc = _router.routerDelegate.currentConfiguration.uri.toString();
    _router.dispose();
    _router = createAppRouter(auth: _session, rootNavigatorKey: _rootKey);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (loc.isNotEmpty && loc != '/') {
        _router.go(loc);
      }
    });
  }

  void _onAuthSessionChanged() {
    if (_session.isAuthenticated && _session.isUnlocked) {
      if (!_session.cashierPlatformAllowed) {
        _visitPollService.updateEnabled(false);
        return;
      }
      unawaited(_pushService.syncRegistration());
      _visitPollService.updateEnabled(
        _session.hasRole('cashier') && AppConfig.isCashierPlatform,
      );
    } else if (!_session.isAuthenticated) {
      unawaited(_pushService.unregister());
      _visitPollService.updateEnabled(false);
    }
  }

  @override
  void dispose() {
    _session.removeListener(_onAuthSessionChanged);
    _pushService.dispose();
    _visitPollService.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _session),
        Provider.value(value: _services),
        ChangeNotifierProvider(create: (_) => PosCartNotifier()),
        ChangeNotifierProvider(create: (_) => VisitBillingQueueNotifier()),
        ChangeNotifierProvider(create: (_) => ConnectivityNotifier()),
        Provider.value(value: _offlineQueue),
        Provider.value(value: _productDao),
        Provider.value(value: _customerDao),
        Provider.value(value: _syncMeta),
        Provider.value(value: _productSync),
        Provider.value(value: _customerSync),
        Provider.value(value: _billingCoordinator),
        ChangeNotifierProvider.value(value: _syncCoordinator),
        Provider.value(value: _posProducts),
        Provider.value(value: _pushService),
      ],
      child: MaterialApp.router(
        title: 'Maran Billing',
        scaffoldMessengerKey: AppMessenger.rootKey,
        theme: AppTheme.light(desktop: AppConfig.usesLargeUiScale),
        routerConfig: _router,
        builder: (context, child) {
          if (!_windowsUpdateStarted) {
            _windowsUpdateStarted = true;
            // Hold splash immediately so a fast splash finish cannot race
            // ahead of the post-frame update check.
            if (shouldRunWindowsUpdateFlow()) {
              WindowsUpdateGate.instance.acquire();
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final navCtx = _rootKey.currentContext;
              if (navCtx != null) {
                unawaited(runWindowsUpdateFlow(navCtx));
              } else {
                WindowsUpdateGate.instance.release();
              }
            });
          }
          Widget built = child ?? const SizedBox.shrink();
          built = OfflineSyncListener(child: built);
          if (!AppConfig.usesLargeUiScale) {
            return built;
          }
          // Scale up all text on web & native desktop.
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: TextScaler.linear(AppConfig.desktopTextScale),
            ),
            child: built,
          );
        },
      ),
    );
  }
}

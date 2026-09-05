import 'package:flutter/material.dart';

/// Observer for the app shell navigator so EMR screens can reload when
/// a pushed edit/preview route is popped.
final RouteObserver<ModalRoute<void>> appShellRouteObserver =
    RouteObserver<ModalRoute<void>>();

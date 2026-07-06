import 'package:flutter/widgets.dart';

import '../app_config.dart';

enum FormFactor { mobile, tablet, desktop }

FormFactor formFactorOf(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w < AppConfig.mobileCompactBreakpoint) return FormFactor.mobile;
  if (w < AppConfig.desktopLayoutBreakpoint) return FormFactor.tablet;
  return FormFactor.desktop;
}

bool useWebLikeShell(BuildContext context) =>
    formFactorOf(context) != FormFactor.mobile;

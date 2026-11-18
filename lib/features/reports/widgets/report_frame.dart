import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/web_page.dart';

/// Web page frame for report screens: breadcrumbs (Reports › title), header
/// with icon/title/subtitle, then the report's own toolbar + content.
class ReportFrame extends StatelessWidget {
  const ReportFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.group = 'Reports',
    this.actions = const [],
  });

  /// Breadcrumb group before the page title (e.g. Reports, Admin).
  final String group;
  final List<Widget> actions;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < AppTokens.bpTablet;
    final pad = narrow ? 12.0 : 16.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!narrow) PageBreadcrumbs(items: [Crumb(group), Crumb(title)]),
            PageHeader(title: title, subtitle: subtitle, icon: icon, actions: actions),
          ]),
        ),
        Expanded(child: child),
      ],
    );
  }
}

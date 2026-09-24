import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_services.dart';
import '../../core/network/api_exception.dart';

final _dateFormat = DateFormat('dd MMM yyyy');

String formatSubscriptionDate(DateTime? value) =>
    value == null ? '—' : _dateFormat.format(value);

final _inr =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

String formatInr(num amount) => _inr.format(amount);

/// Opens the website billing portal, already signed in, in the external browser.
/// Returns false (and shows an error) when the link could not be opened.
Future<bool> openBillingPortal(
  BuildContext context, {
  String page = 'plans',
  String? planSlug,
  String? billingCycle,
}) async {
  final services = context.read<AppServices>();
  try {
    final url = await services.subscription.manageLink(
      page: page,
      planSlug: planSlug,
      billingCycle: billingCycle,
    );
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      AppMessenger.error(
          context, 'Could not open the browser. Please try again.');
    }
    return opened;
  } on ApiException catch (e) {
    if (context.mounted) AppMessenger.error(context, e.message);
    return false;
  } catch (_) {
    if (context.mounted) {
      AppMessenger.error(
          context, 'Could not open the billing portal. Please try again.');
    }
    return false;
  }
}

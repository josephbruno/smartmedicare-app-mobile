import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../network/api_exception.dart';

/// Shared WhatsApp points balance — mirrors `useWhatsAppWallet.ts`.
/// Every "Send on WhatsApp" button reads the same [balance].
class WhatsAppWalletState {
  WhatsAppWalletState._();

  static final ValueNotifier<int?> balance = ValueNotifier<int?>(null);

  static Future<void> refresh(BuildContext context) async {
    try {
      balance.value = (await context.read<AppServices>().whatsapp.wallet()).balance;
    } catch (_) {
      // Informational only; the server still guards every send.
    }
  }

  /// Update the balance from a send response body (`data.balance`).
  static void noteBalance(Object? data) {
    if (data is Map && data['balance'] is num) balance.value = (data['balance'] as num).toInt();
  }

  static Future<void> showOutOfPoints(BuildContext context) async {
    final buy = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('No WhatsApp points left'),
        content: const Text(
            'Each WhatsApp message uses 1 point. Buy a points pack to keep sharing invoices and visit records.'),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Buy points')),
        ],
      ),
    );
    if (buy == true && context.mounted) context.push('/settings/subscription');
  }

  /// False (and shows the prompt) when the balance is known to be zero.
  static bool ensureCanSend(BuildContext context) {
    final b = balance.value;
    if (b != null && b <= 0) {
      showOutOfPoints(context);
      return false;
    }
    return true;
  }

  /// True when [error] was "out of points" (HTTP 402) and the prompt was shown.
  static bool handleSendError(BuildContext context, Object error) {
    if (error is ApiException && error.statusCode == 402) {
      balance.value = 0;
      showOutOfPoints(context);
      return true;
    }
    return false;
  }
}

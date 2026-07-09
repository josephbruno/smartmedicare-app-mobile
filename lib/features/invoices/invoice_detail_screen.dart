import 'package:flutter/material.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/services/thermal_printer_service.dart';
import '../../core/session/auth_session.dart';
import '../../data/models/invoice.dart';

class InvoiceDetailScreen extends StatefulWidget {
  const InvoiceDetailScreen({super.key, required this.id});

  final int id;

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  late Future<Invoice> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppServices>().billing.get(widget.id);
  }

  Future<void> _handleWhatsApp(Invoice inv) async {
    final services = context.read<AppServices>();
    final phoneController = TextEditingController(text: inv.customer?.phone ?? '');
    bool sending = false;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Send WhatsApp Invoice'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Enter target phone number:'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                sending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : TextButton(
                        onPressed: () async {
                          final phone = phoneController.text.trim();
                          if (phone.isEmpty) return;
                          setState(() => sending = true);
                          try {
                            final success = await services.billing.sendWhatsApp(inv.id, phone: phone);
                            if (success) {
                              if (context.mounted) {
                                AppMessenger.show(context,
                                  const SnackBar(content: Text('WhatsApp message sent successfully!')),
                                );
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                            } else {
                              if (context.mounted) {
                                AppMessenger.show(context,
                                  const SnackBar(content: Text('Failed to send WhatsApp message.')),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              AppMessenger.show(context,
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          } finally {
                            setState(() => sending = false);
                          }
                        },
                        child: const Text('Send'),
                      ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Invoice>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: Text('Not found'));
        }
        final inv = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(inv.invoiceNumber, style: Theme.of(context).textTheme.headlineSmall),
            Text('Status: ${inv.status}'),
            Text('Date: ${inv.invoiceDate}'),
            if (inv.customer != null) Text('Customer: ${inv.customer!.name}'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleWhatsApp(inv),
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                    label: const Text('Send WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: inv.items == null || inv.items!.isEmpty
                        ? null
                        : () async {
                            final auth = context.read<AuthSession>();
                            final ok = await ThermalPrinterService.printReceipt(
                              invoice: inv,
                              items: inv.items!,
                              shopName: auth.currentShop?.name ?? auth.currentBranch?.name,
                            );
                            if (context.mounted) {
                              AppMessenger.show(
                                context,
                                SnackBar(
                                  content: Text(ok ? 'Print dialog opened' : 'Print failed'),
                                  backgroundColor: ok ? Colors.green : Colors.red,
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Print'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final shareUrl = 'http://localhost:8001/share/invoice/${inv.shareToken ?? ''}';
                      await Clipboard.setData(ClipboardData(text: shareUrl));
                      if (context.mounted) {
                        AppMessenger.show(context,
                          const SnackBar(content: Text('Share link copied!')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Share Link'),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text('Total: ₹${inv.totalAmount.toStringAsFixed(2)}'),
            if (inv.items != null)
              ...inv.items!.map(
                (it) => ListTile(
                  title: Text(it.productName),
                  subtitle: Text('Qty ${it.quantity}'),
                  trailing: Text('₹${it.totalAmount.toStringAsFixed(2)}'),
                ),
              ),
          ],
        );
      },
    );
  }
}

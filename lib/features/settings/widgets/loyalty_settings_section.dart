import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';

import '../../../app_services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/shop.dart';

/// Shop loyalty program settings (synced to loyalty_programs on save).
class LoyaltySettingsSection extends StatefulWidget {
  const LoyaltySettingsSection({super.key, required this.initial});

  final ShopSettings initial;

  @override
  State<LoyaltySettingsSection> createState() => _LoyaltySettingsSectionState();
}

class _LoyaltySettingsSectionState extends State<LoyaltySettingsSection> {
  late bool _enabled;
  late final TextEditingController _earn;
  late final TextEditingController _redeem;
  late final TextEditingController _minRedeem;
  late final TextEditingController _maxPercent;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _enabled = s.enableLoyalty;
    _earn = TextEditingController(
        text: s.loyaltyEarnPerAmount.toStringAsFixed(
            s.loyaltyEarnPerAmount == s.loyaltyEarnPerAmount.roundToDouble()
                ? 0
                : 2));
    _redeem = TextEditingController(
        text: s.loyaltyRedeemPerPoint.toStringAsFixed(2));
    _minRedeem =
        TextEditingController(text: '${s.loyaltyRedemptionMinPoints}');
    _maxPercent = TextEditingController(
        text: s.loyaltyMaxRedeemPercent.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _earn.dispose();
    _redeem.dispose();
    _minRedeem.dispose();
    _maxPercent.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final earn = double.tryParse(_earn.text.trim()) ?? 0;
    final redeem = double.tryParse(_redeem.text.trim()) ?? 0;
    final minPts = int.tryParse(_minRedeem.text.trim()) ?? 0;
    final maxPct = double.tryParse(_maxPercent.text.trim()) ?? 0;

    if (_enabled && earn < 0.01) {
      AppMessenger.show(
        context,
        const SnackBar(content: Text('Enter rupees spent to earn 1 point')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final settings = widget.initial
          .copyWith(
            enableLoyalty: _enabled,
            loyaltyEarnPerAmount: earn > 0 ? earn : 100,
            loyaltyRedeemPerPoint: redeem,
            loyaltyRedemptionMinPoints: minPts,
            loyaltyMaxRedeemPercent: maxPct.clamp(0, 100),
          )
          .toJson();
      await context.read<AppServices>().shop.updateSettings(settings);
      if (!mounted) return;
      AppMessenger.show(
        context,
        SnackBar(
          content: Text(_enabled
              ? 'Loyalty points enabled and saved'
              : 'Loyalty points disabled'),
          backgroundColor: AppTheme.accent,
        ),
      );
    } catch (e) {
      if (mounted) {
        AppMessenger.show(
          context,
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ListTile(
              leading: Icon(Icons.stars_rounded, color: AppTheme.warning),
              title: Text('Loyalty Points',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Earn & redeem rules for customer invoices'),
            ),
            SwitchListTile(
              title: const Text('Enable loyalty points'),
              subtitle: Text(
                _enabled
                    ? 'Customers earn points on paid invoices'
                    : 'Turn on to start earning points',
              ),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            if (_enabled) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  'Example: spend ₹100 → 1 point',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _earn,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: '₹ spent to earn 1 point',
                    hintText: '100',
                    border: OutlineInputBorder(),
                    helperText: 'Bill ÷ this value = points earned',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _redeem,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: '₹ value of 1 point (redeem)',
                    hintText: '0.25',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _minRedeem,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Minimum points to redeem',
                    hintText: '100',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _maxPercent,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Max % of bill payable by points',
                    hintText: '10',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save loyalty settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

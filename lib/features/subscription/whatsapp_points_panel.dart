import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:maran/core/messaging/app_messenger.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_services.dart';
import '../../core/services/whatsapp_wallet.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/ist.dart';
import '../../core/widgets/web_page.dart';
import '../../data/services/whatsapp_service.dart';

/// WhatsApp points wallet — mirrors `frontend/src/components/WhatsAppPointsPanel.vue`:
/// balance, packs to buy (owner only), paginated recent activity.
class WhatsAppPointsPanel extends StatefulWidget {
  const WhatsAppPointsPanel({super.key});

  @override
  State<WhatsAppPointsPanel> createState() => _WhatsAppPointsPanelState();
}

class _WhatsAppPointsPanelState extends State<WhatsAppPointsPanel> {
  static const _pageSize = 10;
  static final _num = NumberFormat.decimalPattern('en_IN');

  WhatsAppWallet? _wallet;
  bool _loading = true;
  String? _buying;
  List<WhatsAppTransaction> _tx = const [];
  int _txPage = 1;
  int _txLast = 1;
  int _txTotal = 0;
  bool _txLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final w = await context.read<AppServices>().whatsapp.wallet();
      WhatsAppWalletState.balance.value = w.balance;
      if (mounted) setState(() => _wallet = w);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    await _loadTransactions(1);
  }

  Future<void> _loadTransactions(int page) async {
    setState(() => _txLoading = true);
    try {
      final r = await context.read<AppServices>().whatsapp.transactions(page: page, perPage: _pageSize);
      if (!mounted) return;
      setState(() {
        _tx = r.items;
        _txPage = r.meta?.currentPage ?? page;
        _txLast = r.meta?.lastPage ?? 1;
        _txTotal = r.meta?.total ?? r.items.length;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _txLoading = false);
    }
  }

  Future<void> _buy(String slug) async {
    setState(() => _buying = slug);
    try {
      final url = await context.read<AppServices>().whatsapp.checkoutLink(slug);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (mounted) AppMessenger.success(context, 'Complete the payment on the billing page, then come back and refresh.');
    } catch (e) {
      if (mounted) AppMessenger.error(context, 'The billing portal is unavailable right now. $e');
    } finally {
      if (mounted) setState(() => _buying = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = _wallet;
    final low = w != null && w.balance <= 20;
    return WebCard(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.chat, color: Color(0xFF16A34A)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('WhatsApp Points', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTokens.text1)),
              Text('1 point per message. Use them for invoice and visit-record sharing.',
                  style: TextStyle(fontSize: 13, color: AppTokens.text3)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(w == null ? '—' : _num.format(w.balance),
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: low ? AppTokens.error : AppTokens.success)),
            const Text('points left', style: TextStyle(fontSize: 12, color: AppTokens.text3)),
          ]),
        ]),
        if (_loading && w == null)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        if (w != null && w.balance <= 0)
          Container(
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: const Text('You are out of points. WhatsApp sharing is paused until you buy a pack.',
                style: TextStyle(color: AppTokens.error, fontWeight: FontWeight.w500)),
          ),
        if (w != null && w.packs.isNotEmpty) ...[
          const SizedBox(height: 16),
          FormGrid(
            columns: w.packs.length.clamp(1, 3),
            gap: 12,
            children: [
              for (final p in w.packs)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.slug == 'pro' ? AppTokens.primary : AppTokens.border, width: p.slug == 'pro' ? 2 : 1),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                      if (p.slug == 'pro') const StatusPill('Popular', tone: PillTone.blue),
                    ]),
                    const SizedBox(height: 6),
                    Text.rich(TextSpan(children: [
                      TextSpan(text: _num.format(p.points), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      const TextSpan(text: ' points', style: TextStyle(color: AppTokens.text3)),
                    ])),
                    Text.rich(TextSpan(children: [
                      TextSpan(text: '₹${_num.format(p.priceInr)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      const TextSpan(text: ' one-time', style: TextStyle(color: AppTokens.text3, fontSize: 12)),
                    ])),
                    Text('₹${(p.priceInr / (p.points == 0 ? 1 : p.points)).toStringAsFixed(2)} per message',
                        style: const TextStyle(fontSize: 12, color: AppTokens.text3)),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: !w.canManage || _buying != null ? null : () => _buy(p.slug),
                        child: _buying == p.slug
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text('Buy ${p.name}'),
                      ),
                    ),
                  ]),
                ),
            ],
          ),
          if (!w.canManage)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Only the organization owner can buy points.', style: TextStyle(fontSize: 12, color: AppTokens.text3)),
            ),
        ],
        if (_txTotal > 0) ...[
          const SizedBox(height: 18),
          Row(children: [
            const Expanded(child: Text('Recent activity', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
            if (_txLoading) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
          const SizedBox(height: 6),
          for (final t in _tx)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEDF1F6)))),
              child: Row(children: [
                Expanded(child: Text(t.description)),
                Text(formatDateTimeIst(t.createdAt), style: const TextStyle(fontSize: 12, color: AppTokens.text3)),
                const SizedBox(width: 16),
                SizedBox(
                  width: 52,
                  child: Text('${t.points > 0 ? '+' : ''}${t.points}',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontWeight: FontWeight.w700, color: t.points >= 0 ? AppTokens.success : AppTokens.error)),
                ),
              ]),
            ),
          if (_txLast > 1)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                IconButton(
                  onPressed: _txPage > 1 && !_txLoading ? () => _loadTransactions(_txPage - 1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('Page $_txPage of $_txLast'),
                IconButton(
                  onPressed: _txPage < _txLast && !_txLoading ? () => _loadTransactions(_txPage + 1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ]),
            ),
        ],
      ]),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/desktop/desktop_prefs.dart';
import '../../../core/theme/app_theme.dart';

/// POS / desktop toggles stored in SharedPreferences.
class PosDesktopSettingsSection extends StatefulWidget {
  const PosDesktopSettingsSection({super.key});

  @override
  State<PosDesktopSettingsSection> createState() => _PosDesktopSettingsSectionState();
}

class _PosDesktopSettingsSectionState extends State<PosDesktopSettingsSection> {
  bool _autoPrint = false;
  bool _sound = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auto = await DesktopPrefs.getAutoPrintReceipt();
    final sound = await DesktopPrefs.getNotificationSound();
    if (mounted) {
      setState(() {
        _autoPrint = auto;
        _sound = sound;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ListTile(
            leading: Icon(Icons.desktop_windows_outlined, color: AppTheme.primary),
            title: Text('Desktop & POS', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Receipt printing and notifications'),
          ),
          SwitchListTile(
            title: const Text('Auto-print receipt after checkout'),
            subtitle: const Text('Opens print dialog when payment succeeds (desktop)'),
            value: _autoPrint,
            onChanged: (v) async {
              await DesktopPrefs.setAutoPrintReceipt(v);
              setState(() => _autoPrint = v);
            },
          ),
          SwitchListTile(
            title: const Text('Sound for visit billing alerts'),
            value: _sound,
            onChanged: (v) async {
              await DesktopPrefs.setNotificationSound(v);
              setState(() => _sound = v);
            },
          ),
        ],
      ),
    );
  }
}

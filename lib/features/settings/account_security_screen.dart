import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/messaging/app_messenger.dart';
import '../../core/network/api_exception.dart';
import '../../core/security/biometric_service.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';

/// Accent for the PIN column in the security mockup.
const Color _pinAccent = Color(0xFF7C3AED);
const Color _pinAccentSoft = Color(0xFFF3E8FF);
const Color _passwordSoft = Color(0xFFDBEAFE);
const Color _bannerBg = Color(0xFFEFF6FF);
const Color _footerBg = Color(0xFFF1F5F9);
const Color _fieldBorder = Color(0xFFCBD5E1);

/// Self-service "Change Password" / "Change PIN" for the signed-in account.
/// Open to every authenticated user regardless of role/permissions.
class AccountSecurityScreen extends StatelessWidget {
  const AccountSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hasPin = context.watch<AuthSession>().hasPinSet;

    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= 860;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
                _SecurityBanner(hasPin: hasPin),
                const SizedBox(height: 20),
                if (sideBySide)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _SectionCard(
                            accent: AppTheme.primary,
                            softAccent: _passwordSoft,
                            icon: Icons.lock_outline_rounded,
                            title: 'Change Password',
                            subtitle:
                                'Update the password used to sign in to your account',
                            child: const _ChangePasswordForm(),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _SectionCard(
                            accent: _pinAccent,
                            softAccent: _pinAccentSoft,
                            icon: Icons.dialpad_rounded,
                            title: 'Change PIN',
                            subtitle:
                                '6-digit PIN used to quickly unlock the app',
                            trailing: _ActiveChip(active: hasPin),
                            child: const _ChangePinForm(),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  _SectionCard(
                    accent: AppTheme.primary,
                    softAccent: _passwordSoft,
                    icon: Icons.lock_outline_rounded,
                    title: 'Change Password',
                    subtitle:
                        'Update the password used to sign in to your account',
                    child: const _ChangePasswordForm(),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    accent: _pinAccent,
                    softAccent: _pinAccentSoft,
                    icon: Icons.dialpad_rounded,
                    title: 'Change PIN',
                    subtitle: '6-digit PIN used to quickly unlock the app',
                    trailing: _ActiveChip(active: hasPin),
                    child: const _ChangePinForm(),
                  ),
                ],
                if (AppConfig.isNativeMobile) ...[
                  const SizedBox(height: 16),
                  const _BiometricUnlockCard(),
                ],
                const SizedBox(height: 20),
                const _SecurityFooter(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BiometricUnlockCard extends StatefulWidget {
  const _BiometricUnlockCard();

  @override
  State<_BiometricUnlockCard> createState() => _BiometricUnlockCardState();
}

class _BiometricUnlockCardState extends State<_BiometricUnlockCard> {
  final _biometrics = BiometricService();
  final _pinController = TextEditingController();

  bool _loading = true;
  bool _available = false;
  bool _toggling = false;
  String _label = 'Fingerprint unlock';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final available = await _biometrics.canCheckBiometrics();
    final label = available ? await _biometrics.unlockLabel() : _label;
    if (!mounted) return;
    setState(() {
      _available = available;
      _label = label.replaceFirst('Use ', '');
      _label = '${_label[0].toUpperCase()}${_label.substring(1)} unlock';
      _loading = false;
    });
  }

  Future<void> _onToggle(bool enable) async {
    final auth = context.read<AuthSession>();
    if (!enable) {
      setState(() => _toggling = true);
      try {
        await auth.disableBiometricUnlock();
        if (mounted) {
          AppMessenger.success(context, 'Fingerprint unlock turned off');
        }
      } finally {
        if (mounted) setState(() => _toggling = false);
      }
      return;
    }

    _pinController.clear();
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Enable $_label'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your current 6-digit PIN once so fingerprint can unlock the app.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Current PIN',
                counterText: '',
              ),
              onSubmitted: (v) {
                if (v.length == 6) Navigator.pop(ctx, v);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = _pinController.text;
              if (v.length == 6) Navigator.pop(ctx, v);
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (pin == null || !mounted) return;

    setState(() => _toggling = true);
    try {
      final ok = await _biometrics.authenticate(
        reason: 'Confirm biometrics for Maran Billing',
      );
      if (!ok) {
        if (mounted) {
          AppMessenger.error(context, 'Biometric confirmation cancelled');
        }
        return;
      }
      await auth.enableBiometricUnlock(pin);
      if (mounted) {
        AppMessenger.success(context, '$_label enabled');
      }
    } on ApiException catch (e) {
      if (mounted) AppMessenger.error(context, e.displayMessage);
    } catch (e) {
      if (mounted) AppMessenger.error(context, '$e');
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !_available) return const SizedBox.shrink();

    final enabled = context.watch<AuthSession>().biometricEnabled;
    final hasPin = context.watch<AuthSession>().hasPinSet;

    return _SectionCard(
      accent: AppTheme.accent,
      softAccent: const Color(0xFFD1FAE5),
      icon: Icons.fingerprint,
      title: _label,
      subtitle: hasPin
          ? 'Unlock with biometrics instead of typing your PIN'
          : 'Set a PIN first, then enable fingerprint unlock',
      trailing: _ActiveChip(active: enabled),
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(
          enabled ? 'Enabled on this device' : 'Off on this device',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: const Text(
          'PIN remains available as a backup.',
          style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
        ),
        value: enabled,
        onChanged: (!hasPin || _toggling) ? null : _onToggle,
      ),
    );
  }
}

class _SecurityBanner extends StatelessWidget {
  const _SecurityBanner({required this.hasPin});

  final bool hasPin;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _bannerBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.12)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _DotGridPainter()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: AppTheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Account Security',
                        style: TextStyle(
                          color: Color(0xFF1E3A8A),
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasPin
                            ? 'Password and quick-unlock PIN are configured.'
                            : 'Password is active. Set a PIN for faster unlock.',
                        style: TextStyle(
                          color: AppTheme.primary.withValues(alpha: 0.85),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (MediaQuery.sizeOf(context).width >= 640) ...[
                  const SizedBox(width: 12),
                  const _BannerDecoration(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    const step = 14.0;
    for (var x = size.width * 0.45; x < size.width; x += step) {
      for (var y = 8.0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BannerDecoration extends StatelessWidget {
  const _BannerDecoration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 0,
            top: 4,
            child: Container(
              width: 48,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 18,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      4,
                      (i) => Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 0,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.lock_rounded, color: Colors.white, size: 26),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  const _ActiveChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.accent : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.check_rounded : Icons.info_outline_rounded,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            active ? 'Active' : 'Not set',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.accent,
    required this.softAccent,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final Color accent;
  final Color softAccent;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: softAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (trailing != null) trailing!,
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _SecurityFooter extends StatelessWidget {
  const _SecurityFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _footerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, size: 18, color: AppTheme.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Keep your password and PIN private. Never share them with anyone.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _firstErrorMessage(ApiException e) => e.displayMessage;

enum _PasswordStrength { empty, weak, fair, good, strong }

_PasswordStrength _passwordStrength(String value) {
  if (value.isEmpty) return _PasswordStrength.empty;
  var score = 0;
  if (value.length >= 8) score++;
  if (value.length >= 12) score++;
  if (RegExp(r'[A-Z]').hasMatch(value) && RegExp(r'[a-z]').hasMatch(value)) {
    score++;
  }
  if (RegExp(r'\d').hasMatch(value)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;

  if (score <= 1) return _PasswordStrength.weak;
  if (score == 2) return _PasswordStrength.fair;
  if (score == 3) return _PasswordStrength.good;
  return _PasswordStrength.strong;
}

class _PasswordStrengthMeter extends StatelessWidget {
  const _PasswordStrengthMeter({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final strength = _passwordStrength(password);
    final filled = switch (strength) {
      _PasswordStrength.empty => 0,
      _PasswordStrength.weak => 1,
      _PasswordStrength.fair => 2,
      _PasswordStrength.good => 3,
      _PasswordStrength.strong => 4,
    };
    final color = switch (strength) {
      _PasswordStrength.empty => const Color(0xFFE2E8F0),
      _PasswordStrength.weak => AppTheme.danger,
      _PasswordStrength.fair => AppTheme.warning,
      _PasswordStrength.good => AppTheme.primary,
      _PasswordStrength.strong => AppTheme.accent,
    };

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(4, (i) {
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: i < filled ? color : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            strength == _PasswordStrength.empty
                ? 'Password strength'
                : 'Password strength · ${strength.name[0].toUpperCase()}${strength.name.substring(1)}',
            style: TextStyle(
              color: strength == _PasswordStrength.empty
                  ? AppTheme.textSecondary
                  : color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchHint extends StatelessWidget {
  const _MatchHint({
    required this.value,
    required this.confirm,
    required this.emptyLabel,
  });

  final String value;
  final String confirm;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (confirm.isEmpty) return const SizedBox.shrink();

    final matches = value.isNotEmpty && value == confirm;
    final color = matches ? AppTheme.accent : AppTheme.danger;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            matches ? Icons.check_circle_outline : Icons.error_outline,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            matches ? 'Matches' : emptyLabel,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PinProgressDots extends StatelessWidget {
  const _PinProgressDots({required this.length});

  final int length;
  static const _total = 6;
  static const _color = _pinAccent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 2),
      child: Row(
        children: List.generate(_total, (i) {
          final filled = i < length;
          return Container(
            width: 9,
            height: 9,
            margin: EdgeInsets.only(right: i == _total - 1 ? 0 : 5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? _color : Colors.transparent,
              border: Border.all(
                color: filled ? _color : const Color(0xFFCBD5E1),
                width: 1.5,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _FullWidthButton extends StatelessWidget {
  const _FullWidthButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: FilledButton.icon(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.55),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

InputDecoration _fieldDecoration({
  required String label,
  String? hint,
  String? counterText,
  Widget? suffixIcon,
  Color focusColor = AppTheme.primary,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    counterText: counterText,
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
    suffixIcon: suffixIcon,
    suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 36),
    labelStyle: const TextStyle(
      color: AppTheme.textSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
    floatingLabelStyle: TextStyle(
      color: focusColor,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
    hintStyle: TextStyle(
      color: AppTheme.textSecondary.withValues(alpha: 0.7),
      fontSize: 13.5,
      fontWeight: FontWeight.w400,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _fieldBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _fieldBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: focusColor, width: 1.8),
    ),
  );
}

Widget _visibilityButton({
  required bool visible,
  required VoidCallback onToggle,
  Color color = AppTheme.textSecondary,
}) {
  return IconButton(
    tooltip: visible ? 'Hide' : 'Show',
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    icon: Icon(
      visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      size: 20,
      color: color,
    ),
    onPressed: onToggle,
  );
}

class _ChangePasswordForm extends StatefulWidget {
  const _ChangePasswordForm();

  @override
  State<_ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<_ChangePasswordForm> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _showCurrent = false;
  bool _showNext = false;
  bool _showConfirm = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _next.addListener(_onChanged);
    _confirm.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _next.removeListener(_onChanged);
    _confirm.removeListener(_onChanged);
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _current.text;
    final next = _next.text;
    final confirm = _confirm.text;

    if (current.isEmpty) {
      AppMessenger.error(context, 'Enter your current password');
      return;
    }
    if (next.length < 8) {
      AppMessenger.error(context, 'New password must be at least 8 characters');
      return;
    }
    if (next != confirm) {
      AppMessenger.error(context, 'New password and confirmation do not match');
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<AuthSession>().changePassword(
            currentPassword: current,
            newPassword: next,
          );
      if (!mounted) return;
      _current.clear();
      _next.clear();
      _confirm.clear();
      AppMessenger.success(context, 'Password changed successfully');
    } on ApiException catch (e) {
      if (mounted) AppMessenger.error(context, _firstErrorMessage(e));
    } catch (e) {
      if (mounted) AppMessenger.error(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    required bool visible,
    required VoidCallback onToggle,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: !visible,
      textInputAction: textInputAction,
      style: const TextStyle(fontSize: 14, height: 1.25),
      decoration: _fieldDecoration(
        label: label,
        hint: hint,
        suffixIcon: _visibilityButton(visible: visible, onToggle: onToggle),
      ),
      onSubmitted: onSubmitted,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(
          controller: _current,
          label: 'Current Password',
          hint: 'Enter current password',
          visible: _showCurrent,
          onToggle: () => setState(() => _showCurrent = !_showCurrent),
        ),
        const SizedBox(height: 14),
        _field(
          controller: _next,
          label: 'New Password',
          hint: 'At least 8 characters',
          visible: _showNext,
          onToggle: () => setState(() => _showNext = !_showNext),
        ),
        _PasswordStrengthMeter(password: _next.text),
        const SizedBox(height: 14),
        _field(
          controller: _confirm,
          label: 'Confirm New Password',
          hint: 'Confirm new password',
          visible: _showConfirm,
          onToggle: () => setState(() => _showConfirm = !_showConfirm),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        _MatchHint(
          value: _next.text,
          confirm: _confirm.text,
          emptyLabel: 'Passwords do not match',
        ),
        const SizedBox(height: 18),
        _FullWidthButton(
          label: 'Update Password',
          icon: Icons.lock_rounded,
          color: AppTheme.primary,
          loading: _saving,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _ChangePinForm extends StatefulWidget {
  const _ChangePinForm();

  @override
  State<_ChangePinForm> createState() => _ChangePinFormState();
}

class _ChangePinFormState extends State<_ChangePinForm> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _showCurrent = false;
  bool _showNext = false;
  bool _showConfirm = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _current.addListener(_onChanged);
    _next.addListener(_onChanged);
    _confirm.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _current.removeListener(_onChanged);
    _next.removeListener(_onChanged);
    _confirm.removeListener(_onChanged);
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit(bool hasPin) async {
    final current = _current.text;
    final next = _next.text;
    final confirm = _confirm.text;

    if (hasPin && current.length != 6) {
      AppMessenger.error(context, 'Enter your current 6-digit PIN');
      return;
    }
    if (next.length != 6) {
      AppMessenger.error(context, 'New PIN must be exactly 6 digits');
      return;
    }
    if (next != confirm) {
      AppMessenger.error(context, 'New PIN and confirmation do not match');
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<AuthSession>().changePin(
            currentPin: hasPin ? current : null,
            newPin: next,
          );
      if (!mounted) return;
      _current.clear();
      _next.clear();
      _confirm.clear();
      AppMessenger.success(
        context,
        hasPin ? 'PIN changed successfully' : 'PIN set successfully',
      );
    } on ApiException catch (e) {
      if (mounted) AppMessenger.error(context, _firstErrorMessage(e));
    } catch (e) {
      if (mounted) AppMessenger.error(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _pinField({
    required TextEditingController controller,
    required String label,
    required bool visible,
    required VoidCallback onToggle,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          obscureText: !visible,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textInputAction: textInputAction,
          style: const TextStyle(
            fontSize: 18,
            height: 1.2,
            letterSpacing: 4,
            fontWeight: FontWeight.w600,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _fieldDecoration(
            label: label,
            hint: '••••••',
            counterText: '',
            focusColor: _pinAccent,
            suffixIcon: _visibilityButton(
              visible: visible,
              onToggle: onToggle,
              color: _pinAccent.withValues(alpha: 0.7),
            ),
          ),
          onSubmitted: onSubmitted,
        ),
        _PinProgressDots(length: controller.text.length),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPin = context.watch<AuthSession>().hasPinSet;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasPin)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppTheme.warning.withValues(alpha: 0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.warning, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You haven\'t set a PIN yet. Set one below for quick unlock.',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (hasPin) ...[
          _pinField(
            controller: _current,
            label: 'Current PIN',
            visible: _showCurrent,
            onToggle: () => setState(() => _showCurrent = !_showCurrent),
          ),
          const SizedBox(height: 14),
        ],
        _pinField(
          controller: _next,
          label: 'New PIN',
          visible: _showNext,
          onToggle: () => setState(() => _showNext = !_showNext),
        ),
        const SizedBox(height: 14),
        _pinField(
          controller: _confirm,
          label: 'Confirm New PIN',
          visible: _showConfirm,
          onToggle: () => setState(() => _showConfirm = !_showConfirm),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(hasPin),
        ),
        _MatchHint(
          value: _next.text,
          confirm: _confirm.text,
          emptyLabel: 'PINs do not match',
        ),
        const SizedBox(height: 18),
        _FullWidthButton(
          label: hasPin ? 'Update PIN' : 'Set PIN',
          icon: Icons.dialpad_rounded,
          color: _pinAccent,
          loading: _saving,
          onPressed: () => _submit(hasPin),
        ),
      ],
    );
  }
}

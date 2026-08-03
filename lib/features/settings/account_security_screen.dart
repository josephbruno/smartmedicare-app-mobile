import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/messaging/app_messenger.dart';
import '../../core/network/api_exception.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';

/// Self-service "Change Password" / "Change PIN" for the signed-in account.
/// Open to every authenticated user regardless of role/permissions.
class AccountSecurityScreen extends StatelessWidget {
  const AccountSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _SectionCard(
          icon: Icons.lock_outline_rounded,
          title: 'Change Password',
          subtitle: 'Update the password used to sign in to your account',
          child: _ChangePasswordForm(),
        ),
        SizedBox(height: 16),
        _SectionCard(
          icon: Icons.pin_outlined,
          title: 'Change PIN',
          subtitle: '6-digit PIN used to quickly unlock the app',
          child: _ChangePinForm(),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(icon, color: AppTheme.primary),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(subtitle),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Extracts the first field-level validation message, falling back to the
/// top-level exception message.
String _firstErrorMessage(ApiException e) {
  final errors = e.errors;
  if (errors != null && errors.isNotEmpty) {
    final firstList = errors.values.first;
    if (firstList.isNotEmpty) return firstList.first;
  }
  return e.message;
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
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _current,
          obscureText: !_showCurrent,
          decoration: InputDecoration(
            labelText: 'Current Password',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_showCurrent
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: () => setState(() => _showCurrent = !_showCurrent),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _next,
          obscureText: !_showNext,
          decoration: InputDecoration(
            labelText: 'New Password',
            hintText: 'At least 8 characters',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_showNext
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: () => setState(() => _showNext = !_showNext),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirm,
          obscureText: !_showConfirm,
          decoration: InputDecoration(
            labelText: 'Confirm New Password',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_showConfirm
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: () => setState(() => _showConfirm = !_showConfirm),
            ),
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Update Password'),
          ),
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
  bool _saving = false;

  @override
  void dispose() {
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

  InputDecoration _pinDecoration(String label) => InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        counterText: '',
      );

  @override
  Widget build(BuildContext context) {
    final hasPin = context.watch<AuthSession>().hasPinSet;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasPin)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'You haven\'t set a PIN yet. Set one below for quick unlock.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
        if (hasPin) ...[
          TextField(
            controller: _current,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _pinDecoration('Current PIN'),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _next,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _pinDecoration('New PIN'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirm,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _pinDecoration('Confirm New PIN'),
          onSubmitted: (_) => _submit(hasPin),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _saving ? null : () => _submit(hasPin),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(hasPin ? 'Update PIN' : 'Set PIN'),
          ),
        ),
      ],
    );
  }
}

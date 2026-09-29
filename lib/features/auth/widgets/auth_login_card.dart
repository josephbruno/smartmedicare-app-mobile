import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../login_view_model.dart';

const _kRememberLoginKey = 'auth_remember_login';
const _kRememberMeKey = 'auth_remember_me';

/// Login panel matching the SmartMediCare sign-in screenshot.
class AuthLoginCard extends StatefulWidget {
  const AuthLoginCard({super.key});

  @override
  State<AuthLoginCard> createState() => _AuthLoginCardState();
}

class _AuthLoginCardState extends State<AuthLoginCard> {
  final _employeeId = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedLogin();
  }

  Future<void> _loadRememberedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _rememberMe = prefs.getBool(_kRememberMeKey) ?? false;
      final saved = prefs.getString(_kRememberLoginKey);
      if (_rememberMe && saved != null && saved.isNotEmpty) {
        _employeeId.text = saved;
        context.read<LoginViewModel>().login = saved;
      }
      _prefsLoaded = true;
    });
  }

  Future<void> _persistRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRememberMeKey, _rememberMe);
    if (_rememberMe) {
      await prefs.setString(_kRememberLoginKey, _employeeId.text.trim());
    } else {
      await prefs.remove(_kRememberLoginKey);
    }
  }

  @override
  void dispose() {
    _employeeId.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit(LoginViewModel vm) async {
    await vm.submit();
    if (!mounted || vm.error != null) return;
    await _persistRememberMe();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildForm(context, vm),
        if (!_prefsLoaded)
          Positioned.fill(
            child: Container(
              color: Colors.white,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildForm(BuildContext context, LoginViewModel vm) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Adaptive padding: tighter when window is short
          final isShort = constraints.maxHeight < 620;
          final vPad = isShort ? 18.0 : 30.0;
          final hPad = isShort ? 36.0 : 48.0;
          final gap = isShort ? 14.0 : 20.0;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, vPad),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.hasBoundedHeight
                    ? constraints.maxHeight - (vPad * 2)
                    : 0,
              ),
              child: Center(
                child: SizedBox(
                  width: double.infinity,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Header: logo + trusted badge ─────────────────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: const [
                            AppLogo(size: 60, borderRadius: 0),
                            Spacer(),
                            Icon(Icons.favorite_rounded,
                                size: 18, color: Color(0xFFE60018)),
                            SizedBox(width: 6),
                            Text('Trusted Healthcare\nManagement Solution',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35)),
                          ],
                        ),
                        SizedBox(height: gap),

                        // ── Welcome Back (left-aligned) ──────────────────────────────
                        Text(
                          'Welcome Back',
                          textAlign: TextAlign.left,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 26,
                                    color: const Color(0xFF0F172A),
                                  ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Sign in to continue to SmartMediCare',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                        SizedBox(height: gap),

                        // ── Email field ───────────────────────────────────────────────
                        const _FieldLabel('Email *'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _employeeId,
                          decoration: const InputDecoration(
                            constraints: BoxConstraints(minHeight: 58),
                            hintText: 'your@email.com',
                            prefixIcon: Icon(
                              Icons.mail_outline_rounded,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email
                          ],
                          onChanged: (v) => vm.login = v,
                        ),
                        const SizedBox(height: 14),

                        // ── Password field ────────────────────────────────────────────
                        const _FieldLabel('Password *'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _password,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            constraints: const BoxConstraints(minHeight: 58),
                            hintText: 'Enter your password',
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              color: AppTheme.textSecondary,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppTheme.textSecondary,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onChanged: (v) => vm.password = v,
                          onSubmitted: (_) {
                            if (!vm.loading) _submit(vm);
                          },
                        ),
                        const SizedBox(height: 12),

                        // ── Remember me + Forgot password ────────────────────────────
                        Row(
                          children: [
                            SizedBox(
                              height: 22,
                              width: 22,
                              child: Checkbox(
                                value: _rememberMe,
                                activeColor: AppTheme.primary,
                                side:
                                    const BorderSide(color: Color(0xFFCBD5E1)),
                                onChanged: (v) =>
                                    setState(() => _rememberMe = v ?? false),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _rememberMe = !_rememberMe),
                              child: const Text(
                                'Remember me',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => context.go('/forgot-password'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                foregroundColor: AppTheme.primary,
                              ),
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),

                        // ── Error banner ──────────────────────────────────────────────
                        if (vm.error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.danger.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.danger.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: AppTheme.danger,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    vm.error!,
                                    style: const TextStyle(
                                      color: AppTheme.danger,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        SizedBox(height: gap),

                        // ── Sign In button ────────────────────────────────────────────
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: vm.loading ? null : () => _submit(vm),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1463D8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: vm.loading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.login_rounded, size: 20),
                                      SizedBox(width: 8),
                                      Text('Sign In',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                          ),
                        ),
                        SizedBox(height: gap),

                        // ── Powered by ────────────────────────────────────────────────
                        const _PoweredBy(),
                      ],
                    ), // Column
                  ), // AutofillGroup
                ), // SizedBox
              ), // Center
            ), // ConstrainedBox
          ); // SingleChildScrollView
        }, // LayoutBuilder builder
      ), // LayoutBuilder
    ); // Container
  }
}

// ---------------------------------------------------------------------------
// Field label
// ---------------------------------------------------------------------------
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF334155),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Powered by footer with styled link
// ---------------------------------------------------------------------------
class _PoweredBy extends StatelessWidget {
  const _PoweredBy();

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Powered by ',
              style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse('https://bestwaveinnovation.com');
              if (await canLaunchUrl(uri)) launchUrl(uri);
            },
            child: const Text(
              'bestwaveinnovation.com',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF1463D8),
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: Color(0xFF1463D8),
              ),
            ),
          ),
        ],
      );
}

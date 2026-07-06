import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/session/auth_session.dart';
import 'login_view_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_logo.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) => LoginViewModel(c.read<AuthSession>()),
      child: const _LoginBody(),
    );
  }
}

class _LoginBody extends StatefulWidget {
  const _LoginBody();

  @override
  State<_LoginBody> createState() => _LoginBodyState();
}

class _LoginBodyState extends State<_LoginBody> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();
    final auth = context.watch<AuthSession>();

    if (auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/dashboard');
      });
    } else if (auth.hasStoredSession && !auth.isUnlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.go(auth.hasPinSet ? '/pin' : '/set-pin');
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AppConfig.usesLargeUiScale
                  ? AppConfig.desktopFormCardMaxWidth
                  : 420,
            ),
            child: Card(
              elevation: 4,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: AutofillGroup(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Branding Header Logo
                      const Center(child: AppLogo(size: 72)),
                      const SizedBox(height: 24),
                      Text(
                        'Maran Billing',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pet shop billing & EMR',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 36),
                      // Email Field
                      TextField(
                        controller: _email,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          hintText: 'name@example.com',
                          prefixIcon: Icon(Icons.mail_outline_rounded, color: AppTheme.textSecondary),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        onChanged: (v) => vm.email = v,
                      ),
                      const SizedBox(height: 16),
                      // Password Field
                      TextField(
                        controller: _password,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.textSecondary),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: AppTheme.textSecondary,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        autofillHints: const [AutofillHints.password],
                        onChanged: (v) => vm.password = v,
                      ),
                      const SizedBox(height: 12),
                      // Forgot Password Link
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.go('/forgot-password'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      // Error Banner
                      if (vm.error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.danger.withOpacity(0.3), width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 20),
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
                      const SizedBox(height: 28),
                      // Submit Button
                      ElevatedButton(
                        onPressed: vm.loading ? null : () => vm.submit(),
                        child: vm.loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Sign In'),
                      ),
                      const SizedBox(height: 24),
                      // Sign up row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account?",
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                          ),
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: () => context.go('/register'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Register'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/session/auth_session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_logo.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _shop = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _loading = false;
  String? _error;
  String _clinicType = 'veterinary';
  String _facilityType = 'clinic';

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthSession>().register({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'shop_name': _shop.text.trim(),
        'clinic_type': _clinicType,
        'facility_type': _facilityType,
        'password': _password.text,
        'password_confirmation': _password2.text,
      });
      if (mounted) context.go('/dashboard');
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _shop.dispose();
    _password.dispose();
    _password2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AppConfig.usesLargeUiScale
                  ? AppConfig.desktopFormCardMaxWidth
                  : 480,
            ),
            child: Card(
              elevation: 4,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AppLogo(size: 64)),
                    const SizedBox(height: 20),
                    Text(
                      'Get Started',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create your 15-day free trial organization',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 28),
                    // Name
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Your Name',
                        hintText: 'John Doe',
                        prefixIcon: Icon(Icons.person_outline_rounded,
                            color: AppTheme.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Email
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        hintText: 'john@example.com',
                        prefixIcon: Icon(Icons.mail_outline_rounded,
                            color: AppTheme.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Phone
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'e.g. +91 98765 43210',
                        prefixIcon: Icon(Icons.phone_outlined,
                            color: AppTheme.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Organization Name
                    TextField(
                      controller: _shop,
                      decoration: const InputDecoration(
                        labelText: 'Organization / Clinic / Hospital',
                        hintText: 'City Care Clinic',
                        prefixIcon: Icon(Icons.local_hospital_outlined,
                            color: AppTheme.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _clinicType,
                      decoration: const InputDecoration(
                        labelText: 'Healthcare Type',
                        prefixIcon: Icon(Icons.health_and_safety_outlined,
                            color: AppTheme.textSecondary),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'human', child: Text('Human Healthcare')),
                        DropdownMenuItem(
                            value: 'veterinary',
                            child: Text('Veterinary Healthcare')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _clinicType = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _facilityType,
                      decoration: const InputDecoration(
                        labelText: 'Facility Type',
                        prefixIcon: Icon(Icons.apartment_outlined,
                            color: AppTheme.textSecondary),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'clinic', child: Text('Clinic')),
                        DropdownMenuItem(
                            value: 'hospital', child: Text('Hospital')),
                        DropdownMenuItem(
                            value: 'clinic_hospital',
                            child: Text('Clinic & Hospital')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _facilityType = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    // Password
                    TextField(
                      controller: _password,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: '••••••••',
                        prefixIcon: const Icon(Icons.lock_outline_rounded,
                            color: AppTheme.textSecondary),
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
                    ),
                    const SizedBox(height: 16),
                    // Confirm Password
                    TextField(
                      controller: _password2,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        hintText: '••••••••',
                        prefixIcon: const Icon(Icons.lock_outline_rounded,
                            color: AppTheme.textSecondary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppTheme.textSecondary,
                          ),
                          onPressed: () => setState(() =>
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword),
                        ),
                      ),
                    ),
                    // Error Banner
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppTheme.danger.withOpacity(0.3),
                              width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: AppTheme.danger, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error!,
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
                    // Register Button
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Create Account'),
                    ),
                    const SizedBox(height: 24),
                    // Sign in Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Already have an account?",
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Sign In'),
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
    );
  }
}

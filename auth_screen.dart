import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/auth_repository.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLogin = true;
  bool _usePhone = false;
  bool _loading = false;
  String _role = 'customer';
  String? _error;
  String? _info;

  AuthRepository get _auth => AuthRepository(Supabase.instance.client);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    try {
      if (_usePhone) {
        final phone = _phoneController.text.trim();
        if (phone.isEmpty) throw Exception('Enter your phone number.');
        await _auth.sendPhoneOtp(phone);
        if (!mounted) return;
        setState(() => _info = 'Verification code sent to $phone.');
      } else if (_isLogin) {
        await _auth.signInWithPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        if (_nameController.text.trim().isEmpty) {
          throw Exception('Enter your name.');
        }
        await _auth.signUpWithPassword(
          email: _emailController.text,
          password: _passwordController.text,
          displayName: _nameController.text,
          phone: _phoneController.text,
          role: _role,
        );
        if (!mounted) return;
        setState(() => _info =
            'Account created. Check your email if email confirmation is enabled in Supabase.');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.verifyPhoneOtp(
        phone: _phoneController.text,
        token: _otpController.text,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isLogin ? 'Welcome back' : 'Create your RingLink account';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 36),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.notifications_active_outlined,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'RingLink',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 22),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Email')),
                      ButtonSegment(value: false, label: Text('Phone OTP')),
                    ],
                    selected: {_usePhone ? false : true},
                    onSelectionChanged: (value) =>
                        setState(() => _usePhone = value.first == false),
                  ),
                  const SizedBox(height: 18),
                  if (_error != null)
                    _MessageCard(text: _error!, error: true),
                  if (_info != null)
                    _MessageCard(text: _info!, error: false),
                  if (_usePhone) ...[
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        hintText: '+256 7XX XXX XXX',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_info != null)
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Verification code',
                          prefixIcon: Icon(Icons.password_outlined),
                        ),
                      ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loading
                          ? null
                          : (_info == null ? _submit : _verifyOtp),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_info == null ? 'Send code' : 'Verify code'),
                    ),
                  ] else ...[
                    if (!_isLogin) ...[
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _role,
                        decoration: const InputDecoration(
                          labelText: 'Account type',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'customer',
                            child: Text('Customer'),
                          ),
                          DropdownMenuItem(
                            value: 'provider',
                            child: Text('Service Provider'),
                          ),
                          DropdownMenuItem(
                            value: 'business',
                            child: Text('Business / Group'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _role = value ?? 'customer'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone number (optional)',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isLogin ? 'Log in' : 'Create account'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                              _isLogin = !_isLogin;
                              _error = null;
                              _info = null;
                            }),
                    child: Text(
                      _isLogin
                          ? 'Create a new account'
                          : 'Already have an account? Log in',
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'RingLink starts as a verified local directory. Later, the RING flow connects customers with nearby available providers.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.text, required this.error});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text),
    );
  }
}

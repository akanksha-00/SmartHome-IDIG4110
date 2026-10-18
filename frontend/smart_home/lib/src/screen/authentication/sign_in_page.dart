import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_home/src/blocs/authentication/auth_cubit.dart';
import 'package:smart_home/src/screen/authentication/widgets/auth_brand_panel.dart';
import 'package:smart_home/src/theme/app_theme.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final auth = context.read<AuthCubit>();
    if (auth.state.isBusy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    auth.signIn(
        email: _email.text, password: _password.text, rememberMe: _rememberMe);
  }

  void _showInfo(String title, String text) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(text)),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it')),
          ],
        ),
      );

  InputDecoration _input(String hint, {Widget? suffix}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: authMuted, fontSize: 16),
        filled: true,
        fillColor: const Color(0xFF171B1E),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        suffixIcon: suffix,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF343A40))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF343A40))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: authAmber, width: 1.5)),
      );

  Widget _formContent(bool wide) => BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) => AutofillGroup(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.home_outlined, size: 76, color: authAmber),
                const SizedBox(height: 18),
                Text('Welcome back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: wide ? 42 : 34,
                        height: 1.15,
                        letterSpacing: -1,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                const Text('Sign in to your smart home.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: authMuted)),
                const SizedBox(height: 42),
                const Text('Email address', style: TextStyle(fontSize: 15)),
                const SizedBox(height: 10),
                TextFormField(
                  key: const ValueKey('auth-email'),
                  controller: _email,
                  enabled: !state.isBusy,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email
                  ],
                  autocorrect: false,
                  decoration: _input('Enter your email'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter your email address';
                    }
                    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                        .hasMatch(value.trim())) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                  onChanged: (_) => context.read<AuthCubit>().clearError(),
                ),
                const SizedBox(height: 24),
                const Text('Password', style: TextStyle(fontSize: 15)),
                const SizedBox(height: 10),
                TextFormField(
                  key: const ValueKey('auth-password'),
                  controller: _password,
                  enabled: !state.isBusy,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: _input('Enter your password',
                      suffix: IconButton(
                        key: const ValueKey('auth-password-visibility'),
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        color: authMuted,
                      )),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Enter a password'
                      : null,
                  onChanged: (_) => context.read<AuthCubit>().clearError(),
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    InkWell(
                      onTap: state.isBusy
                          ? null
                          : () => setState(() => _rememberMe = !_rememberMe),
                      borderRadius: BorderRadius.circular(6),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Checkbox(
                          key: const ValueKey('auth-remember-me'),
                          value: _rememberMe,
                          activeColor: authAmber,
                          checkColor: Colors.black,
                          visualDensity: VisualDensity.compact,
                          onChanged: state.isBusy
                              ? null
                              : (value) => setState(() => _rememberMe = value!),
                        ),
                        const Text('Remember me'),
                        const SizedBox(width: 8),
                      ]),
                    ),
                    TextButton(
                      onPressed: () => _showInfo('Reset your password',
                          'Password reset is not available yet.'),
                      style: TextButton.styleFrom(foregroundColor: authAmber),
                      child: const Text('Forgot password?'),
                    ),
                  ],
                ),
                if (state.error != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      key: const ValueKey('auth-error'),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: const Color(0xFF341D1E),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(state.error!,
                          style: const TextStyle(color: Color(0xFFFFB4AB))),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 60,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFFFC12F), Color(0xFFFFAA1C)]),
                        borderRadius: BorderRadius.circular(10)),
                    child: FilledButton(
                      key: const ValueKey('auth-submit'),
                      onPressed: state.isBusy ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: Colors.transparent,
                        disabledForegroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(state.isBusy ? 'Signing in…' : 'Sign in',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 14),
                          if (state.isBusy)
                            const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.black))
                          else
                            const Icon(Icons.arrow_forward, size: 22),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('New here?'),
                    TextButton(
                        onPressed: () => _showInfo('Create an account',
                            'Account creation is not available yet.'),
                        style: TextButton.styleFrom(foregroundColor: authAmber),
                        child: const Text('Create an account')),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _formPane(bool wide) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: wide ? 56 : 24, vertical: 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (!wide) ...[
                      const AuthBrand(),
                      const SizedBox(height: 40),
                    ],
                    _formContent(wide),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Theme(
        data: AppTheme.dark(),
        child: Scaffold(
          backgroundColor: const Color(0xFF090C0E),
          body: SafeArea(
            child: LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1000;
              if (!wide) return _formPane(false);
              return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Expanded(flex: 54, child: AuthBrandPanel()),
                    Expanded(flex: 46, child: _formPane(true)),
                  ]);
            }),
          ),
        ),
      );
}

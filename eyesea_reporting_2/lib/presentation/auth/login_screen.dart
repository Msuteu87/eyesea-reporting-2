import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:wave/config.dart';
import 'package:wave/wave.dart';
import 'package:go_router/go_router.dart';
import '../../core/errors/exceptions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../providers/auth_provider.dart';

// TODO: [FEATURE] SSO Authentication - Pending Implementation
// - Google Sign In: Configure OAuth in Supabase dashboard, add google_sign_in package
// - Apple Sign In: Configure OAuth in Supabase, add sign_in_with_apple package
// - LinkedIn Sign In: Configure OAuth in Supabase dashboard

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isResettingPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = context.read<AuthProvider>();
      try {
        await authProvider.signIn(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } on AuthException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login failed. Please try again.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();

    // Validate email before sending reset
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address first.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final emailError = Validators.validateEmail(email);
    if (emailError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(emailError),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isResettingPassword = true);

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'com.mariussuteu.eyesea.eyeseareporting://reset-callback',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to $email'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send reset email. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResettingPassword = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Consistent spacing constant
    const double spacing = 16.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Stack(
        children: [
          // Wave Background
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 200,
            child: WaveWidget(
              config: CustomConfig(
                gradients: isDark
                    ? [
                        [
                          primaryColor.withValues(alpha: 0.2),
                          primaryColor.withValues(alpha: 0.2)
                        ],
                        [
                          primaryColor.withValues(alpha: 0.4),
                          primaryColor.withValues(alpha: 0.4)
                        ],
                        [
                          primaryColor.withValues(alpha: 0.6),
                          primaryColor.withValues(alpha: 0.6)
                        ],
                      ]
                    : [
                        [
                          primaryColor.withValues(alpha: 0.3),
                          primaryColor.withValues(alpha: 0.3)
                        ],
                        [
                          primaryColor.withValues(alpha: 0.4),
                          primaryColor.withValues(alpha: 0.4)
                        ],
                        [
                          primaryColor.withValues(alpha: 0.5),
                          primaryColor.withValues(alpha: 0.5)
                        ],
                      ],
                durations: [18000, 10000, 6000],
                heightPercentages: [0.20, 0.45, 0.60],
              ),
              size: const Size(double.infinity, double.infinity),
              waveAmplitude: 0,
            ),
          ),

          // Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: spacing),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo - theme-aware
                      SvgPicture.asset(
                        Theme.of(context).brightness == Brightness.dark
                            ? 'assets/images/logo_white.svg'
                            : 'assets/images/logo.svg',
                        height: 200,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 12),

                      // Login Card
                      Card(
                        elevation: 2,
                        shadowColor: AppColors.inkBlack.withValues(alpha: 0.1),
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: const TextStyle(
                                      fontFamily: 'Roboto',
                                      color: Colors.black87),
                                  decoration: const InputDecoration(
                                    labelText: 'Email Address',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                  validator: Validators.validateEmail,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: const TextStyle(
                                      fontFamily: 'Roboto',
                                      color: Colors.black87),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed: () {
                                        setState(() => _obscurePassword =
                                            !_obscurePassword);
                                      },
                                    ),
                                  ),
                                  validator: (value) =>
                                      Validators.validatePassword(value,
                                          minLength: 6),
                                ),

                                const SizedBox(height: 8),

                                // Forgot Password Link
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: GestureDetector(
                                    onTap: _isResettingPassword
                                        ? null
                                        : _handleForgotPassword,
                                    child: _isResettingPassword
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            'Forgot Password?',
                                            style: TextStyle(
                                              fontFamily: 'Roboto',
                                              fontSize: 13,
                                              color: primaryColor,
                                            ),
                                          ),
                                  ),
                                ),

                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed:
                                      context.watch<AuthProvider>().isLoading
                                          ? null
                                          : _handleLogin,
                                  child: context.watch<AuthProvider>().isLoading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Log In',
                                          style:
                                              TextStyle(fontFamily: 'Roboto')),
                                ),

                                const SizedBox(height: 8),

                                // Sign Up Link - compact, no container padding
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Don't have an account? ",
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 14,
                                        color: isDark
                                            ? AppColors.porcelain
                                                .withValues(alpha: 0.7)
                                            : AppColors.inkBlack
                                                .withValues(alpha: 0.6),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => context.go('/signup'),
                                      child: Text(
                                        'Sign Up',
                                        style: TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wave/config.dart';
import 'package:wave/wave.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

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
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Login failed: ${e.toString()}'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleSSO() async {
    try {
      await context.read<AuthProvider>().signInWithOAuth(OAuthProvider.google);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SSO Login Error: $e')),
        );
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
                      Image.asset(
                        Theme.of(context).brightness == Brightness.dark
                            ? 'assets/images/logo_white.png'
                            : 'assets/images/logo.png',
                        width: 200,
                        height: 220,
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
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!value.contains('@')) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
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
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    if (value.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
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

                      const SizedBox(height: 16),

                      // SSO Buttons Row - Google, Apple (TODO), LinkedIn (TODO)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Google SSO Button
                          InkWell(
                            onTap: () {
                              _handleSSO();
                            },
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              height: 60,
                              width: 60,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Image.asset(
                                'assets/images/google_logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),

                          const SizedBox(width: 20),

                          // Apple SSO Button - TODO: Implement Apple Sign In
                          InkWell(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Apple Sign In coming soon!'),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              height: 60,
                              width: 60,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(14),
                              child: const Icon(
                                Icons.apple,
                                size: 32,
                                color: Colors.black,
                              ),
                            ),
                          ),

                          const SizedBox(width: 20),

                          // LinkedIn SSO Button - TODO: Implement LinkedIn Sign In
                          InkWell(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('LinkedIn Sign In coming soon!'),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              height: 60,
                              width: 60,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(14),
                              child: const Icon(
                                Icons.link, // LinkedIn icon placeholder
                                size: 32,
                                color: Color(0xFF0A66C2), // LinkedIn blue
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
          ),
        ],
      ),
    );
  }
}

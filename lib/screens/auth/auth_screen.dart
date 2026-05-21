import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart' as ap;
import '../../theme/app_theme.dart';
import 'email_verification_screen.dart';

class AuthScreen extends StatefulWidget {
  final Function(String username) onAuthenticated;
  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // Sign In
  final _signInEmailCtrl = TextEditingController();
  final _signInPassCtrl = TextEditingController();
  // Sign Up
  final _signUpEmailCtrl = TextEditingController();
  final _signUpPassCtrl = TextEditingController();
  final _signUpUsernameCtrl = TextEditingController();

  bool _signInPassVisible = false;
  bool _signUpPassVisible = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _signInEmailCtrl.dispose();
    _signInPassCtrl.dispose();
    _signUpEmailCtrl.dispose();
    _signUpPassCtrl.dispose();
    _signUpUsernameCtrl.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _signIn() async {
    final auth = context.read<ap.AuthProvider>();
    final email = _signInEmailCtrl.text.trim();
    final pass = _signInPassCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }
    final err = await auth.signInWithEmail(email: email, password: pass);
    if (err == null && auth.username != null) {
      widget.onAuthenticated(auth.username!);
    } else if (err == 'EMAIL_NOT_VERIFIED') {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => EmailVerificationScreen(email: email, password: pass),
      ));
    } else if (err != null) {
      _showError(err);
    }
  }

  Future<void> _signUp() async {
    final auth = context.read<ap.AuthProvider>();
    final email = _signUpEmailCtrl.text.trim();
    final pass = _signUpPassCtrl.text.trim();
    final uname = _signUpUsernameCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty || uname.isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }
    if (uname.length < 3) {
      _showError('Username must be at least 3 characters.');
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(uname)) {
      _showError('Username may only contain letters, numbers, and underscores.');
      return;
    }
    final err = await auth.signUpWithEmail(
        email: email, password: pass, username: uname);
    if (err == 'VERIFY_EMAIL') {
      // Account created — send them to the verify screen
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => EmailVerificationScreen(email: email, password: pass),
      ));
    } else if (err != null) {
      _showError(err);
    }
  }

  Future<void> _googleSignIn() async {
    final auth = context.read<ap.AuthProvider>();
    final err = await auth.signInWithGoogle();
    if (err != null && err != 'Google sign-in cancelled.') {
      _showError(err);
    } else if (auth.username != null) {
      widget.onAuthenticated(auth.username!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ap.AuthProvider>();
    final isDark = true; // always dark for auth screen

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 52),

              // Logo + title
              Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.accentGreen, AppColors.accentCyan],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.wifi_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Aimesig',
                      style: TextStyle(
                          color: AppColors.textPrimary(isDark),
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5)),
                  Text('Secure. Fast. Private.',
                      style: TextStyle(
                          color: AppColors.textSecondary(isDark),
                          fontSize: 13)),
                ]),
              ]),

              const SizedBox(height: 40),

              // Google button
              _GoogleButton(onTap: auth.isLoading ? null : _googleSignIn),

              const SizedBox(height: 20),
              _Divider(isDark: isDark),
              const SizedBox(height: 20),

              // Tab bar
              Container(
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.accentGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary(isDark),
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                  tabs: const [
                    Tab(text: 'Sign In'),
                    Tab(text: 'Sign Up'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 380,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // ── Sign In ───────────────────────────────────────────
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Field(
                          controller: _signInEmailCtrl,
                          hint: 'Email address',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 14),
                        _Field(
                          controller: _signInPassCtrl,
                          hint: 'Password',
                          icon: Icons.lock_outline_rounded,
                          obscure: !_signInPassVisible,
                          isDark: isDark,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _signInPassVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textMuted(isDark),
                              size: 20,
                            ),
                            onPressed: () => setState(
                                () => _signInPassVisible = !_signInPassVisible),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _PrimaryButton(
                          label: 'Sign In',
                          loading: auth.isLoading,
                          onTap: _signIn,
                        ),
                      ],
                    ),

                    // ── Sign Up ───────────────────────────────────────────
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Field(
                          controller: _signUpUsernameCtrl,
                          hint: 'Choose a username (e.g. alex_42)',
                          icon: Icons.alternate_email_rounded,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          controller: _signUpEmailCtrl,
                          hint: 'Email address',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          controller: _signUpPassCtrl,
                          hint: 'Password (min 6 chars)',
                          icon: Icons.lock_outline_rounded,
                          obscure: !_signUpPassVisible,
                          isDark: isDark,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _signUpPassVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textMuted(isDark),
                              size: 20,
                            ),
                            onPressed: () => setState(
                                () => _signUpPassVisible = !_signUpPassVisible),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _PrimaryButton(
                          label: 'Create Account',
                          loading: auth.isLoading,
                          onTap: _signUp,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your username is permanent and unique — others will use it to find and message you.',
                          style: TextStyle(
                              color: AppColors.textMuted(isDark), fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────

class _GoogleButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _GoogleButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF3C3C3C), width: 1.5),
          backgroundColor: const Color(0xFF1E1E1E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google G icon via unicode
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(
                child: Text(
                  'G',
                  style: TextStyle(
                      color: Color(0xFF4285F4),
                      fontWeight: FontWeight.w800,
                      fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Continue with Google',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Divider(color: AppColors.darkBorder, thickness: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text('or',
            style:
                TextStyle(color: AppColors.textMuted(isDark), fontSize: 13)),
      ),
      Expanded(child: Divider(color: AppColors.darkBorder, thickness: 1)),
    ]);
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboardType;
  final bool isDark;
  final Widget? suffixIcon;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    required this.isDark,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: TextStyle(color: AppColors.textPrimary(isDark), fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textMuted(isDark), fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.textMuted(isDark), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.darkCard,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.darkBorder, width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: AppColors.accentGreen, width: 1.5)),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _PrimaryButton(
      {required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
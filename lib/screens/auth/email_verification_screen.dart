import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart' as ap;
import '../../theme/app_theme.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String password;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  bool _resending = false;
  bool _resentSuccess = false;
  late AnimationController _anim;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    setState(() { _resending = true; _resentSuccess = false; });
    final auth = context.read<ap.AuthProvider>();
    final err = await auth.resendVerificationEmail(widget.email, widget.password);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    } else {
      setState(() => _resentSuccess = true);
    }
    setState(() => _resending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: FadeTransition(
        opacity: _fade,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.accentGreen.withOpacity(0.3),
                        width: 1.5),
                  ),
                  child: const Icon(Icons.mark_email_unread_outlined,
                      color: AppColors.accentGreen, size: 40),
                ),
                const SizedBox(height: 32),

                const Text(
                  'Verify your email',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  'We sent a verification link to',
                  style: TextStyle(
                      color: AppColors.textSecondary(true), fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.email,
                  style: const TextStyle(
                    color: AppColors.accentGreen,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Click the link in that email to activate your account, then come back and sign in.',
                  style: TextStyle(
                      color: AppColors.textSecondary(true),
                      fontSize: 14,
                      height: 1.5),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Back to Sign In
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Back to Sign In',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),

                const SizedBox(height: 16),

                // Resend
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _resending ? null : _resend,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AppColors.accentGreen.withOpacity(0.5),
                          width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _resending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accentGreen))
                        : Text(
                            _resentSuccess
                                ? '✓ Email resent!'
                                : 'Resend verification email',
                            style: TextStyle(
                              color: _resentSuccess
                                  ? AppColors.accentGreen
                                  : AppColors.textSecondary(true),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 32),

                // Tip
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.darkCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.darkBorder, width: 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: AppColors.textMuted(true), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Check your spam folder if you don\'t see it within a minute.',
                          style: TextStyle(
                              color: AppColors.textSecondary(true),
                              fontSize: 13,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
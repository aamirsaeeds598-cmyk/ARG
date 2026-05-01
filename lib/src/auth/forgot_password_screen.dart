import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// ── Brand colours ─────────────────────────────────────────────────────────────
const _kBg       = Color(0xFFF5F7FA);
const _kCard     = Colors.white;
const _kBlue1    = Color(0xFF2563EB);
const _kBlue2    = Color(0xFF1D4ED8);
const _kBlueSoft = Color(0xFFEFF6FF);
const _kText     = Color(0xFF0F172A);
const _kSubText  = Color(0xFF64748B);
const _kDivider  = Color(0xFFE2E8F0);
const _kGreen    = Color(0xFF059669);
const _kGreenSoft= Color(0xFFECFDF5);
const _kRed      = Color(0xFFDC2626);
const _kRedSoft  = Color(0xFFFEF2F2);

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent    = false;
  String? _error;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email address.');
      return;
    }
    setState(() {
      _loading = true;
      _error   = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        // Re-animate the success state
        _animCtrl.reset();
        setState(() => _sent = true);
        _animCtrl.forward();
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq     = MediaQuery.of(context);
    final topPad = mq.padding.top;
    final botPad = mq.padding.bottom;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // ── Decorative background blobs ─────────────────────────────
          Positioned(
            top: -60.h,
            right: -40.w,
            child: Container(
              width: 220.w,
              height: 220.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kBlue1.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -80.h,
            left: -50.w,
            child: Container(
              width: 260.w,
              height: 260.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kBlue1.withValues(alpha: 0.05),
              ),
            ),
          ),

          // ── Main content ────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                children: [
                  SizedBox(height: 16.h),

                  // Back button row
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: _kCard,
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: _kDivider),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A)
                                  .withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back_ios_new,
                                size: 13.sp, color: _kBlue1),
                            SizedBox(width: 5.w),
                            Text('Back',
                                style: TextStyle(
                                    color: _kBlue1,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Expanded centre area ──────────────────────────────
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: Center(
                          child: SingleChildScrollView(
                            child: _sent
                                ? _SuccessContent(
                              email: _emailCtrl.text.trim(),
                              onBack: () =>
                                  Navigator.of(context).pop(),
                            )
                                : _FormContent(
                              emailCtrl: _emailCtrl,
                              loading: _loading,
                              error: _error,
                              onSend: _send,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Footer ───────────────────────────────────────────
                  Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: Text(
                      'We\'ll only use your email to send the reset link.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: _kSubText.withValues(alpha: 0.7),
                          fontSize: 11.sp),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Form content ──────────────────────────────────────────────────────────────

class _FormContent extends StatelessWidget {
  const _FormContent({
    required this.emailCtrl,
    required this.loading,
    required this.error,
    required this.onSend,
  });

  final TextEditingController emailCtrl;
  final bool loading;
  final String? error;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Icon badge ──────────────────────────────────────────────
        Center(
          child: Container(
            width: 72.w,
            height: 72.w,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), _kBlue2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                  color: _kBlue1.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(Icons.lock_reset_outlined,
                color: Colors.white, size: 32.sp),
          ),
        ),
        SizedBox(height: 24.h),

        // ── Headline ────────────────────────────────────────────────
        Text(
          'Forgot password?',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 26.sp,
              fontWeight: FontWeight.w800,
              color: _kText,
              letterSpacing: -0.5),
        ),
        SizedBox(height: 8.h),
        Text(
          'Enter your email and we\'ll send\nyou a password reset link.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14.sp, color: _kSubText, height: 1.5),
        ),
        SizedBox(height: 36.h),

        // ── Card ─────────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.all(22.w),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: _kDivider),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.07),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Label
              Text('Email Address',
                  style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: _kText)),
              SizedBox(height: 8.h),

              // Field
              Container(
                decoration: BoxDecoration(
                  color: _kBg,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: _kDivider),
                ),
                child: TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  onSubmitted: (_) => onSend(),
                  style:
                  TextStyle(color: _kText, fontSize: 14.sp),
                  decoration: InputDecoration(
                    hintText: 'you@example.com',
                    hintStyle: TextStyle(
                        color: _kSubText.withValues(alpha: 0.6),
                        fontSize: 14.sp),
                    prefixIcon: Icon(Icons.email_outlined,
                        color: _kSubText, size: 19.sp),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 14.w, vertical: 14.h),
                  ),
                ),
              ),
              SizedBox(height: 14.h),

              // Error
              if (error != null) ...[
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 12.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: _kRedSoft,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                        color: _kRed.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline,
                        color: _kRed, size: 15.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(error!,
                          style: TextStyle(
                              color: _kRed, fontSize: 13.sp)),
                    ),
                  ]),
                ),
                SizedBox(height: 14.h),
              ],

              // Send button
              GestureDetector(
                onTap: loading ? null : onSend,
                child: Container(
                  height: 50.h,
                  decoration: BoxDecoration(
                    gradient: loading
                        ? null
                        : const LinearGradient(
                      colors: [Color(0xFF3B82F6), _kBlue2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    color: loading ? _kDivider : null,
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: loading
                        ? null
                        : [
                      BoxShadow(
                        color: _kBlue1.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: loading
                      ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white),
                  )
                      : Row(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_outlined,
                          color: Colors.white, size: 16.sp),
                      SizedBox(width: 8.w),
                      Text('Send reset link',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15.sp)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Success content ───────────────────────────────────────────────────────────

class _SuccessContent extends StatelessWidget {
  const _SuccessContent({
    required this.email,
    required this.onBack,
  });

  final String email;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Icon ───────────────────────────────────────────────────
        Center(
          child: Container(
            width: 80.w,
            height: 80.w,
            decoration: BoxDecoration(
              color: _kGreenSoft,
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(
                  color: _kGreen.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: _kGreen.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(Icons.mark_email_read_outlined,
                color: _kGreen, size: 36.sp),
          ),
        ),
        SizedBox(height: 24.h),

        Text(
          'Check your inbox!',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 26.sp,
              fontWeight: FontWeight.w800,
              color: _kText,
              letterSpacing: -0.5),
        ),
        SizedBox(height: 10.h),
        Text(
          'We\'ve sent a password reset link to',
          textAlign: TextAlign.center,
          style:
          TextStyle(fontSize: 14.sp, color: _kSubText),
        ),
        SizedBox(height: 4.h),
        Text(
          email,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14.sp,
              color: _kBlue1,
              fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 32.h),

        // Info card
        Container(
          padding: EdgeInsets.all(18.w),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: _kDivider),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _CheckRow(
                icon: Icons.inbox_outlined,
                text: 'Check your spam folder if you don\'t see it',
              ),
              SizedBox(height: 12.h),
              _CheckRow(
                icon: Icons.schedule_outlined,
                text: 'The link will expire in 24 hours',
              ),
              SizedBox(height: 12.h),
              _CheckRow(
                icon: Icons.lock_outline,
                text: 'Never share your reset link with anyone',
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),

        // Back button
        GestureDetector(
          onTap: onBack,
          child: Container(
            height: 50.h,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), _kBlue2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: _kBlue1.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 14.sp),
                SizedBox(width: 8.w),
                Text('Back to sign in',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15.sp)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Check row ─────────────────────────────────────────────────────────────────

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: _kBlueSoft,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(icon, color: _kBlue1, size: 14.sp),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(text,
              style:
              TextStyle(color: _kSubText, fontSize: 13.sp, height: 1.4)),
        ),
      ],
    );
  }
}
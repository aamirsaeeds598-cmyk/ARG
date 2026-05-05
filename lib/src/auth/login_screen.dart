import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../data/firestore_paths.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController     = TextEditingController();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading      = false;
  bool _isSignup       = false;
  bool _obscure        = true;
  bool _rememberMe     = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<String?> _findFirstTeamId() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('teams')
          .limit(1)
          .get();
      return snap.docs.firstOrNull?.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // user cancelled
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );
      final cred = await FirebaseAuth.instance.signInWithCredential(credential);
      final uid   = cred.user!.uid;
      final email = cred.user!.email ?? '';
      final name  = cred.user!.displayName ?? email.split('@').first;

      // Ensure worker doc exists
      final ref = FirebaseFirestore.instance.doc(FirestorePaths.user(uid));
      final snap = await ref.get();
      if (!snap.exists) {
        final teamId = await _findFirstTeamId();
        await ref.set({
          'name':          name,
          'email':         email.toLowerCase(),
          'role':          'worker',
          'currentTeamId': teamId ?? '',
          'createdAt':     FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {    setState(() { _isLoading = true; _error = null; });
    try {
      final email    = _emailController.text.trim();
      final password = _passwordController.text;
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Email and password are required.');
      }
      if (_isSignup) {
        final name = _nameController.text.trim();
        if (name.isEmpty) throw Exception('Name is required.');
        final cred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
        // Auto-assign to first available team
        final teamId = await _findFirstTeamId();
        await FirebaseFirestore.instance
            .doc(FirestorePaths.user(cred.user!.uid))
            .set({
          'name':          name,
          'email':         email.toLowerCase(),
          'role':          'worker',
          'currentTeamId': teamId ?? '',
          'createdAt':     FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
     backgroundColor: Color(0xFFF5F7FA),

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 440.w),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 32.h),
                decoration: BoxDecoration(
                  color: Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: const [],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    // ── Logo ───────────────────────────────────────
                    Center(child: _ArgLogo()),
                    const SizedBox(height: 28),

                    // ── Heading ────────────────────────────────────
                    Text(
                      _isSignup ? 'Create account' : 'Welcome back',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        fontSize: 22.sp,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      _isSignup
                          ? 'Fill in your details to get started.'
                          : 'Please enter your details to sign in.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade500,
                        fontSize: 14.sp,
                      ),
                    ),
                    SizedBox(height: 28.h),

                    // ── Name (signup only) ─────────────────────────
                    if (_isSignup) ...[
                      _Label('Full name'),
                      SizedBox(height: 6.h),
                      _Field(
                        controller: _nameController,
                        hint: 'Enter your name',
                        icon: Icons.person_outline,
                      ),
                      SizedBox(height: 18.h),
                    ],

                    // ── Email ──────────────────────────────────────
                    _Label('Email Address'),
                    SizedBox(height: 6.h),
                    _Field(
                      controller: _emailController,
                      hint: 'Enter your email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: 18.h),

                    // ── Password ───────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _Label('Password'),
                        if (!_isSignup)
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            ),
                            child: Text(
                              'Forgot password?',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF2563EB),
                                fontWeight: FontWeight.w600,
                                fontSize: 13.sp,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon: Icon(Icons.lock_outline,
                            color: Colors.grey.shade400, size: 20.sp),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey.shade400,
                            size: 20.sp,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: const BorderSide(
                              color: Color(0xFF2563EB), width: 1.5),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 14.w, vertical: 14.h),
                      ),
                    ),
                    SizedBox(height: 14.h),

                    // ── Remember me (login only) ───────────────────
                    if (!_isSignup)
                      Row(
                        children: [
                          SizedBox(
                            width: 20.w,
                            height: 20.h,
                            child: Checkbox(
                              value: _rememberMe,
                              onChanged: (v) =>
                                  setState(() => _rememberMe = v ?? false),
                              activeColor: const Color(0xFF2563EB),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              side: BorderSide(
                                  color: Colors.grey.shade400, width: 1.5),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Text(
                            'Remember me for 30 days',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF374151),
                              fontSize: 13.sp,
                            ),
                          ),
                        ],
                      ),

                    SizedBox(height: 22.h),

                    // ── Error ──────────────────────────────────────
                    if (_error != null) ...[
                      Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(_error!,
                            style: TextStyle(
                                color: Colors.red.shade700, fontSize: 13.sp)),
                      ),
                      SizedBox(height: 16.h),
                    ],

                    // ── Sign In button ─────────────────────────────
                    SizedBox(
                      height: 52.h,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF38BDF8), Color(0xFF1D4ED8)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r)),
                          ),
                          child: _isLoading
                              ? SizedBox(
                            width: 20.w,
                            height: 20.h,
                            child: const CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                              : Text(
                            _isSignup ? 'Create account' : 'Sign In',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16.sp,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 24.h),

                    // ── Divider ────────────────────────────────────
                    Row(children: [
                      Expanded(child: Divider(color: Colors.grey.shade200)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        child: Text(
                          'Or continue with',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey.shade400),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade200)),
                    ]),
                    SizedBox(height: 16.h),

                    // ── Social buttons ─────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _SocialButton(
                            label: 'Google',
                            icon: _GoogleIcon(),
                            onTap: _isLoading ? () {} : _signInWithGoogle,
                          ),
                        ),
                        // SizedBox(width: 12.w),
                        // Expanded(
                        //   child: _SocialButton(
                        //     label: 'Apple',
                        //     icon: const Icon(Icons.apple, size: 20, color: Colors.black),
                        //     onTap: () {/* Apple sign-in placeholder */},
                        //   ),
                        // ),
                      ],
                    ),
                    SizedBox(height: 24.h),

                    // ── Bottom link ────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isSignup
                              ? 'Already have an account? '
                              : "Don't have an account? ",
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey.shade500),
                        ),
                        GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () => setState(() {
                            _isSignup = !_isSignup;
                            _error = null;
                          }),
                          child: Text(
                            _isSignup ? 'Sign in' : 'Contact Administrator',
                            style: TextStyle(
                              color: const Color(0xFF2563EB),
                              fontWeight: FontWeight.w600,
                              fontSize: 13.sp,
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
      ),
    );
  }
}

// ── ARG Logo widget ───────────────────────────────────────────────────────────

class _ArgLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Image.asset('assets/images/logo.png',
              height: 100.h,
              width: 200.w,)
          ],
        )
        // Coloured icon strip (water drop / flame / gear)

      ],
    );
  }
}

// ── Social button ─────────────────────────────────────────────────────────────

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        height: 48.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Google coloured "G" icon ──────────────────────────────────────────────────

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2;

    // Draw coloured arcs to approximate the Google "G"
    final colors = [
      const Color(0xFF4285F4), // blue   top-right
      const Color(0xFF34A853), // green  bottom-right
      const Color(0xFFFBBC05), // yellow bottom-left
      const Color(0xFFEA4335), // red    top-left
    ];

    for (int i = 0; i < 4; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.22
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.78),
        (-90 + i * 90) * (3.14159 / 180),
        80 * (3.14159 / 180),
        false,
        paint,
      );
    }

    // White horizontal bar for the "G" cutout
    final barPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(cx - 0.5, cy - size.height * 0.13,
          r + 1, size.height * 0.26),
      barPaint,
    );

    // Blue fill for right half of bar
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - size.height * 0.13,
          r * 0.78, size.height * 0.26),
      bluePaint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 13.sp,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF374151),
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20.sp),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      ),
    );
  }
}
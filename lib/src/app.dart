import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'splash_screen.dart';

// ── Change the font here — applies everywhere in the app ─────────────────────
const _appFont = 'Lato'; // swap to 'Poppins', 'Nunito', 'Lato', etc.

class JobberAdminApp extends StatelessWidget {
  const JobberAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      scaffoldBackgroundColor:   Color(0xFFF5F7FA),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
      useMaterial3: true,
      textTheme: GoogleFonts.getTextTheme(_appFont).apply(
        decoration: TextDecoration.none,
      ),
    );

    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, __) => MaterialApp(

        debugShowCheckedModeBanner: false,
        theme: theme,
        home: const SplashScreen(),
      ),
    );
  }
}

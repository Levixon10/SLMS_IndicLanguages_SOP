import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _progressCtrl;
  static const _bengaliChars = [
    'অ','আ','ক','খ','গ','চ','ট','ত','ন','প',
    'ব','ম','য','র','ল','শ','স','হ','ড','ঢ',
  ];

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..forward();

    Future.delayed(const Duration(milliseconds: 4600), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 700),
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween(begin: 0.97, end: 1.0).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOut),
              ),
              child: child,
            ),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final rng = Random(42);

    return Scaffold(
      backgroundColor: const Color(0xFF06060f),
      body: Stack(
        children: [
          // Floating Bengali characters
          ...List.generate(20, (i) {
            final x = rng.nextDouble() * size.width;
            final delay = rng.nextDouble() * 4000;
            final dur   = 5000 + rng.nextInt(4000);
            final sz    = 16.0 + rng.nextDouble() * 24;
            final char  = _bengaliChars[i % _bengaliChars.length];
            return Positioned(
              left: x,
              bottom: -40,
              child: Text(
                char,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: sz,
                  color: const Color(0xFFF59E0B).withOpacity(0.07 + rng.nextDouble() * 0.06),
                ),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .moveY(
                begin: 0, end: -(size.height + 80),
                duration: Duration(milliseconds: dur),
                delay: Duration(milliseconds: delay.toInt()),
                curve: Curves.linear,
              ),
            );
          }),

          // Centre content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bengali subtitle
                Text(
                  'যন্ত্র অনুবাদ',
                  style: GoogleFonts.cormorantGaramond(
                    color: const Color(0xFFF59E0B),
                    fontSize: 22,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 4,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 900.ms)
                    .slideY(begin: 0.3, curve: Curves.easeOut),

                const SizedBox(height: 16),

                // Main title — letter by letter
                _AnimatedTitle(),

                const SizedBox(height: 24),

                // Divider line
                Container(height: 1, width: 0, color: Colors.transparent)
                    .animate()
                    .custom(
                  delay: 1400.ms,
                  duration: 700.ms,
                  builder: (ctx, val, child) => Container(
                    height: 1,
                    width: val * 300,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFFF59E0B),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Pipeline subtitle
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Bengali', style: GoogleFonts.dmMono(
                      color: const Color(0xFF8B99AF), fontSize: 11, letterSpacing: 2,
                    )),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_rounded,
                        color: Color(0xFFF59E0B), size: 13),
                    const SizedBox(width: 10),
                    Text('English', style: GoogleFonts.dmMono(
                      color: const Color(0xFF8B99AF), fontSize: 11, letterSpacing: 2,
                    )),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_back_rounded,
                        color: Color(0xFFF59E0B), size: 13),
                    const SizedBox(width: 10),
                    Text('Bengali', style: GoogleFonts.dmMono(
                      color: const Color(0xFF8B99AF), fontSize: 11, letterSpacing: 2,
                    )),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 1700.ms, duration: 600.ms)
                    .slideY(begin: 0.2),

                const SizedBox(height: 52),

                // Progress bar
                SizedBox(
                  width: 240,
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: AnimatedBuilder(
                          animation: _progressCtrl,
                          builder: (_, __) => LinearProgressIndicator(
                            value: _progressCtrl.value,
                            backgroundColor: Colors.white.withOpacity(0.06),
                            valueColor: const AlwaysStoppedAnimation(Color(0xFFF59E0B)),
                            minHeight: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 2000.ms, duration: 400.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Letter-by-letter title animation
class _AnimatedTitle extends StatelessWidget {
  const _AnimatedTitle();

  @override
  Widget build(BuildContext context) {
    const word1 = 'Machine';
    const word2 = 'Translation';
    int ci = 0;

    Widget letter(String char, int index, {double rightPad = 0}) {
      return Text(
        char,
        style: GoogleFonts.cormorantGaramond(
          fontSize: 52,
          fontWeight: FontWeight.w300,
          height: 1.05,
          foreground: Paint()
            ..shader = const LinearGradient(
              colors: [Color(0xFFE8D5A3), Color(0xFFF59E0B), Color(0xFFFCD34D)],
            ).createShader(const Rect.fromLTWH(0, 0, 300, 60)),
        ),
      )
          .animate()
          .fadeIn(
        delay: Duration(milliseconds: 550 + index * 50),
        duration: 600.ms,
      )
          .slideY(
        begin: 0.8,
        end: 0,
        delay: Duration(milliseconds: 550 + index * 50),
        duration: 600.ms,
        curve: Curves.easeOut,
      );
    }

    final letters1 = word1.split('').map((c) => letter(c, ci++)).toList();
    ci++; // space
    final letters2 = word2.split('').map((c) => letter(c, ci++)).toList();

    return Column(
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: letters1),
        Row(mainAxisSize: MainAxisSize.min, children: letters2),
      ],
    );
  }
}

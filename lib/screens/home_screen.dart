import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../services/api_service.dart';
import '../widgets/pipeline_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  bool _isLoading = false;
  bool _serverOnline = false;
  TranslationResult? _result;
  String? _error;
  String _displayedText = '';
  Timer? _typewriterTimer;

  // Colours
  static const _bg         = Color(0xFF06060f);
  static const _surface    = Color(0xFF0e0e1a);
  static const _amber      = Color(0xFFF59E0B);
  static const _amberDim   = Color(0x22F59E0B);
  static const _textPri    = Color(0xFFDDE4ED);
  static const _textSec    = Color(0xFF8B99AF);
  static const _textMuted  = Color(0xFF4B5668);
  static const _border     = Color(0x11FFFFFF);
  static const _borderStr  = Color(0x20FFFFFF);

  @override
  void initState() {
    super.initState();
    _checkHealth();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _typewriterTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkHealth() async {
    final online = await ApiService.healthCheck();
    if (mounted) setState(() => _serverOnline = online);
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;
    _focusNode.unfocus();
    _typewriterTimer?.cancel();

    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
      _displayedText = '';
    });

    // Scroll down to response area
    await Future.delayed(const Duration(milliseconds: 100));
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 300,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );

    try {
      final result = await ApiService.generate(text);
      if (!mounted) return;
      setState(() {
        _result = result;
        _isLoading = false;
      });
      _startTypewriter(result.translatedResponse);
      // Scroll again once response arrives
      await Future.delayed(const Duration(milliseconds: 100));
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _startTypewriter(String text) {
    int index = 0;
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 18), (t) {
      if (index < text.length) {
        setState(() => _displayedText = text.substring(0, index + 1));
        index++;
      } else {
        t.cancel();
      }
    });
  }

  void _clear() {
    _typewriterTimer?.cancel();
    setState(() {
      _controller.clear();
      _result = null;
      _error = null;
      _displayedText = '';
    });
  }

  void _copyResponse() {
    if (_result == null) return;
    Clipboard.setData(ClipboardData(text: _result!.translatedResponse));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied to clipboard', style: GoogleFonts.dmSans()),
        backgroundColor: _surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showPipeline() {
    if (_result == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, sc) => SingleChildScrollView(
          controller: sc,
          child: PipelineSheet(result: _result!),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Background gradient mesh
          Positioned.fill(
            child: CustomPaint(painter: _MeshPainter()),
          ),
          // Content
          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 36),
                  _buildInputSection(),
                  const SizedBox(height: 16),
                  _buildActions(),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _buildError(),
                  ],
                  if (_isLoading || _result != null) ...[
                    const SizedBox(height: 28),
                    _buildResponse(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status dot + badge
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _amberDim,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: _amber.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _serverOnline ? const Color(0xFF34D399) : _textMuted,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Bengali  বাংলা',
                    style: GoogleFonts.dmMono(
                      color: _amber, fontSize: 10, letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Refresh health
          ],
        ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.3),

        const SizedBox(height: 18),

        // Title
        Text(
          'Machine\nTranslation',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 44,
            fontWeight: FontWeight.w300,
            height: 1.08,
            foreground: Paint()
              ..shader = const LinearGradient(
                colors: [Color(0xFFE8D5A3), Color(0xFFF59E0B), Color(0xFFFCD34D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(const Rect.fromLTWH(0, 0, 250, 100)),
          ),
        ).animate().fadeIn(delay: 100.ms, duration: 600.ms).slideY(begin: 0.2),

        const SizedBox(height: 12),

        Text(
          'Type a question in Bengali. Gemma will generate the answer via a translate → generate → translate pipeline.',
          style: GoogleFonts.dmSans(
            color: _textSec, fontSize: 13.5, height: 1.65, fontWeight: FontWeight.w300,
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
      ],
    );
  }

  // ── Input ────────────────────────────────────────────────────────────────

  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR QUESTION — আপনার প্রশ্ন',
          style: GoogleFonts.dmMono(
            color: _textMuted, fontSize: 10, letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _focusNode.hasFocus
                  ? _amber.withOpacity(0.45)
                  : _border,
            ),
            boxShadow: _focusNode.hasFocus
                ? [BoxShadow(color: _amber.withOpacity(0.06), blurRadius: 16, spreadRadius: 2)]
                : [],
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            maxLines: 5,
            maxLength: 2000,
            style: GoogleFonts.cormorantGaramond(
              color: _textPri, fontSize: 19, height: 1.65, fontWeight: FontWeight.w300,
            ),
            decoration: InputDecoration(
              hintText: 'এখানে আপনার প্রশ্ন লিখুন…',
              hintStyle: GoogleFonts.cormorantGaramond(
                color: _textMuted, fontSize: 19, fontWeight: FontWeight.w300,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(18),
              counterStyle: GoogleFonts.dmMono(color: _textMuted, fontSize: 10),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms, duration: 600.ms).slideY(begin: 0.2);
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _isLoading ? null : _submit,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                gradient: _isLoading
                    ? null
                    : const LinearGradient(
                  colors: [Color(0xFFD97706), Color(0xFFF59E0B), Color(0xFFFBBF24)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                color: _isLoading ? _surface : null,
                borderRadius: BorderRadius.circular(12),
                border: _isLoading ? Border.all(color: _border) : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isLoading)
                    SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _textMuted,
                      ),
                    )
                  else
                    const Icon(Icons.arrow_forward_rounded, color: Color(0xFF0c0a05), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _isLoading ? 'Generating…' : 'Generate Response',
                    style: GoogleFonts.dmSans(
                      color: _isLoading ? _textMuted : const Color(0xFF0c0a05),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _clear,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Text(
              'Clear',
              style: GoogleFonts.dmSans(color: _textSec, fontSize: 14),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms, duration: 600.ms);
  }

  // ── Error ────────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF87171).withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF87171).withOpacity(0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFCA5A5), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: GoogleFonts.dmSans(color: const Color(0xFFFCA5A5), fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2);
  }

  // ── Response ─────────────────────────────────────────────────────────────

  Widget _buildResponse() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RESPONSE — উত্তর',
          style: GoogleFonts.dmMono(color: _textMuted, fontSize: 10, letterSpacing: 1.8),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isLoading
                  ? _amber.withOpacity(0.2)
                  : _border,
            ),
          ),
          child: _isLoading
              ? _buildSkeleton()
              : _buildResponseContent(),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2);
  }

  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.white.withOpacity(0.04),
      highlightColor: Colors.white.withOpacity(0.09),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmerLine(0.92),
          const SizedBox(height: 10),
          _shimmerLine(0.85),
          const SizedBox(height: 10),
          _shimmerLine(0.78),
          const SizedBox(height: 10),
          _shimmerLine(0.55),
        ],
      ),
    );
  }

  Widget _shimmerLine(double widthFactor) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 14,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildResponseContent() {
    final isDone = _displayedText.length == (_result?.translatedResponse.length ?? 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _amberDim,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: _amber.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language_rounded, color: _amber, size: 10),
                  const SizedBox(width: 5),
                  Text(
                    'Bengali Response',
                    style: GoogleFonts.dmMono(color: _amber, fontSize: 10, letterSpacing: 1),
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (isDone) ...[
              GestureDetector(
                onTap: _copyResponse,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.copy_rounded, color: _textMuted, size: 10),
                      const SizedBox(width: 5),
                      Text(
                        'copy',
                        style: GoogleFonts.dmMono(color: _textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),

        // Response text with blinking cursor
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: _displayedText,
                style: GoogleFonts.cormorantGaramond(
                  color: _textPri,
                  fontSize: 19,
                  height: 1.75,
                  fontWeight: FontWeight.w300,
                ),
              ),
              if (!isDone)
                WidgetSpan(
                  child: _BlinkingCursor(),
                ),
            ],
          ),
        ),

        if (isDone) ...[
          const SizedBox(height: 20),
          // Pipeline button
          GestureDetector(
            onTap: _showPipeline,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: _border)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_tree_outlined, color: _textMuted, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    'VIEW TRANSLATION PIPELINE',
                    style: GoogleFonts.dmMono(
                      color: _textMuted, fontSize: 10, letterSpacing: 1.4,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.expand_less_rounded, color: _textMuted, size: 16),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Blinking cursor ──────────────────────────────────────────────────────────

class _BlinkingCursor extends StatefulWidget {
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 2, height: 20, margin: const EdgeInsets.only(left: 2),
        color: const Color(0xFFF59E0B),
      ),
    );
  }
}

// ── Mesh background painter ──────────────────────────────────────────────────

class _MeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.shader = RadialGradient(
      center: const Alignment(-0.8, -0.9),
      radius: 0.8,
      colors: [const Color(0xFFF59E0B).withOpacity(0.045), Colors.transparent],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    paint.shader = RadialGradient(
      center: const Alignment(0.9, 0.9),
      radius: 0.7,
      colors: [const Color(0xFF818CF8).withOpacity(0.04), Colors.transparent],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

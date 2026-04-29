import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class PipelineSheet extends StatelessWidget {
  final TranslationResult result;

  const PipelineSheet({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0e0e1a),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Text(
            'Translation Pipeline',
            style: GoogleFonts.dmMono(
              color: Colors.white38,
              fontSize: 11,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          _PipelineStep(
            number: '01',
            label: 'Bengali → English',
            text: result.englishQuery,
            color: const Color(0xFFF59E0B),
          ),
          _connector(),
          _PipelineStep(
            number: '02',
            label: "Gemma's Response",
            text: result.englishResponse,
            color: const Color(0xFF818CF8),
          ),
          _connector(),
          _PipelineStep(
            number: '03',
            label: 'English → Bengali',
            text: result.translatedResponse,
            color: const Color(0xFF2DD4BF),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _connector() {
    return Padding(
      padding: const EdgeInsets.only(left: 15),
      child: Container(width: 1, height: 12, color: Colors.white12),
    );
  }
}

class _PipelineStep extends StatelessWidget {
  final String number;
  final String label;
  final String text;
  final Color color;

  const _PipelineStep({
    required this.number,
    required this.label,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: GoogleFonts.dmMono(
              color: color, fontSize: 10, fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.dmMono(
                  color: Colors.white38, fontSize: 10, letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onLongPress: () {
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied', style: GoogleFonts.dmSans()),
                      backgroundColor: const Color(0xFF1e1e2e),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.07)),
                  ),
                  child: Text(
                    text.isEmpty ? '—' : text,
                    style: GoogleFonts.dmSans(
                      color: Colors.white60, fontSize: 13, height: 1.6,
                    ),
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

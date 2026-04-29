import 'dart:convert';
import 'package:http/http.dart' as http;

class TranslationResult {
  final String language;
  final String englishQuery;
  final String englishResponse;
  final String translatedResponse;

  TranslationResult({
    required this.language,
    required this.englishQuery,
    required this.englishResponse,
    required this.translatedResponse,
  });

  factory TranslationResult.fromJson(Map<String, dynamic> json) {
    return TranslationResult(
      language: json['language'] ?? '',
      englishQuery: json['english_query'] ?? '',
      englishResponse: json['english_response'] ?? '',
      translatedResponse: json['translated_response'] ?? '',
    );
  }
}

class ApiService {
  // ── CHANGE THIS to your ngrok URL when deploying ──────────────────────────
  static const String baseUrl = 'http://172.24.16.73:8000';

  static Future<TranslationResult> generate(String text) async {
    final uri = Uri.parse('$baseUrl/api/generate');

    final response = await http
        .post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'text': text,
        'language': 'Bengali',
        'max_new_tokens': 512,
        'temperature': 0.7,
      }),
    )
        .timeout(const Duration(minutes: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return TranslationResult.fromJson(data);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Server error ${response.statusCode}');
    }
  }

  static Future<bool> healthCheck() async {
    try {
      final uri = Uri.parse('$baseUrl/health');
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

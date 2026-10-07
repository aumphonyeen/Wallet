import 'dart:convert';

import 'package:http/http.dart' as http;

class FinancialQuote {
  const FinancialQuote({required this.quote, required this.author});

  final String quote;
  final String author;

  factory FinancialQuote.fromJson(Map<String, dynamic> json) {
    return FinancialQuote(
      quote: json['quote'] as String,
      author: json['author'] as String,
    );
  }
}

class QuoteService {
  QuoteService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  void dispose() => _client.close();

  Future<FinancialQuote> fetchQuote() async {
    final response = await _client
        .get(Uri.https('dummyjson.com', '/quotes/random'))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw http.ClientException(
        'เซิร์ฟเวอร์ตอบกลับ ${response.statusCode}',
        Uri.https('dummyjson.com', '/quotes/random'),
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return FinancialQuote.fromJson(json);
  }
}

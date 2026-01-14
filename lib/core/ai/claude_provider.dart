import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'ai_provider.dart';
import 'prompts.dart';

/// Claude Provider 实现
class ClaudeProvider implements AIProvider {
  final Dio _dio;
  final String apiKey;
  final String baseUrl;
  final String model;

  ClaudeProvider({
    required this.apiKey,
    this.baseUrl = 'https://api.anthropic.com/v1',
    this.model = 'claude-3-haiku-20240307',
    Dio? dio,
  }) : _dio = dio ?? Dio();

  @override
  String get name => 'Claude';

  @override
  Future<bool> testConnection() async {
    try {
      final response = await _dio.post(
        '$baseUrl/messages',
        options: Options(
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': model,
          'max_tokens': 10,
          'messages': [
            {'role': 'user', 'content': 'Hi'}
          ],
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  Stream<TranslationResult> translate({
    required String text,
    String from = 'auto',
    String to = 'zh',
  }) async* {
    try {
      final response = await _dio.post<ResponseBody>(
        '$baseUrl/messages',
        options: Options(
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.stream,
        ),
        data: {
          'model': model,
          'max_tokens': 4096,
          'stream': true,
          'system': Prompts.translateSystem,
          'messages': [
            {'role': 'user', 'content': Prompts.translateUser(text)},
          ],
        },
      );

      await for (final chunk in response.data!.stream) {
        final text = utf8.decode(chunk);
        final lines = text.split('\n').where((line) => line.isNotEmpty);

        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6);

            try {
              final json = jsonDecode(data);
              final type = json['type'] as String?;

              if (type == 'content_block_delta') {
                final text = json['delta']?['text'] as String?;
                if (text != null) {
                  yield TranslationResult(text: text, isComplete: false);
                }
              } else if (type == 'message_stop') {
                yield TranslationResult(text: '', isComplete: true);
                return;
              }
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      yield TranslationResult(text: 'Error: $e', isComplete: true);
    }
  }

  @override
  Stream<List<Example>> getExamples(String word) async* {
    yield* _streamJsonList<Example>(
      Prompts.examples(word),
      (json) => Example(
        scene: json['scene'] ?? '',
        original: json['original'] ?? '',
        translation: json['translation'] ?? '',
      ),
    );
  }

  @override
  Stream<List<MovieQuote>> getMovieQuotes(String word) async* {
    yield* _streamJsonList<MovieQuote>(
      Prompts.movieQuotes(word),
      (json) => MovieQuote(
        movie: json['movie'] ?? '',
        quote: json['quote'] ?? '',
        translation: json['translation'] ?? '',
      ),
    );
  }

  @override
  Stream<List<ExamItem>> getExamItems(String word) async* {
    yield* _streamJsonList<ExamItem>(
      Prompts.examItems(word),
      (json) => ExamItem(
        source: json['source'] ?? '',
        question: json['question'] ?? '',
        answer: json['answer'] ?? '',
      ),
    );
  }

  Stream<List<T>> _streamJsonList<T>(
    String prompt,
    T Function(Map<String, dynamic>) fromJson,
  ) async* {
    final buffer = StringBuffer();

    try {
      final response = await _dio.post<ResponseBody>(
        '$baseUrl/messages',
        options: Options(
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.stream,
        ),
        data: {
          'model': model,
          'max_tokens': 4096,
          'stream': true,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        },
      );

      await for (final chunk in response.data!.stream) {
        final text = utf8.decode(chunk);
        final lines = text.split('\n').where((line) => line.isNotEmpty);

        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6);

            try {
              final json = jsonDecode(data);
              final type = json['type'] as String?;

              if (type == 'content_block_delta') {
                final text = json['delta']?['text'] as String?;
                if (text != null) {
                  buffer.write(text);
                }
              } else if (type == 'message_stop') {
                try {
                  final jsonStr = buffer.toString().trim();
                  final list = jsonDecode(jsonStr) as List;
                  yield list.map((e) => fromJson(e)).toList();
                } catch (_) {
                  yield [];
                }
                return;
              }
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      yield [];
    }
  }
}

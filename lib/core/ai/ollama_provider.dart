import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'ai_provider.dart';
import 'prompts.dart';

/// Ollama Provider 实现 (本地模型)
class OllamaProvider implements AIProvider {
  final Dio _dio;
  final String baseUrl;
  final String model;

  OllamaProvider({
    this.baseUrl = 'http://0.0.0.0:11434',
    this.model = 'llama3.2',
    Dio? dio,
  }) : _dio = dio ?? Dio();

  @override
  String get name => 'Ollama';

  @override
  Future<bool> testConnection() async {
    try {
      final response = await _dio.get('$baseUrl/api/tags');
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
      final response   = await _dio.post<ResponseBody>(
        '$baseUrl/api/generate',
        options: Options(
          responseType: ResponseType.stream,
        ),
        data: {
          'model': model,
          'prompt': '${Prompts.translateSystem(from: from, to: to)}\n\n${Prompts.translateUser(text)}',
          'stream': true,
        },
      );

      await for (final chunk in response.data!.stream) {
        final text = utf8.decode(chunk);
        final lines = text.split('\n').where((line) => line.isNotEmpty);

        for (final line in lines) {
          try {
            final json = jsonDecode(line);
            final text = json['response'] as String?;
            final done = json['done'] as bool? ?? false;

            if (text != null && text.isNotEmpty) {
              yield TranslationResult(text: text, isComplete: false);
            }

            if (done) {
              yield TranslationResult(text: '', isComplete: true);
              return;
            }
          } catch (_) {}
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
        '$baseUrl/api/generate',
        options: Options(
          responseType: ResponseType.stream,
        ),
        data: {
          'model': model,
          'prompt': prompt,
          'stream': true,
        },
      );

      await for (final chunk in response.data!.stream) {
        final text = utf8.decode(chunk);
        final lines = text.split('\n').where((line) => line.isNotEmpty);

        for (final line in lines) {
          try {
            final json = jsonDecode(line);
            final text = json['response'] as String?;
            final done = json['done'] as bool? ?? false;

            if (text != null) {
              buffer.write(text);
            }

            if (done) {
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
    } catch (e) {
      yield [];
    }
  }
}

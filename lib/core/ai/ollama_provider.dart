import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'ai_provider.dart';

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
          'prompt': '你是翻译助手。只返回翻译结果，不要解释。\n\n翻译到$to：$text',
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
    final prompt = '''
为单词/短语 "$word" 提供3个不同场景的例句。
请严格按照以下JSON格式返回：
[
  {"scene": "日常对话", "original": "英文例句", "translation": "中文翻译"},
  {"scene": "商务场景", "original": "英文例句", "translation": "中��翻译"},
  {"scene": "学术写作", "original": "英文例句", "translation": "中文翻译"}
]
只返回JSON，不要其他内容。
''';

    yield* _streamJsonList<Example>(
      prompt,
      (json) => Example(
        scene: json['scene'] ?? '',
        original: json['original'] ?? '',
        translation: json['translation'] ?? '',
      ),
    );
  }

  @override
  Stream<List<MovieQuote>> getMovieQuotes(String word) async* {
    final prompt = '''
提供包含 "$word" 的3句经典电影台词。
请严格按照以下JSON格式返回：
[
  {"movie": "电影名", "quote": "台词原文", "translation": "中文翻译"},
  {"movie": "电影名", "quote": "台词原文", "translation": "中文翻译"},
  {"movie": "电影名", "quote": "台词原文", "translation": "中文翻译"}
]
只返回JSON，不要其他内容。
''';

    yield* _streamJsonList<MovieQuote>(
      prompt,
      (json) => MovieQuote(
        movie: json['movie'] ?? '',
        quote: json['quote'] ?? '',
        translation: json['translation'] ?? '',
      ),
    );
  }

  @override
  Stream<List<ExamItem>> getExamItems(String word) async* {
    final prompt = '''
提供包含 "$word" 的3道英语考试真题（如高考、四六级、托福、雅思）。
请严格按照以下JSON格式返回：
[
  {"source": "考试来源", "question": "题目", "answer": "答案解析"},
  {"source": "考试来源", "question": "题目", "answer": "答案解析"},
  {"source": "考试来源", "question": "题目", "answer": "答案解析"}
]
只返回JSON，不要其他内容。
''';

    yield* _streamJsonList<ExamItem>(
      prompt,
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

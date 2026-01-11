import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'ai_provider.dart';

/// DeepSeek Provider 实现
class DeepSeekProvider implements AIProvider {
  final Dio _dio;
  final String apiKey;
  final String baseUrl;
  final String model;

  DeepSeekProvider({
    required this.apiKey,
    this.baseUrl = 'https://api.deepseek.com/v1',
    this.model = 'deepseek-chat',
    Dio? dio,
  }) : _dio = dio ?? Dio();

  @override
  String get name => 'DeepSeek';

  @override
  Future<bool> testConnection() async {
    try {
      final response = await _dio.get(
        '$baseUrl/models',
        options: Options(
          headers: {'Authorization': 'Bearer $apiKey'},
        ),
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
        '$baseUrl/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.stream,
        ),
        data: {
          'model': model,
          'stream': true,
          'messages': [
            {
              'role': 'system',
              'content': '你是翻译助手。只返回翻译结果，不要解释。'
            },
            {
              'role': 'user',
              'content': '翻译到$to：$text',
            },
          ],
        },
      );

      final stream = response.data!.stream;

      await for (final chunk in stream) {
        final text = utf8.decode(chunk);
        final lines = text.split('\n').where((line) => line.isNotEmpty);

        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (data == '[DONE]') {
              yield TranslationResult(text: '', isComplete: true);
              return;
            }

            try {
              final json = jsonDecode(data);
              final content =
                  json['choices']?[0]?['delta']?['content'] as String?;
              if (content != null) {
                yield TranslationResult(text: content, isComplete: false);
              }
            } catch (_) {
              // Skip invalid JSON
            }
          }
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
  {"scene": "商务场景", "original": "英文例句", "translation": "中文翻译"},
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
        '$baseUrl/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.stream,
        ),
        data: {
          'model': model,
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
            if (data == '[DONE]') {
              try {
                final jsonStr = buffer.toString().trim();
                final list = jsonDecode(jsonStr) as List;
                yield list.map((e) => fromJson(e)).toList();
              } catch (_) {
                yield [];
              }
              return;
            }

            try {
              final json = jsonDecode(data);
              final content =
                  json['choices']?[0]?['delta']?['content'] as String?;
              if (content != null) {
                buffer.write(content);
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

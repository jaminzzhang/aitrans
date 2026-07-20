import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aitrans/core/ai/ai_provider.dart';
import 'package:aitrans/core/ai/claude_provider.dart';
import 'package:aitrans/core/ai/prompts.dart';
import 'package:aitrans/core/ai/review_ai_models.dart';
import 'package:test/test.dart';

void main() {
  test(
    'ranks review candidates through the Claude messages endpoint',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      late Map<String, dynamic> requestBody;
      var requestCount = 0;
      server.listen((request) async {
        requestCount++;
        requestBody =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType(
            'text',
            'event-stream',
            charset: 'utf-8',
          )
          ..write(
            'data: ${jsonEncode({
              'type': 'content_block_delta',
              'delta': {
                'text': jsonEncode({
                  'contractVersion': 1,
                  'rankedItems': [
                    {'id': 'candidate-1', 'reason': 'Frequently forgotten'},
                  ],
                }),
              },
            })}\n\n',
          )
          ..write('data: ${jsonEncode({'type': 'message_stop'})}\n\n');
        await request.response.close();
      });
      final provider = ClaudeProvider(
        apiKey: 'test-key',
        baseUrl: 'http://127.0.0.1:${server.port}',
        model: 'test-model',
      );
      addTearDown(provider.close);
      final request = ReviewAIRankRequest(
        candidates: [
          ReviewAICandidate(
            id: 'candidate-1',
            term: 'otter',
            sourceLanguage: 'en',
            targetLanguage: 'zh',
            translationCount: 2,
            consecutiveRememberedCount: 0,
            forgetCount: 1,
            overdueMinutes: 60,
            daysSinceLastReview: 2,
          ),
        ],
      );

      final response = await provider.rankReviewCandidates(request);

      expect(response.rankedItems.single.id, 'candidate-1');
      expect(requestCount, 1);
      expect(requestBody['model'], 'test-model');
      expect(requestBody['messages'], [
        {'role': 'user', 'content': Prompts.reviewRanking(request)},
      ]);
    },
  );

  test('cancels an in-flight Claude review ranking request', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final requestSeen = Completer<void>();
    final releaseServer = Completer<void>();
    addTearDown(() {
      if (!releaseServer.isCompleted) releaseServer.complete();
    });
    server.listen((request) async {
      await utf8.decoder.bind(request).join();
      requestSeen.complete();
      await releaseServer.future;
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        )
        ..write('data: ${jsonEncode({'type': 'message_stop'})}\n\n');
      await request.response.close();
    });
    final provider = ClaudeProvider(
      apiKey: 'test-key',
      baseUrl: 'http://127.0.0.1:${server.port}',
      model: 'test-model',
    );
    addTearDown(provider.close);
    final result = provider.rankReviewCandidates(
      ReviewAIRankRequest(
        candidates: [
          ReviewAICandidate(
            id: 'candidate-1',
            term: 'otter',
            sourceLanguage: 'en',
            targetLanguage: 'zh',
            translationCount: 1,
            consecutiveRememberedCount: 0,
            forgetCount: 0,
            overdueMinutes: 1,
            daysSinceLastReview: null,
          ),
        ],
      ),
    );
    await requestSeen.future;

    await provider.cancelActiveRequests();

    await expectLater(
      result.timeout(const Duration(seconds: 1)),
      throwsA(
        isA<AIProviderException>().having(
          (error) => error.code,
          'code',
          AIProviderErrorCode.cancelled,
        ),
      ),
    );
  });

  test('generates review text through one Claude messages request', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    late Map<String, dynamic> requestBody;
    var requestCount = 0;
    server.listen((request) async {
      requestCount++;
      requestBody =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        )
        ..write(
          'data: ${jsonEncode({
            'type': 'content_block_delta',
            'delta': {
              'text': jsonEncode({
                'contractVersion': 1,
                'everydayUsages': [
                  {'situation': '社区活动', 'original': 'This game will break the ice.', 'translation': '这个游戏能帮助大家打破僵局。'},
                ],
                'fictionalDialogue': {'dialogue': 'It is time to break the ice.', 'translation': '是时候打破僵局了。'},
              }),
            },
          })}\n\n',
        )
        ..write('data: ${jsonEncode({'type': 'message_stop'})}\n\n');
      await request.response.close();
    });
    final provider = ClaudeProvider(
      apiKey: 'test-key',
      baseUrl: 'http://127.0.0.1:${server.port}',
      model: 'test-model',
    );
    addTearDown(provider.close);
    final contentRequest = ReviewAITextContentRequest(
      term: 'break the ice',
      sourceLanguage: 'en',
      targetLanguage: 'zh',
      primaryMeaning: '打破僵局',
    );

    final response = await provider.generateReviewTextContent(contentRequest);

    expect(response.everydayUsages.single.situation, '社区活动');
    expect(requestCount, 1);
    expect(requestBody['messages'], [
      {'role': 'user', 'content': Prompts.reviewTextContent(contentRequest)},
    ]);
  });
}

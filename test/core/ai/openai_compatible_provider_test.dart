import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aitrans/core/ai/ai.dart';
import 'package:aitrans/core/ai/prompts.dart';
import 'package:test/test.dart';

void main() {
  test('streams translation through an OpenAI-compatible endpoint', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);

    late Map<String, dynamic> requestBody;
    server.listen((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/v1/chat/completions');
      requestBody =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );

      final payload = utf8.encode(
        'data: ${jsonEncode({
          'id': 'chat-test',
          'object': 'chat.completion.chunk',
          'created': 1,
          'model': 'test-model',
          'choices': [
            {
              'index': 0,
              'delta': {'content': '你'},
              'finish_reason': null,
            },
          ],
        })}\n\n'
        'data: ${jsonEncode({
          'id': 'chat-test',
          'object': 'chat.completion.chunk',
          'created': 1,
          'model': 'test-model',
          'choices': [
            {
              'index': 0,
              'delta': {'content': '好'},
              'finish_reason': null,
            },
          ],
        })}\n\n'
        'data: [DONE]\n\n',
      );
      final splitAt = payload.indexOf(0xe4) + 1;
      request.response.add(payload.sublist(0, splitAt));
      await request.response.flush();
      request.response.add(payload.sublist(splitAt));
      await request.response.close();
    });

    final provider = OpenAICompatibleProvider(
      providerName: 'Test',
      apiKey: 'test-key',
      baseUrl: 'http://127.0.0.1:${server.port}/v1',
      model: 'test-model',
    );
    addTearDown(provider.close);

    final events = await provider
        .translate(text: 'hello', from: 'en', to: 'zh')
        .toList();

    expect(events.map((event) => event.text), ['你', '好', '']);
    expect(events.last.isComplete, isTrue);
    expect(requestBody['model'], 'test-model');
    expect(requestBody['stream'], isTrue);
    expect(requestBody['messages'], [
      {
        'role': 'system',
        'content': Prompts.translateSystem(from: 'en', to: 'zh'),
      },
      {'role': 'user', 'content': Prompts.translateUser('hello')},
    ]);
  });

  test('cancelActiveRequests aborts an in-flight HTTP stream', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final firstChunkSent = Completer<void>();
    final releaseServer = Completer<void>();

    server.listen((request) async {
      await utf8.decoder.bind(request).join();
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        )
        ..write(
          'data: {"choices":[{"index":0,"delta":{"content":"first"},"finish_reason":null}]}\n\n',
        );
      await request.response.flush();
      firstChunkSent.complete();
      await releaseServer.future;
      request.response.write(
        'data: {"choices":[{"index":0,"delta":{"content":"second"},"finish_reason":null}]}\n\n',
      );
      await request.response.close();
    });

    final provider = OpenAICompatibleProvider(
      providerName: 'Test',
      apiKey: 'test-key',
      baseUrl: 'http://127.0.0.1:${server.port}/v1',
      model: 'test-model',
    );
    addTearDown(provider.close);

    final events = <TranslationResult>[];
    final streamDone = Completer<void>();
    final subscription = provider.translate(text: 'hello').listen((event) {
      events.add(event);
    }, onDone: streamDone.complete);
    await firstChunkSent.future;
    await provider.cancelActiveRequests();
    await streamDone.future.timeout(const Duration(seconds: 2));
    releaseServer.complete();

    expect(events.map((event) => event.text), isNot(contains('second')));
    await subscription.cancel();
  });

  test('loads all enrichment sections with one AI request', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    var requestCount = 0;

    server.listen((request) async {
      requestCount++;
      await utf8.decoder.bind(request).join();
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        )
        ..write(
          'data: ${jsonEncode({
            'choices': [
              {
                'index': 0,
                'delta': {
                  'content': jsonEncode({
                    'examples': [
                      {'scene': '日常', 'original': 'Hello there.', 'translation': '你好。'},
                    ],
                    'movieQuotes': [
                      {'movie': 'Test Movie', 'quote': 'Hello, world.', 'translation': '你好，世界。'},
                    ],
                    'examItems': [
                      {'source': 'Test Exam', 'question': 'Say hello.', 'answer': 'Hello.'},
                    ],
                  }),
                },
                'finish_reason': null,
              },
            ],
          })}\n\n',
        )
        ..write('data: [DONE]\n\n');
      await request.response.close();
    });

    final provider = OpenAICompatibleProvider(
      providerName: 'Test',
      apiKey: 'test-key',
      baseUrl: 'http://127.0.0.1:${server.port}/v1',
      model: 'test-model',
    );
    addTearDown(provider.close);

    final enrichment = await provider.enrichTranslation('hello').single;

    expect(requestCount, 1);
    expect(enrichment.examples.single.scene, '日常');
    expect(enrichment.movieQuotes.single.movie, 'Test Movie');
    expect(enrichment.examItems.single.source, 'Test Exam');
  });
}

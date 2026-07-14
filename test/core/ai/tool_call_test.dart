// ignore_for_file: unnecessary_string_escapes

import 'dart:convert';
import 'dart:io';

import 'package:aitrans/core/ai/ai.dart';
import 'package:test/test.dart';

void main() {
  test('reassembles a streamed tool call and accepts its explicit result', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final bodies = <Map<String, dynamic>>[];

    server.listen((request) async {
      bodies.add(
        jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>,
      );
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );

      if (bodies.length == 1) {
        request.response.write(
          'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call_1","type":"function","function":{"name":"get_weather","arguments":"{\\\"loc"}}]},"finish_reason":null}]}\n\n',
        );
        await request.response.flush();
        request.response.write(
          'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"ation\\\":\\\"Tokyo\\\"}"}}]},"finish_reason":"tool_calls"}]}\n\n',
        );
      } else {
        request.response.write(
          'data: {"choices":[{"index":0,"delta":{"content":"sunny"},"finish_reason":"stop"}]}\n\n',
        );
      }
      request.response.write('data: [DONE]\n\n');
      await request.response.close();
    });

    final provider = OpenAICompatibleProvider(
      providerName: 'Test',
      apiKey: 'test-key',
      baseUrl: 'http://127.0.0.1:${server.port}/v1',
      model: 'test-model',
    );
    addTearDown(provider.close);
    const tool = AIFunctionTool(
      name: 'get_weather',
      description: 'Get weather for a city',
      parameters: {
        'type': 'object',
        'properties': {
          'location': {'type': 'string'},
        },
        'required': ['location'],
        'additionalProperties': false,
      },
    );

    final firstEvents = await provider
        .chat(
          const AIChatRequest(
            messages: [AIChatMessage.user('weather')],
            tools: [tool],
            toolChoice: AIToolChoice.required(),
          ),
        )
        .toList();
    final call = firstEvents.expand((event) => event.toolCalls).single;
    expect(call.id, 'call_1');
    expect(call.name, 'get_weather');
    expect(call.arguments, {'location': 'Tokyo'});
    expect(bodies.first['tool_choice'], 'required');
    expect(bodies.first['tools'], hasLength(1));

    final secondEvents = await provider
        .chat(
          AIChatRequest(
            messages: [
              const AIChatMessage.user('weather'),
              AIChatMessage.assistantToolCalls([call]),
              const AIChatMessage.toolResult(
                toolCallId: 'call_1',
                content: '{"temperature":22}',
              ),
            ],
            tools: const [tool],
          ),
        )
        .toList();

    expect(secondEvents.map((event) => event.textDelta), contains('sunny'));
    expect((bodies[1]['messages'] as List).map((message) => message['role']), [
      'user',
      'assistant',
      'tool',
    ]);
    expect(bodies[1]['tools'], hasLength(1));
  });

  test('rejects tool arguments that violate the declared schema', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
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
          'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call_bad","type":"function","function":{"name":"get_weather","arguments":"{}"}}]},"finish_reason":"tool_calls"}]}\n\n',
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

    await expectLater(
      provider.chat(
        const AIChatRequest(
          messages: [AIChatMessage.user('weather')],
          tools: [
            AIFunctionTool(
              name: 'get_weather',
              description: 'Get weather',
              parameters: {
                'type': 'object',
                'properties': {
                  'location': {'type': 'string'},
                },
                'required': ['location'],
                'additionalProperties': false,
              },
            ),
          ],
        ),
      ),
      emitsError(
        isA<AIProviderException>().having(
          (error) => error.code,
          'code',
          AIProviderErrorCode.invalidResponse,
        ),
      ),
    );
  });

  test(
    'rejects unknown tool results and excessive rounds before network',
    () async {
      final provider = OpenAICompatibleProvider(
        providerName: 'Test',
        apiKey: 'test-key',
        baseUrl: 'http://127.0.0.1:1/v1',
        model: 'test-model',
      );
      addTearDown(provider.close);

      await expectLater(
        provider
            .chat(
              const AIChatRequest(
                messages: [
                  AIChatMessage.toolResult(
                    toolCallId: 'unknown',
                    content: '{}',
                  ),
                ],
              ),
            )
            .toList(),
        throwsA(isA<AIProviderException>()),
      );
      await expectLater(
        provider
            .chat(
              const AIChatRequest(
                messages: [AIChatMessage.user('loop')],
                toolRound: 8,
                maxToolRounds: 8,
              ),
            )
            .toList(),
        throwsA(isA<AIProviderException>()),
      );
    },
  );
}

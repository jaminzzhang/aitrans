import 'dart:async';
import 'dart:convert';

import 'package:openai_dart/openai_dart.dart';

import 'ai_provider.dart';
import 'ai_chat.dart';
import 'prompts.dart';

/// OpenAI Chat Completions compatible provider used by remote and local models.
class OpenAICompatibleProvider extends AIProvider {
  final String providerName;
  final String apiKey;
  final String baseUrl;
  final String model;
  final OpenAIClient _client;
  final Set<Completer<void>> _activeAborts = {};

  OpenAICompatibleProvider({
    required this.providerName,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    Duration timeout = const Duration(seconds: 60),
    OpenAIClient? client,
  }) : _client =
           client ??
           OpenAIClient(
             config: OpenAIConfig(
               authProvider: ApiKeyProvider(apiKey.isEmpty ? 'ollama' : apiKey),
               baseUrl: baseUrl,
               timeout: timeout,
               retryPolicy: const RetryPolicy(maxRetries: 0),
             ),
           );

  @override
  String get name => providerName;

  @override
  String get cacheNamespace => '$providerName|$baseUrl|$model';

  @override
  Future<void> cancelActiveRequests() async {
    for (final abort in _activeAborts.toList()) {
      if (!abort.isCompleted) {
        abort.complete();
      }
    }
  }

  @override
  void close() {
    cancelActiveRequests();
    _client.close();
  }

  @override
  Future<bool> testConnection() async {
    try {
      await _client.models.list();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<AIChatEvent> chat(AIChatRequest request) {
    try {
      _validateChatRequest(request);
    } on AIProviderException catch (error) {
      return Stream.error(error);
    }

    final sdkRequest = ChatCompletionCreateRequest(
      model: model,
      messages: request.messages.map(_toSdkMessage).toList(),
      tools: request.tools
          .map(
            (tool) => Tool.function(
              name: tool.name,
              description: tool.description,
              parameters: tool.parameters,
            ),
          )
          .toList(),
      toolChoice: _toSdkToolChoice(request.toolChoice),
      parallelToolCalls: true,
    );
    return _chatStream(sdkRequest, request.tools);
  }

  Stream<AIChatEvent> _chatStream(
    ChatCompletionCreateRequest request,
    List<AIFunctionTool> declaredTools,
  ) {
    final abort = Completer<void>();
    late StreamController<AIChatEvent> controller;

    Future<void> run() async {
      _activeAborts.add(abort);
      final accumulator = ChatStreamAccumulator();
      try {
        final stream = _client.chat.completions.createStream(
          request,
          abortTrigger: abort.future,
        );
        await for (final event in stream) {
          if (abort.isCompleted) break;
          accumulator.add(event);
          final text = event.textDelta;
          if (text != null && text.isNotEmpty) {
            controller.add(AIChatEvent(textDelta: text));
          }
        }
        if (!abort.isCompleted && accumulator.toolCalls.isNotEmpty) {
          final calls = _validateToolCalls(
            accumulator.toolCalls,
            declaredTools,
          );
          controller.add(AIChatEvent(toolCalls: calls));
        }
        if (!abort.isCompleted) {
          controller.add(const AIChatEvent(isComplete: true));
        }
      } on AbortedException {
        // Explicit cancellation closes the stream without an error event.
      } on AIProviderException catch (error) {
        controller.addError(error);
      } catch (_) {
        if (!abort.isCompleted) {
          controller.addError(
            const AIProviderException(
              code: AIProviderErrorCode.requestFailed,
              message: 'AI request failed. Please retry.',
            ),
          );
        }
      } finally {
        _activeAborts.remove(abort);
        await controller.close();
      }
    }

    controller = StreamController<AIChatEvent>(
      onListen: () => unawaited(run()),
      onCancel: () {
        if (!abort.isCompleted) abort.complete();
      },
    );
    return controller.stream;
  }

  ChatMessage _toSdkMessage(AIChatMessage message) => switch (message.role) {
    AIChatRole.system => ChatMessage.system(message.content!),
    AIChatRole.user => ChatMessage.user(message.content!),
    AIChatRole.assistant when message.toolCalls.isNotEmpty =>
      ChatMessage.assistant(
        toolCalls: message.toolCalls
            .map(
              (call) => ToolCall.functionCall(
                id: call.id,
                call: FunctionCall.fromMap(
                  name: call.name,
                  arguments: call.arguments,
                ),
              ),
            )
            .toList(),
      ),
    AIChatRole.assistant => ChatMessage.assistant(content: message.content),
    AIChatRole.tool => ChatMessage.tool(
      toolCallId: message.toolCallId!,
      content: message.content!,
    ),
  };

  ToolChoice _toSdkToolChoice(AIToolChoice choice) => switch (choice.mode) {
    AIToolChoiceMode.auto => ToolChoice.auto(),
    AIToolChoiceMode.none => ToolChoice.none(),
    AIToolChoiceMode.required => ToolChoice.required(),
    AIToolChoiceMode.function => ToolChoice.function(choice.functionName!),
  };

  void _validateChatRequest(AIChatRequest request) {
    if (request.messages.isEmpty) {
      throw const AIProviderException(
        code: AIProviderErrorCode.invalidConfiguration,
        message: 'At least one chat message is required.',
      );
    }
    if (request.toolRound >= request.maxToolRounds) {
      throw const AIProviderException(
        code: AIProviderErrorCode.invalidConfiguration,
        message: 'The maximum tool-call round count was reached.',
      );
    }
    final names = <String>{};
    for (final tool in request.tools) {
      if (!RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(tool.name) ||
          !names.add(tool.name)) {
        throw const AIProviderException(
          code: AIProviderErrorCode.invalidConfiguration,
          message: 'Tool names must be unique and use safe characters.',
        );
      }
      if (tool.parameters['type'] != 'object' ||
          tool.parameters['properties'] is! Map) {
        throw const AIProviderException(
          code: AIProviderErrorCode.invalidConfiguration,
          message: 'Tool parameters must use an object JSON Schema.',
        );
      }
    }
    if (request.toolChoice.mode == AIToolChoiceMode.function &&
        !names.contains(request.toolChoice.functionName)) {
      throw const AIProviderException(
        code: AIProviderErrorCode.invalidConfiguration,
        message: 'The selected tool was not declared.',
      );
    }
    final knownCallIds = request.messages
        .expand((message) => message.toolCalls)
        .map((call) => call.id)
        .toSet();
    for (final message in request.messages.where(
      (message) => message.role == AIChatRole.tool,
    )) {
      if (!knownCallIds.contains(message.toolCallId)) {
        throw const AIProviderException(
          code: AIProviderErrorCode.invalidConfiguration,
          message: 'Tool results must reference a known call ID.',
        );
      }
    }
  }

  List<AIToolCall> _validateToolCalls(
    List<ToolCall> calls,
    List<AIFunctionTool> declaredTools,
  ) {
    final tools = {for (final tool in declaredTools) tool.name: tool};
    final ids = <String>{};
    return calls.map((call) {
      final tool = tools[call.function.name];
      if (tool == null || !ids.add(call.id)) {
        throw const AIProviderException(
          code: AIProviderErrorCode.invalidResponse,
          message:
              'The AI service returned an undeclared or duplicate tool call.',
        );
      }
      Map<String, dynamic> arguments;
      try {
        arguments = call.function.argumentsMap;
      } on Object {
        throw const AIProviderException(
          code: AIProviderErrorCode.invalidResponse,
          message: 'The AI service returned invalid tool arguments.',
        );
      }
      if (!_matchesSchema(arguments, tool.parameters)) {
        throw const AIProviderException(
          code: AIProviderErrorCode.invalidResponse,
          message: 'The AI service returned invalid tool arguments.',
        );
      }
      return AIToolCall(
        id: call.id,
        name: call.function.name,
        arguments: arguments,
      );
    }).toList();
  }

  bool _matchesSchema(Object? value, Map<String, dynamic> schema) {
    final enumValues = schema['enum'];
    if (enumValues is List && !enumValues.contains(value)) return false;
    final type = schema['type'];
    if (type == 'string') return value is String;
    if (type == 'number') return value is num;
    if (type == 'integer') return value is int;
    if (type == 'boolean') return value is bool;
    if (type == 'array') {
      if (value is! List) return false;
      final itemSchema = schema['items'];
      return itemSchema is! Map ||
          value.every(
            (item) => _matchesSchema(item, itemSchema.cast<String, dynamic>()),
          );
    }
    if (type == 'object') {
      if (value is! Map<String, dynamic>) return false;
      final properties = (schema['properties'] as Map).cast<String, dynamic>();
      final required =
          (schema['required'] as List?)?.cast<String>() ?? const [];
      if (required.any((name) => !value.containsKey(name))) return false;
      if (schema['additionalProperties'] == false &&
          value.keys.any((name) => !properties.containsKey(name))) {
        return false;
      }
      for (final entry in value.entries) {
        final propertySchema = properties[entry.key];
        if (propertySchema is Map &&
            !_matchesSchema(
              entry.value,
              propertySchema.cast<String, dynamic>(),
            )) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  @override
  Stream<TranslationResult> translate({
    required String text,
    String from = 'auto',
    String to = 'zh',
  }) {
    final request = ChatCompletionCreateRequest(
      model: model,
      messages: [
        ChatMessage.system(Prompts.translateSystem(from: from, to: to)),
        ChatMessage.user(Prompts.translateUser(text)),
      ],
    );
    return _translationStream(request);
  }

  Stream<TranslationResult> _translationStream(
    ChatCompletionCreateRequest request,
  ) {
    final abort = Completer<void>();
    late StreamController<TranslationResult> controller;

    Future<void> run() async {
      _activeAborts.add(abort);
      try {
        final stream = _client.chat.completions.createStream(
          request,
          abortTrigger: abort.future,
        );
        await for (final event in stream) {
          if (abort.isCompleted) break;
          final delta = event.textDelta;
          if (delta != null && delta.isNotEmpty) {
            controller.add(TranslationResult(text: delta, isComplete: false));
          }
        }
        if (!abort.isCompleted) {
          controller.add(TranslationResult(text: '', isComplete: true));
        }
      } on AbortedException {
        // Cancellation is an explicit terminal path, not a user-facing error.
      } catch (_) {
        if (!abort.isCompleted) {
          controller.addError(
            const AIProviderException(
              code: AIProviderErrorCode.requestFailed,
              message: 'AI request failed. Please retry.',
            ),
          );
        }
      } finally {
        _activeAborts.remove(abort);
        await controller.close();
      }
    }

    controller = StreamController<TranslationResult>(
      onListen: () => unawaited(run()),
      onCancel: () {
        if (!abort.isCompleted) abort.complete();
      },
    );
    return controller.stream;
  }

  @override
  Stream<List<Example>> getExamples(String word) async* {
    final json = await _requestJsonList(Prompts.examples(word));
    yield json
        .map(
          (item) => Example(
            scene: item['scene'] as String? ?? '',
            original: item['original'] as String? ?? '',
            translation: item['translation'] as String? ?? '',
          ),
        )
        .toList();
  }

  @override
  Stream<TranslationEnrichment> enrichTranslation(String text) async* {
    final json = await _requestJsonObject(Prompts.translationEnrichment(text));
    yield TranslationEnrichment.fromJson(json);
  }

  @override
  Stream<List<MovieQuote>> getMovieQuotes(String word) async* {
    final json = await _requestJsonList(Prompts.movieQuotes(word));
    yield json
        .map(
          (item) => MovieQuote(
            movie: item['movie'] as String? ?? '',
            quote: item['quote'] as String? ?? '',
            translation: item['translation'] as String? ?? '',
          ),
        )
        .toList();
  }

  @override
  Stream<List<ExamItem>> getExamItems(String word) async* {
    final json = await _requestJsonList(Prompts.examItems(word));
    yield json
        .map(
          (item) => ExamItem(
            source: item['source'] as String? ?? '',
            question: item['question'] as String? ?? '',
            answer: item['answer'] as String? ?? '',
          ),
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> _requestJsonList(String prompt) async {
    final buffer = StringBuffer();
    try {
      final stream = _client.chat.completions.createStream(
        ChatCompletionCreateRequest(
          model: model,
          messages: [ChatMessage.user(prompt)],
        ),
      );
      await for (final event in stream) {
        buffer.write(event.textDelta ?? '');
      }
      final decoded = jsonDecode(buffer.toString());
      if (decoded is! List) {
        throw const FormatException('Expected a JSON array.');
      }
      return decoded
          .map((item) => (item as Map).cast<String, dynamic>())
          .toList();
    } catch (_) {
      throw const AIProviderException(
        code: AIProviderErrorCode.invalidResponse,
        message: 'The AI service returned an invalid response.',
      );
    }
  }

  Future<Map<String, dynamic>> _requestJsonObject(String prompt) async {
    final buffer = StringBuffer();
    final abort = Completer<void>();
    _activeAborts.add(abort);
    try {
      final stream = _client.chat.completions.createStream(
        ChatCompletionCreateRequest(
          model: model,
          messages: [ChatMessage.user(prompt)],
        ),
        abortTrigger: abort.future,
      );
      await for (final event in stream) {
        if (abort.isCompleted) break;
        buffer.write(event.textDelta ?? '');
      }
      final decoded = jsonDecode(buffer.toString());
      if (decoded is! Map) {
        throw const FormatException('Expected a JSON object.');
      }
      return decoded.cast<String, dynamic>();
    } on AbortedException {
      throw const AIProviderException(
        code: AIProviderErrorCode.cancelled,
        message: 'AI request was cancelled.',
      );
    } on AIProviderException {
      rethrow;
    } catch (_) {
      throw const AIProviderException(
        code: AIProviderErrorCode.invalidResponse,
        message: 'The AI service returned an invalid response.',
      );
    } finally {
      _activeAborts.remove(abort);
    }
  }
}

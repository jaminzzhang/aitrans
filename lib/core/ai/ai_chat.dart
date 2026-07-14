enum AIChatRole { system, user, assistant, tool }

class AIFunctionTool {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  const AIFunctionTool({
    required this.name,
    required this.description,
    required this.parameters,
  });
}

class AIToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  const AIToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });
}

class AIChatMessage {
  final AIChatRole role;
  final String? content;
  final List<AIToolCall> toolCalls;
  final String? toolCallId;

  const AIChatMessage.user(this.content)
    : role = AIChatRole.user,
      toolCalls = const [],
      toolCallId = null;

  const AIChatMessage.system(this.content)
    : role = AIChatRole.system,
      toolCalls = const [],
      toolCallId = null;

  const AIChatMessage.assistant(this.content)
    : role = AIChatRole.assistant,
      toolCalls = const [],
      toolCallId = null;

  const AIChatMessage.assistantToolCalls(this.toolCalls)
    : role = AIChatRole.assistant,
      content = null,
      toolCallId = null;

  const AIChatMessage.toolResult({
    required this.toolCallId,
    required this.content,
  }) : role = AIChatRole.tool,
       toolCalls = const [];
}

enum AIToolChoiceMode { auto, none, required, function }

class AIToolChoice {
  final AIToolChoiceMode mode;
  final String? functionName;

  const AIToolChoice.auto() : mode = AIToolChoiceMode.auto, functionName = null;

  const AIToolChoice.none() : mode = AIToolChoiceMode.none, functionName = null;

  const AIToolChoice.required()
    : mode = AIToolChoiceMode.required,
      functionName = null;

  const AIToolChoice.function(String name)
    : mode = AIToolChoiceMode.function,
      functionName = name;
}

class AIChatRequest {
  final List<AIChatMessage> messages;
  final List<AIFunctionTool> tools;
  final AIToolChoice toolChoice;
  final int toolRound;
  final int maxToolRounds;

  const AIChatRequest({
    required this.messages,
    this.tools = const [],
    this.toolChoice = const AIToolChoice.auto(),
    this.toolRound = 0,
    this.maxToolRounds = 8,
  });
}

class AIChatEvent {
  final String textDelta;
  final List<AIToolCall> toolCalls;
  final bool isComplete;

  const AIChatEvent({
    this.textDelta = '',
    this.toolCalls = const [],
    this.isComplete = false,
  });
}

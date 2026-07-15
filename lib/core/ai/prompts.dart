/// 统一管理所有 AI 提示词
class Prompts {
  Prompts._();

  /// 翻译系统提示词
  /// [from] 源语言代码，'auto' 表示自动检测
  /// [to] 目标语言代码
  static String translateSystem({String from = 'auto', String to = 'zh'}) {
    final targetLangName = _languageNames[to] ?? to;
    final task = from == 'auto'
        ? '自动识别输入语言，并翻译成$targetLangName'
        : '将输入的${_languageNames[from] ?? from}文字翻译成$targetLangName';

    return '''
你是翻译助手。$task。

输出规则：
- 输入是单个词或短语时，第一行只输出最主要、最常用的词义，不加序号、标签或解释。
- 第二行起输出 2 至 4 个常见补充词义，每行以「- 」开头；必要时可保留简短词性，但不要重复主词义。
- 输入是完整句子或段落时，只输出一行自然、完整的译文，不拆分词义。
- 不要输出标题、前言、Markdown 代码块或规则说明。
''';
  }

  /// 语言代码到名称的映射
  static const Map<String, String> _languageNames = {
    'zh': '简体中文',
    'en': '英文',
    'ja': '日语',
    'ko': '韩语',
    'fr': '法语',
    'de': '德语',
    'es': '西班牙语',
    'ru': '俄语',
    'pt': '葡萄牙语',
    'it': '意大利语',
  };

  /// 翻译用户提示词
  static String translateUser(String text) => '翻译：$text';

  /// 一次请求生成全部扩展内容。
  static String translationEnrichment(String text) =>
      '''
围绕单词、短语或文本 "$text" 一次生成三类学习扩展内容。
请严格按照以下 JSON 对象格式返回，每个数组各 3 项：
{
  "examples": [
    {"scene": "场景", "original": "原文例句", "translation": "中文翻译"}
  ],
  "movieQuotes": [
    {"movie": "电影名", "quote": "台词原文", "translation": "中文翻译"}
  ],
  "examItems": [
    {"source": "考试来源", "question": "题目", "answer": "答案解析"}
  ]
}
只返回 JSON，不要 Markdown 代码块或其他内容。''';

  /// 例句提示词
  static String examples(String word) =>
      '''
为单词/短语 "$word" 提供3个不同场景的例句。
请严格按照以下JSON格式返回：
[
  {"scene": "日常对话", "original": "英文例句", "translation": "中文翻译"},
  {"scene": "商务场景", "original": "英文例句", "translation": "中文翻译"},
  {"scene": "学术写作", "original": "英文例句", "translation": "中文翻译"}
]
只返回JSON，不要其他内容。''';

  /// 电影台词提示词
  static String movieQuotes(String word) =>
      '''
提供包含 "$word" 的3句经典电影台词。
请严格按照以下JSON格式返回：
[
  {"movie": "电影名", "quote": "台词原文", "translation": "中文翻译"},
  {"movie": "电影名", "quote": "台词原文", "translation": "中文翻译"},
  {"movie": "电影名", "quote": "台词原文", "translation": "中文翻译"}
]
只返回JSON，不要其他内容。''';

  /// 考试真题提示词
  static String examItems(String word) =>
      '''
提供包含 "$word" 的3道英语考试真题（如高考、四六级、托福��雅思）。
请严格按照以下JSON格式返回：
[
  {"source": "考试来源", "question": "题目", "answer": "答案解析"},
  {"source": "考试来源", "question": "题目", "answer": "答案解析"},
  {"source": "考试来源", "question": "题目", "answer": "答案解析"}
]
只返回JSON，不要其他内容。''';
}

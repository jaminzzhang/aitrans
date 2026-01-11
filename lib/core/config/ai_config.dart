import 'package:hive/hive.dart';
import '../ai/provider_factory.dart';

part 'ai_config.g.dart';

/// AI 配置模型
@HiveType(typeId: 0)
class AIConfig extends HiveObject {
  @HiveField(0)
  ProviderType providerType;

  @HiveField(1)
  String? apiKey;

  @HiveField(2)
  String? baseUrl;

  @HiveField(3)
  String? model;

  AIConfig({
    this.providerType = ProviderType.openai,
    this.apiKey,
    this.baseUrl,
    this.model,
  });

  AIConfig copyWith({
    ProviderType? providerType,
    String? apiKey,
    String? baseUrl,
    String? model,
  }) {
    return AIConfig(
      providerType: providerType ?? this.providerType,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
    );
  }
}

/// ProviderType 的 Hive 适配器
class ProviderTypeAdapter extends TypeAdapter<ProviderType> {
  @override
  final int typeId = 1;

  @override
  ProviderType read(BinaryReader reader) {
    final index = reader.readInt();
    return ProviderType.values[index];
  }

  @override
  void write(BinaryWriter writer, ProviderType obj) {
    writer.writeInt(obj.index);
  }
}

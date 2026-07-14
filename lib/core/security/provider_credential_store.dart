import '../ai/provider_factory.dart';

abstract interface class ProviderCredentialStore {
  Future<String?> read(ProviderType providerType);

  Future<void> write(ProviderType providerType, String? credential);
}

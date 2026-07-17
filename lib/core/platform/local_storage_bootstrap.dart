import 'dart:io';

typedef ApplicationSupportDirectoryProvider = Future<Directory> Function();
typedef HivePathInitializer = void Function(String path);

class LocalStorageBootstrap {
  static const directoryName = 'AITrans';

  final ApplicationSupportDirectoryProvider getApplicationSupportDirectory;
  final HivePathInitializer initializeHive;

  const LocalStorageBootstrap({
    required this.getApplicationSupportDirectory,
    required this.initializeHive,
  });

  Future<Directory> initialize() async {
    final applicationSupport = await getApplicationSupportDirectory();
    final storageDirectory = Directory(
      '${applicationSupport.path}${Platform.pathSeparator}$directoryName',
    );
    await storageDirectory.create(recursive: true);
    initializeHive(storageDirectory.path);
    return storageDirectory;
  }
}

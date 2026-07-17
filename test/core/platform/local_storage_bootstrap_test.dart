import 'dart:io';

import 'package:aitrans/core/platform/local_storage_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'initializes Hive in the private AITrans application support directory',
    () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'aitrans-storage-bootstrap-',
      );
      addTearDown(() => temporaryDirectory.delete(recursive: true));
      final applicationSupport = Directory(
        '${temporaryDirectory.path}/Application Support/com.aitrans.aitrans',
      );
      String? initializedPath;
      final bootstrap = LocalStorageBootstrap(
        getApplicationSupportDirectory: () async => applicationSupport,
        initializeHive: (path) => initializedPath = path,
      );

      final storageDirectory = await bootstrap.initialize();

      expect(storageDirectory.path, '${applicationSupport.path}/AITrans');
      expect(storageDirectory.existsSync(), isTrue);
      expect(initializedPath, storageDirectory.path);
      expect(initializedPath, isNot(contains('Documents')));
    },
  );
}

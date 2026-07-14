import 'dart:io';

import 'package:aitrans/core/security/local_master_key_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDirectory;
  late File keyFile;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'aitrans-master-key-test-',
    );
    keyFile = File('${tempDirectory.path}/security/master-key-v1');
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('creates one 256-bit key and reuses it after reconstruction', () async {
    final expected = List<int>.generate(32, (index) => index);
    final firstStore = LocalMasterKeyStore(
      keyFile,
      randomBytes: (_) => expected,
    );

    final first = await (await firstStore.create()).extractBytes();
    final reconstructed = LocalMasterKeyStore(
      keyFile,
      randomBytes: (_) => List<int>.filled(32, 255),
    );
    final second = await (await reconstructed.loadExisting())!.extractBytes();

    expect(first, expected);
    expect(second, expected);
    expect(await keyFile.readAsBytes(), expected);
    if (Platform.isMacOS || Platform.isLinux) {
      expect((await keyFile.stat()).mode & 0x3F, 0);
    }
  });

  test('rejects a damaged key without replacing it', () async {
    await keyFile.parent.create(recursive: true);
    final damaged = List<int>.filled(31, 7);
    await keyFile.writeAsBytes(damaged, flush: true);
    final store = LocalMasterKeyStore(
      keyFile,
      randomBytes: (_) => List<int>.filled(32, 9),
    );

    await expectLater(
      store.loadExisting(),
      throwsA(isA<MasterKeyUnavailableException>()),
    );
    expect(await keyFile.readAsBytes(), damaged);
  });

  test('recovers a complete pending key after an interrupted create', () async {
    final expected = List<int>.filled(32, 19);
    await keyFile.parent.create(recursive: true);
    await File('${keyFile.path}.pending').writeAsBytes(expected, flush: true);

    final recovered = await LocalMasterKeyStore(keyFile).loadExisting();

    expect(await recovered!.extractBytes(), expected);
    expect(await keyFile.readAsBytes(), expected);
    expect(await File('${keyFile.path}.pending').exists(), isFalse);
  });

  test('reset removes the key and pending recovery file', () async {
    final store = LocalMasterKeyStore(
      keyFile,
      randomBytes: (_) => List<int>.filled(32, 21),
    );
    await store.create();
    await File(
      '${keyFile.path}.pending',
    ).writeAsBytes(List<int>.filled(32, 22));

    await store.reset();

    expect(await keyFile.exists(), isFalse);
    expect(await File('${keyFile.path}.pending').exists(), isFalse);
    expect(await store.loadExisting(), isNull);
  });
}

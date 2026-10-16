import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:elum/core/storage/card_image_disk_cache.dart';
import 'package:elum/features/child/data/card_speech_repository.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:flutter_test/flutter_test.dart';

/// 단계 음성 파일 캐시 (#675).
///
/// 같은 음성을 누를 때마다 받으면 느리고 서버 부담이 크다. 글을 고친 뒤 옛 음성이 남으면 옛 문장이 읽힌다.
void main() {
  late Directory root;
  late _SpeechAdapter adapter;
  late CardImageDiskCache imageCache;
  late CardSpeechRepository repository;

  CardSpeechRepository build({int maxBytes = CardSpeechRepository.defaultMaxBytes}) {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))..httpClientAdapter = adapter;
    return CardSpeechRepository(
      dio: dio,
      imageCache: imageCache,
      rootProvider: () async => root,
      maxBytes: maxBytes,
    );
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('elum_speech_cache_');
    adapter = _SpeechAdapter();
    imageCache = CardImageDiskCache(rootProvider: () async => root);
    repository = build();
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  const source = (routineId: 'r-1', stepId: 's-1', speechPath: 's-1/aaaa.wav');

  test('한 번 받은 음성은 다시 누르면 받지 않고 파일로 재생한다', () async {
    final first = await repository.fileFor(source);
    final second = await repository.fileFor(source);

    expect(first, isNotNull);
    expect(second!.path, first!.path);
    expect(adapter.calls, 1);
  });

  test('빠르게 연타해도 받기는 한 번이다', () async {
    await Future.wait([repository.fileFor(source), repository.fileFor(source)]);

    expect(adapter.calls, 1);
  });

  test('글을 고쳐 열쇠가 바뀌면 새로 받고 옛 음성 파일은 지운다', () async {
    final oldFile = await repository.fileFor(source);
    adapter.keyByStepId['s-1'] = 's-1/bbbb.wav';
    final newFile = await repository.fileFor((routineId: 'r-1', stepId: 's-1', speechPath: 's-1/bbbb.wav'));

    expect(newFile!.path, isNot(oldFile!.path));
    expect(oldFile.existsSync(), isFalse);
    expect(adapter.calls, 2);
  });

  test('WAV 가 아닌 응답은 저장하지 않고 null — 오류 페이지를 소리로 틀지 않게', () async {
    adapter.body = Uint8List.fromList('<html>error</html>'.codeUnits);

    expect(await repository.fileFor(source), isNull);
    expect(await repository.fileFor(source), isNull);
    expect(adapter.calls, 2);
  });

  test('서버에 아직 없으면(404) null — 기기 음성으로 넘어간다', () async {
    adapter.status = 404;

    expect(await repository.fileFor(source), isNull);
  });

  test('열쇠를 모르는 카드도 ETag 열쇠로 저장한다 — 카드확인 화면은 목록이 갱신되기 전이다', () async {
    final file = await repository.fileFor((routineId: 'r-1', stepId: 's-1', speechPath: null));
    final again = await repository.fileFor(source);

    expect(file, isNotNull);
    expect(again!.path, file!.path);
    expect(adapter.calls, 1);
  });

  test('열쇠를 모르는 카드를 다시 누르면 304 로 확인만 하고 파일로 재생한다 — 매번 받지 않게', () async {
    const unknownKey = (routineId: 'r-1', stepId: 's-1', speechPath: null);
    final first = await repository.fileFor(unknownKey);
    final second = await repository.fileFor(unknownKey);

    expect(second!.path, first!.path);
    expect(adapter.notModifiedCalls, 1);
  });

  test('열쇠를 모르는 카드의 글을 고쳐 서버에 음성이 없으면(404) 옛 음성을 버린다 — 옛 문장이 읽히지 않게', () async {
    const unknownKey = (routineId: 'r-1', stepId: 's-1', speechPath: null);
    final oldFile = await repository.fileFor(unknownKey);
    adapter.status = 404;

    expect(await repository.fileFor(unknownKey), isNull);
    expect(oldFile!.existsSync(), isFalse);
  });

  test('일과를 열 때 열쇠가 빈 카드(글 수정 후 다시 만드는 중)의 옛 음성을 지운다', () async {
    final oldFile = await repository.fileFor(source);

    await repository.syncRoutine('r-1', [const ActionCard(id: 's-1', description: '새 글')]);

    expect(oldFile!.existsSync(), isFalse);
  });

  test('로그아웃으로 카드 캐시를 지우면 음성도 함께 지워진다', () async {
    final file = await repository.fileFor(source);

    await imageCache.clear();

    expect(file!.existsSync(), isFalse);
  });

  test('용량 상한을 넘으면 오래 안 쓴 음성부터 지운다 — 지운 카드 음성이 쌓이지 않게', () async {
    repository = build(maxBytes: _SpeechAdapter.wavBytes.length + 1);
    final older = await repository.fileFor(source);
    await older!.setLastModified(DateTime(2020));

    final newer = await repository.fileFor((routineId: 'r-1', stepId: 's-2', speechPath: 's-2/cccc.wav'));

    expect(older.existsSync(), isFalse);
    expect(newer!.existsSync(), isTrue);
  });
}

/// 음성 응답 대역: 상태·본문을 바꿔 가며 호출 수를 센다
class _SpeechAdapter implements HttpClientAdapter {
  static final wavBytes = Uint8List.fromList([
    0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x41, 0x56, 0x45, 1, 2, 3, 4, //
  ]);

  int calls = 0;
  int notModifiedCalls = 0;
  int status = 200;
  Uint8List body = wavBytes;
  final keyByStepId = <String, String>{'s-1': 's-1/aaaa.wav'};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    // 서버의 지금 열쇠 흉내 (경로 /api/routines/{r}/steps/{s}/speech)
    final stepId = options.path.split('/')[5];
    final key = keyByStepId[stepId] ?? '$stepId/cccc.wav';
    // 가진 열쇠와 같으면 304 (실제 서버와 같은 ETag 규칙)
    final isSameKey = options.headers['If-None-Match'] == '"$key"';
    final responseStatus = status == 200 && isSameKey ? 304 : status;
    if (responseStatus == 304) notModifiedCalls++;
    return ResponseBody.fromBytes(
      responseStatus == 200 ? body : const [],
      responseStatus,
      headers: {
        Headers.contentTypeHeader: ['audio/wav'],
        'etag': ['"$key"'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

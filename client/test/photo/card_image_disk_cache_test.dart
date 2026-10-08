import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/auth/data/oauth_sdk.dart';
import 'package:elum/core/storage/card_image_disk_cache.dart';
import 'package:elum/features/guardian/data/card_image_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elum/app/dio_provider.dart';

/// 카드 그림 디스크 캐시 (#462).
///
/// 메모리에만 두면 앱을 다시 켜거나 오프라인일 때 전에 본 그림이 사라지고, 한 번 실패한
/// 결과는 앱을 다시 켤 때까지 남았다. 실제 임시 폴더에 파일을 쓰며 검증한다.
void main() {
  late Directory root;
  late _Adapter adapter;
  late Dio dio;

  // 매직바이트만 맞는 가짜 PNG/JPEG. 디코딩은 하지 않는다.
  Uint8List png([int extra = 0]) => Uint8List.fromList(
      [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, ...List.filled(8 + extra, 7)]);
  Uint8List jpeg() => Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);
  Uint8List webp() => Uint8List.fromList(
      [0x52, 0x49, 0x46, 0x46, 1, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, 9]);

  CardImageDiskCache newCache({int? maxBytes, int? maxFiles, int? maxEntry}) =>
      CardImageDiskCache(
        rootProvider: () async => root,
        maxBytes: maxBytes ?? CardImageDiskCache.defaultMaxBytes,
        maxFiles: maxFiles ?? CardImageDiskCache.defaultMaxFiles,
        maxEntryBytes: maxEntry ?? CardImageDiskCache.defaultMaxEntryBytes,
      );

  CardImageRepository newRepo(CardImageDiskCache cache) =>
      CardImageRepository(dio: dio, diskCache: cache);

  List<File> files() {
    final d = Directory('${root.path}/card_images');
    if (!d.existsSync()) return [];
    return d.listSync().whereType<File>().toList();
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('elum_card_cache_');
    adapter = _Adapter();
    dio = Dio(BaseOptions(baseUrl: 'https://test.local'))..httpClientAdapter = adapter;
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<Uint8List?> fetch(CardImageRepository r, {String? path = 'k/a.png'}) =>
      r.fetch(routineId: 'r1', stepId: 's1', imagePath: path);

  group('디스크 히트·저장', () {
    test('E1 첫 로드는 받아서 저장하고, 두 번째는 네트워크 없이 디스크에서 준다', () async {
      adapter.body = png();
      final repo = newRepo(newCache());

      expect(await fetch(repo), png());
      expect(adapter.gets, 1);
      expect(files(), hasLength(1));

      // 같은 저장소를 새 캐시·새 저장소 객체로 열어도(=앱 재시작) 디스크에서 나온다
      final again = newRepo(newCache());
      expect(await fetch(again), png());
      expect(adapter.gets, 1);
    });

    test('E2 앱 재시작 시뮬레이션 — 새 ProviderContainer 도 디스크에서 읽는다', () async {
      adapter.body = jpeg();
      const key = (routineId: 'r1', stepId: 's1', imagePath: 'k/a.png');
      overrides() => [
            dioProvider.overrideWithValue(dio),
            cardImageDiskCacheProvider.overrideWithValue(newCache()),
          ];

      final first = ProviderContainer(overrides: overrides());
      expect(await first.read(cardImageProvider(key).future), jpeg());
      first.dispose();
      expect(adapter.gets, 1);

      final second = ProviderContainer(overrides: overrides());
      addTearDown(second.dispose);
      expect(await second.read(cardImageProvider(key).future), jpeg());
      expect(adapter.gets, 1, reason: '재시작 뒤에도 네트워크를 부르지 않는다');
    });

    test('E3 오프라인이어도 디스크에 있으면 보인다', () async {
      adapter.body = png();
      final cache = newCache();
      await fetch(newRepo(cache));

      adapter.offline = true;
      expect(await fetch(newRepo(newCache())), png());
    });

    test('E4 오프라인 + 캐시 없음은 null 이고 던지지 않는다', () async {
      adapter.offline = true;
      expect(await fetch(newRepo(newCache())), isNull);
      expect(files(), isEmpty);
    });

    test('E5 WebP·JPEG 도 저장된다', () async {
      final cache = newCache();
      await cache.write('a', webp());
      await cache.write('b', jpeg());
      expect(await cache.read('a'), webp());
      expect(await cache.read('b'), jpeg());
    });

    test('E6 imagePath 가 바뀌면 새로 받는다 (옛 파일은 그대로 두고 정리에 맡긴다)', () async {
      adapter.body = png();
      final repo = newRepo(newCache());
      await fetch(repo, path: 'k/a.png');
      adapter.body = png(1);
      expect(await fetch(repo, path: 'k/b.png'), png(1));
      expect(adapter.gets, 2);
      expect(files(), hasLength(2));
    });

    test('E7 imagePath 가 null·빈 값이면 디스크도 네트워크도 보지 않는다', () async {
      final repo = newRepo(newCache());
      expect(await fetch(repo, path: null), isNull);
      expect(await fetch(repo, path: ''), isNull);
      expect(adapter.gets, 0);
      expect(files(), isEmpty);
    });

    test('E8 경로 문자가 든 imagePath 도 폴더 밖으로 새지 않는다', () async {
      final cache = newCache();
      await cache.write('../../evil/../x.png', png());
      expect(files(), hasLength(1));
      expect(files().single.path.startsWith('${root.path}/card_images/'), isTrue);
    });
  });

  group('깨진 파일·저장 실패', () {
    test('E9 빈 파일·이미지가 아닌 파일은 버리고 다시 받는다', () async {
      adapter.body = png();
      final cache = newCache();
      await fetch(newRepo(cache)); // 저장
      final f = files().single;

      f.writeAsBytesSync([]); // 빈 파일
      expect(await fetch(newRepo(newCache())), png());
      expect(adapter.gets, 2);

      files().single.writeAsBytesSync([1, 2, 3, 4, 5, 6, 7, 8, 9]); // 형식이 다른 파일
      expect(await fetch(newRepo(newCache())), png());
      expect(adapter.gets, 3);
      expect(files().single.readAsBytesSync(), png(), reason: '온전한 그림으로 다시 저장된다');
    });

    test('E10 저장이 실패해도(폴더 자리에 파일) 받은 바이트는 화면에 간다', () async {
      // card_images 자리에 파일을 놓아 폴더를 만들 수 없게 한다 = 디스크 가득·권한 오류 대역
      File('${root.path}/card_images').writeAsStringSync('막힘');
      adapter.body = png();
      final repo = newRepo(newCache());
      expect(await fetch(repo), png());
      expect(adapter.gets, 1);
    });

    test('E11 저장 폴더를 못 찾아도(rootProvider 예외) 네트워크로 계속 보인다', () async {
      adapter.body = png();
      final cache = CardImageDiskCache(rootProvider: () async => throw StateError('no dir'));
      expect(await fetch(newRepo(cache)), png());
      expect(await cache.read('k/a.png'), isNull);
    });

    test('E12 쓰기 중에 남은 .tmp 는 읽히지 않고 다음 저장 때 치워진다', () async {
      final cache = newCache();
      await cache.write('a', png());
      File('${root.path}/card_images/deadbeef.tmp').writeAsBytesSync(png());
      await cache.write('b', png(1));
      expect(files().where((f) => f.path.endsWith('.tmp')), isEmpty);
      expect(await cache.read('a'), png());
    });

    test('E13 아주 큰 응답은 화면엔 주되 디스크엔 두지 않는다', () async {
      adapter.body = png(600);
      final repo = newRepo(newCache(maxEntry: 500));
      expect((await fetch(repo))!.length, png(600).length);
      expect(files(), isEmpty);
    });
  });

  group('용량 정리(LRU)', () {
    test('E14 파일 수 상한을 넘으면 마지막 접근이 오래된 것부터 지운다', () async {
      final cache = newCache(maxFiles: 2);
      await cache.write('a', png());
      await cache.write('b', png(1));
      // a 를 오래된 것으로, b 를 최근 것으로 못박는다(파일시스템 시각 해상도에 기대지 않는다)
      final all = files()..sort((x, y) => x.path.compareTo(y.path));
      for (final f in all) {
        f.setLastModifiedSync(DateTime(2020));
      }
      await cache.read('b'); // 읽으면 b 만 최근이 된다
      await cache.write('c', png(2));

      expect(await cache.read('a'), isNull, reason: '가장 오래된 a 가 밀려난다');
      expect(await cache.read('b'), isNotNull);
      expect(await cache.read('c'), isNotNull);
    });

    test('E15 총 용량 상한을 넘으면 오래된 것부터 지운다', () async {
      final size = png().length;
      final cache = newCache(maxBytes: size * 2 + 5);
      await cache.write('a', png());
      files().single.setLastModifiedSync(DateTime(2020));
      await cache.write('b', png());
      await cache.write('c', png());

      expect(await cache.read('a'), isNull);
      expect(files(), hasLength(2));
    });

    test('E16 옛 imagePath 파일도 결국 정리 대상이다 (그림을 바꿔 가며 써도 폴더가 무한히 크지 않는다)', () async {
      final cache = newCache(maxFiles: 3);
      for (var i = 0; i < 10; i++) {
        await cache.write('k/$i.png', png(i));
      }
      expect(files().length, lessThanOrEqualTo(3));
    });
  });

  group('실패는 보관하지 않는다', () {
    test('E17 실패 뒤 다시 접근하면 다시 시도하고, 성공하면 붙든다', () async {
      const key = (routineId: 'r1', stepId: 's1', imagePath: 'k/a.png');
      final container = ProviderContainer(overrides: [
        dioProvider.overrideWithValue(dio),
        cardImageDiskCacheProvider.overrideWithValue(newCache()),
      ]);
      addTearDown(container.dispose);

      adapter.offline = true;
      expect(await container.read(cardImageProvider(key).future), isNull);
      expect(adapter.gets, 1);

      // 화면이 사라졌다 다시 그려져 접근한다 — 이번엔 망이 돌아왔다.
      // (아무도 듣지 않는 실패 결과는 이벤트 루프 한 바퀴 뒤 버려진다)
      await Future<void>.delayed(Duration.zero);
      adapter.offline = false;
      adapter.body = png();
      expect(await container.read(cardImageProvider(key).future), png());
      expect(adapter.gets, 2);

      // 성공은 붙든다
      expect(await container.read(cardImageProvider(key).future), png());
      expect(adapter.gets, 2);
    });

    test('E18 실패는 정해진 간격이 오기 전에는 다시 부르지 않는다 (무한 루프 없음)', () async {
      const key = (routineId: 'r1', stepId: 's1', imagePath: 'k/a.png');
      final container = ProviderContainer(overrides: [
        dioProvider.overrideWithValue(dio),
        cardImageDiskCacheProvider.overrideWithValue(newCache()),
      ]);
      addTearDown(container.dispose);
      adapter.offline = true;
      final sub = container.listen(cardImageProvider(key), (_, _) {});
      await container.read(cardImageProvider(key).future);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(adapter.gets, 1);
      sub.close();
    });
  });

  group('동시 요청', () {
    test('E19 같은 imagePath 를 동시에 요청해도 받기·쓰기는 한 번이다', () async {
      adapter.body = png();
      adapter.delay = const Duration(milliseconds: 50);
      final repo = newRepo(newCache());

      final results = await Future.wait([for (var i = 0; i < 5; i++) fetch(repo)]);

      expect(results.every((b) => b != null), isTrue);
      expect(adapter.gets, 1);
      expect(files(), hasLength(1));
    });
  });

  group('개인정보 — 계정이 끝나면 지운다', () {
    test('E20 clear 는 폴더째 지우고, 뒤이어 다시 쓸 수 있다', () async {
      final cache = newCache();
      await cache.write('a', png());
      await cache.clear();
      expect(files(), isEmpty);
      expect(Directory('${root.path}/card_images').existsSync(), isFalse);
      await cache.write('a', png());
      expect(await cache.read('a'), png());
    });

    test('E21 지우기 전에 시작한 다운로드가 뒤늦게 저장해 되살아나지 않는다', () async {
      adapter.body = png();
      adapter.delay = const Duration(milliseconds: 50);
      final cache = newCache();
      final repo = newRepo(cache);

      final pending = fetch(repo); // 다운로드 중
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await cache.clear(); // 그 사이 로그아웃
      expect(await pending, png(), reason: '받던 그림은 화면에 준다');
      expect(files(), isEmpty, reason: '하지만 디스크에는 남지 않는다');
    });

    Future<(AuthRepository, InMemoryTokenStore)> authWith(CardImageDiskCache cache) async {
      final tokens = InMemoryTokenStore(accessToken: 'a', refreshToken: 'r');
      final authDio = Dio(BaseOptions(baseUrl: 'https://test.local'))
        ..httpClientAdapter = _Adapter();
      return (
        AuthRepository(
          dio: authDio,
          storage: InMemoryStorage(),
          tokens: tokens,
          sdk: _NoSdk(),
          imageCache: cache,
        ),
        tokens,
      );
    }

    test('E22 로그아웃하면 카드 그림 캐시가 전부 지워진다', () async {
      final cache = newCache();
      await cache.write('a', png());
      await cache.write('b', jpeg());
      final (auth, _) = await authWith(cache);

      await auth.logout();

      expect(files(), isEmpty);
    });

    test('E23 서버 로그아웃이 실패해도 캐시는 지워진다', () async {
      final cache = newCache();
      await cache.write('a', png());
      final tokens = InMemoryTokenStore(accessToken: 'a', refreshToken: 'r');
      final failing = Dio(BaseOptions(baseUrl: 'https://test.local'))
        ..httpClientAdapter = (_Adapter()..offline = true);
      final auth = AuthRepository(
        dio: failing,
        storage: InMemoryStorage(),
        tokens: tokens,
        sdk: _NoSdk(),
        imageCache: cache,
      );

      await auth.logout();
      expect(files(), isEmpty);
    });

    test('E24 회원 탈퇴가 성공하면 지워진다', () async {
      final cache = newCache();
      await cache.write('a', png());
      final (auth, _) = await authWith(cache);

      expect(await auth.deleteAccount(), isNull);
      expect(files(), isEmpty);
    });

    test('E25 회원 탈퇴가 서버에서 실패하면 계정이 그대로이므로 캐시도 남긴다', () async {
      final cache = newCache();
      await cache.write('a', png());
      final tokens = InMemoryTokenStore(accessToken: 'a', refreshToken: 'r');
      final failing = Dio(BaseOptions(baseUrl: 'https://test.local'))
        ..httpClientAdapter = (_Adapter()..offline = true);
      final auth = AuthRepository(
        dio: failing,
        storage: InMemoryStorage(),
        tokens: tokens,
        sdk: _NoSdk(),
        imageCache: cache,
      );

      expect(await auth.deleteAccount(), isNotNull);
      expect(files(), hasLength(1));
    });

    test('E26 authRepositoryProvider 가 앱과 같은 캐시 인스턴스를 물린다', () async {
      final cache = newCache();
      await cache.write('a', png());
      final container = ProviderContainer(overrides: [
        dioProvider.overrideWithValue(dio),
        cardImageDiskCacheProvider.overrideWithValue(cache),
        tokenStoreProvider.overrideWithValue(
            InMemoryTokenStore(accessToken: 'a', refreshToken: 'r')),
        localStorageProvider.overrideWithValue(InMemoryStorage()),
      ]);
      addTearDown(container.dispose);

      await container.read(authRepositoryProvider).logout();
      expect(files(), isEmpty);
    });
  });
}

class _NoSdk implements OAuthSdk {
  @override
  Future<OAuthSdkOutcome> signIn(OAuthProvider provider) async =>
      const OAuthSdkCancelled();
}

class _Adapter implements HttpClientAdapter {
  Uint8List body = Uint8List(0);
  bool offline = false;
  Duration delay = Duration.zero;
  int gets = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET') gets++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (offline) {
      throw DioException.connectionError(requestOptions: options, reason: 'offline');
    }
    if (options.path.contains('/image')) {
      return ResponseBody.fromBytes(body, 200,
          headers: {Headers.contentTypeHeader: ['image/png']});
    }
    return ResponseBody.fromString('{}', 200,
        headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

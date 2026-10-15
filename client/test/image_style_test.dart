import 'package:dio/dio.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/member/data/member_repository.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:elum/features/onboarding/domain/image_style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_dio.dart';
import 'package:elum/core/storage/in_memory_storage.dart';

/// 그림 방식(#458) — 도메인·저장·서버 계약.
///
/// 서버 계약(#457): enum `CARTOON`(기본) / `REALISTIC` / `PHOTO_ONLY`,
/// `PATCH /api/member/image-style` 본문 `{"imageStyle": "..."}`.
void main() {
  group('ImageStyle 서버 계약', () {
    test('apiValue 가 서버 enum name 과 일치한다', () {
      expect(ImageStyle.cartoon.apiValue, 'CARTOON');
      expect(ImageStyle.realistic.apiValue, 'REALISTIC');
      expect(ImageStyle.photoOnly.apiValue, 'PHOTO_ONLY');
    });

    // 순서가 화면 배치다 — 기본 그림(새 이룸이의 기본값)이 맨 위.



    // E1·E2 — 옛 서버(필드 없음)·새 값(모르는 값)이 와도 화면은 만화로 산다.

  });


  group('MemberRepository.updateImageStyle', () {
    late FakeAdapter adapter;

    MemberRepository repo(Map<String, Object?> routes) {
      adapter = FakeAdapter(routes);
      return MemberRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://test.local'))
          ..httpClientAdapter = adapter,
      );
    }

    test('PATCH /api/member/image-style 에 imageStyle 을 보낸다', () async {
      final r = repo({'PATCH /api/member/image-style': <String, Object?>{}});

      final failure = await r.updateImageStyle('REALISTIC');

      expect(failure, isNull);
      expect(adapter.calls, ['PATCH /api/member/image-style']);
      expect(adapter.sentBodies['PATCH /api/member/image-style'], {
        'imageStyle': 'REALISTIC',
      });
    });

    test('E3 서버가 거절해도 던지지 않고 실패를 돌려준다', () async {
      final r = repo({
        'PATCH /api/member/image-style': const FakeHttpError(500),
      });

      final failure = await r.updateImageStyle('REALISTIC');

      expect(failure, isA<AppFailure>());
    });

  });


  group('OnboardingNotifier — 그림 방식', () {
    late InMemoryStorage storage;
    late FakeAdapter adapter;

    ProviderContainer make(Map<String, Object?> routes) {
      adapter = FakeAdapter(routes);
      final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
        ..httpClientAdapter = adapter;
      final c = ProviderContainer(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
          memberRepositoryProvider.overrideWithValue(MemberRepository(dio: dio)),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() => storage = InMemoryStorage());

    // E13 — 기존 설치 앱을 올리면 로컬 값이 없다. 서버 기본값(CARTOON)과 맞춘다.





    // E3 — 서버 저장이 실패하면 이전 값으로 되돌리고, 실패 이유를 돌려준다.
    test('E3 서버가 실패하면 이전 값으로 되돌리고 실패를 돌려준다', () async {
      // 설정 화면은 온보딩을 마친 뒤에만 열린다 — 로컬 값 없는 기존 앱은 만화다
      await storage.setOnboardingCompleted(true);
      final c = make({
        'PATCH /api/member/image-style': const FakeHttpError(503),
      });

      final failure = await c
          .read(onboardingProvider.notifier)
          .changeImageStyle(ImageStyle.photoOnly);

      expect(failure, isNotNull);
      expect(c.read(onboardingProvider).imageStyle, ImageStyle.cartoon);
      expect(storage.imageStyle, ImageStyle.cartoon.apiValue);
    });

    // E19 — 온보딩이 끝날 때 함께 저장한다. 고르지 않으면 기본 그림이 저장된다.

  });

  group('OnboardingNotifier.complete — 입력 값 보존', () {
    late InMemoryStorage storage;
    late FakeAdapter adapter;

    ProviderContainer make(Map<String, Object?> routes) {
      adapter = FakeAdapter(routes);
      final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
        ..httpClientAdapter = adapter;
      final c = ProviderContainer(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
          memberRepositoryProvider.overrideWithValue(MemberRepository(dio: dio)),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() => storage = InMemoryStorage());

    // 저장하는 사이 서버 응답이 상태를 비워도 사용자가 입력한 값이 나가야 한다.
    // 아니면 "직접 찍은 사진"이 만화로 저장돼 AI 그림 비용이 나간다.
    test('저장 도중 상태가 비워져도 입력한 값을 서버로 보낸다', () async {
      final c = make({
        'PATCH /api/member/nickname': <String, Object?>{},
        'PATCH /api/member/support-goals': <String, Object?>{},
        'PATCH /api/member/character': <String, Object?>{},
        'PATCH /api/member/image-style': <String, Object?>{},
      });
      final n = c.read(onboardingProvider.notifier)
        ..setNickname('하늘이')
        ..setImageStyle(ImageStyle.photoOnly);

      final saving = n.complete();
      n.resetProfile(); // 저장이 도는 사이 서버의 빈 프로필이 상태를 덮은 상황
      await saving;

      expect(adapter.sentBodies['PATCH /api/member/nickname'], {
        'nickname': '하늘이',
      });
      expect(adapter.sentBodies['PATCH /api/member/image-style'], {
        'imageStyle': 'PHOTO_ONLY',
      });
      expect(storage.imageStyle, 'PHOTO_ONLY');
    });

    // 앞 저장이 실패해도 그림 방식은 반드시 시도한다 — 빠지면 서버가 만화로 둔다.
  });

}

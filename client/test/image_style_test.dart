import 'package:dio/dio.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/guardian/data/member_repository.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:elum/features/onboarding/domain/image_style.dart';
import 'package:elum/features/onboarding/domain/onboarding_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_dio.dart';

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

    // 순서가 화면 배치다 — 만화(기본)가 맨 위.
    test('enum 순서가 화면 배치(만화, 실사, 직접 사진)를 유지한다', () {
      expect(ImageStyle.values, [
        ImageStyle.cartoon,
        ImageStyle.realistic,
        ImageStyle.photoOnly,
      ]);
    });

    test('알려진 값은 그대로 되돌린다', () {
      for (final s in ImageStyle.values) {
        expect(ImageStyle.fromApiValue(s.apiValue), s);
      }
    });

    // E1·E2 — 옛 서버(필드 없음)·새 값(모르는 값)이 와도 화면은 만화로 산다.
    test('없거나 모르는 값이면 만화로 처리한다', () {
      expect(ImageStyle.fromApiValue(null), ImageStyle.cartoon);
      expect(ImageStyle.fromApiValue(''), ImageStyle.cartoon);
      expect(ImageStyle.fromApiValue('ANIME'), ImageStyle.cartoon);
      expect(ImageStyle.fromApiValue('realistic'), ImageStyle.cartoon);
    });

    test('화면 문구는 시안(임시) 그대로다', () {
      expect(ImageStyle.cartoon.label, '만화');
      expect(ImageStyle.realistic.label, '실사');
      expect(ImageStyle.photoOnly.label, '직접 사진');
      expect(ImageStyle.cartoon.description, '캐릭터가 나오는 그림이에요');
      expect(ImageStyle.realistic.description, '실제 물건 사진처럼 보여요');
      expect(
        ImageStyle.photoOnly.description,
        '그림은 직접 찍은 사진으로 넣어요. 글은 계속 만들어 드려요',
      );
    });
  });

  group('Member 파싱 — 그림 방식', () {
    test('imageStyle 을 읽는다', () {
      expect(
        Member.fromJson({'imageStyle': 'REALISTIC'}).imageStyle,
        ImageStyle.realistic,
      );
    });

    test('E1 필드가 없으면 만화다', () {
      expect(Member.fromJson({'nickname': '하늘이'}).imageStyle, ImageStyle.cartoon);
    });

    test('E2 모르는 값·다른 타입이어도 죽지 않고 만화다', () {
      expect(Member.fromJson({'imageStyle': 'ANIME'}).imageStyle, ImageStyle.cartoon);
      expect(Member.fromJson({'imageStyle': 7}).imageStyle, ImageStyle.cartoon);
      expect(Member.fromJson({'imageStyle': null}).imageStyle, ImageStyle.cartoon);
    });
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

    test('E4 서버에 닿지 못해도 던지지 않는다', () async {
      final r = repo({'PATCH /api/member/image-style': const FakeOffline()});

      expect(await r.updateImageStyle('PHOTO_ONLY'), isA<AppFailure>());
    });
  });

  group('로컬 저장', () {
    test('InMemoryStorage 는 그림 방식을 저장한다', () async {
      final s = InMemoryStorage();
      expect(s.imageStyle, isNull);

      await s.setImageStyle('PHOTO_ONLY');
      expect(s.imageStyle, 'PHOTO_ONLY');
    });

    // E11 — 계정을 바꾸면 이전 이룸이의 그림 방식이 남으면 안 된다.
    test('clearChildProfile·clearAll 이 그림 방식을 지운다', () async {
      final s = InMemoryStorage();
      await s.setImageStyle('REALISTIC');
      await s.clearChildProfile();
      expect(s.imageStyle, isNull);

      await s.setImageStyle('REALISTIC');
      await s.clearAll();
      expect(s.imageStyle, isNull);
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

    // E13 — 기존 설치 앱을 올리면 로컬 값이 없다.
    test('E13 로컬 값이 없으면 만화로 시작한다', () {
      final c = make({});
      expect(c.read(onboardingProvider).imageStyle, ImageStyle.cartoon);
    });

    test('저장된 값으로 시작하고, 모르는 값이면 만화다', () async {
      await storage.setImageStyle('PHOTO_ONLY');
      expect(make({}).read(onboardingProvider).imageStyle, ImageStyle.photoOnly);

      await storage.setImageStyle('ANIME');
      expect(make({}).read(onboardingProvider).imageStyle, ImageStyle.cartoon);
    });

    test('changeImageStyle 은 화면·로컬·서버에 모두 남긴다', () async {
      final c = make({'PATCH /api/member/image-style': <String, Object?>{}});

      final failure = await c
          .read(onboardingProvider.notifier)
          .changeImageStyle(ImageStyle.realistic);

      expect(failure, isNull);
      expect(c.read(onboardingProvider).imageStyle, ImageStyle.realistic);
      expect(storage.imageStyle, 'REALISTIC');
      expect(adapter.sentBodies['PATCH /api/member/image-style'], {
        'imageStyle': 'REALISTIC',
      });
    });

    // E3 — 서버 저장이 실패해도 로컬에는 남고, 실패 이유를 돌려준다.
    test('E3 서버가 실패해도 로컬에는 남고 실패를 돌려준다', () async {
      final c = make({
        'PATCH /api/member/image-style': const FakeHttpError(503),
      });

      final failure = await c
          .read(onboardingProvider.notifier)
          .changeImageStyle(ImageStyle.photoOnly);

      expect(failure, isNotNull);
      expect(c.read(onboardingProvider).imageStyle, ImageStyle.photoOnly);
      expect(storage.imageStyle, 'PHOTO_ONLY');
    });

    // E19 — 온보딩이 끝날 때 함께 저장한다. 건너뛰면 만화가 저장된다.
    test('complete 가 그림 방식도 로컬과 서버에 저장한다', () async {
      final c = make({
        'PATCH /api/member/nickname': <String, Object?>{},
        'PATCH /api/member/support-goals': <String, Object?>{},
        'PATCH /api/member/image-style': <String, Object?>{},
      });
      final n = c.read(onboardingProvider.notifier)
        ..setNickname('하늘이')
        ..setImageStyle(ImageStyle.realistic);

      final failure = await n.complete();

      expect(failure, isNull);
      expect(storage.imageStyle, 'REALISTIC');
      expect(adapter.sentBodies['PATCH /api/member/image-style'], {
        'imageStyle': 'REALISTIC',
      });
    });

    test('E19 complete 에서 그림 방식 저장만 실패해도 실패를 돌려준다', () async {
      final c = make({
        'PATCH /api/member/nickname': <String, Object?>{},
        'PATCH /api/member/support-goals': <String, Object?>{},
        'PATCH /api/member/image-style': const FakeHttpError(500),
      });

      final failure = await c.read(onboardingProvider.notifier).complete();

      expect(failure, isNotNull);
      expect(storage.imageStyle, 'CARTOON'); // 로컬에는 남았다
    });
  });

  test('OnboardingProfile 은 그림 방식을 몰라도 온보딩 완료 조건이 그대로다', () {
    // 그림 방식은 필수 입력이 아니다 — 건너뛰면 만화다.
    const profile = OnboardingProfile();
    expect(profile.imageStyle, ImageStyle.cartoon);
  });
}

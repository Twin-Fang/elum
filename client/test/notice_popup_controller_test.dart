import 'package:dio/dio.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/notice/application/notice_popup_controller.dart';
import 'package:elum/features/notice/data/notice_hide_store.dart';
import 'package:elum/features/notice/data/notice_repository.dart';
import 'package:elum/features/notice/domain/app_notice.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 무엇을 띄울지 정한다 (이슈 #371 · 명세 3-2).
///
/// - 보호자 홈이 **앱 실행 중 처음** 그려질 때 한 번만 서버에 묻는다
/// - 숨긴 것을 빼고 남은 것을 한 팝업의 슬라이드로 띄운다
/// - 체크하고 닫으면 그 팝업에 있던 것을 **전부** 숨긴다
void main() {
  final now = DateTime(2026, 9, 23, 10);

  AppNotice notice(String id, {int revision = 1}) =>
      AppNotice(id: id, revision: revision, title: '제목 $id', body: '본문');

  late InMemoryStorage storage;
  late _FakeRepo repo;

  NoticePopupController controller({NoticeSession? session}) =>
      NoticePopupController(
        repository: repo,
        storage: storage,
        session: session ?? NoticeSession(),
        now: () => now,
      );

  setUp(() {
    storage = InMemoryStorage(onboardingCompleted: true);
    repo = _FakeRepo();
  });

  test('N1 공지를 못 받으면(빈 목록) 띄울 것이 없다', () async {
    repo.feed = NoticeFeed.empty;

    expect(await controller().takeOnce(), isNull);
  });

  test('N9 여러 개면 숨기지 않은 것을 서버 순서대로 한 팝업에 담는다', () async {
    // 명세 2장 결정(2026-09-23) — 한 번에 하나씩 띄우지 않고 슬라이드로 넘긴다
    repo.feed = NoticeFeed(
      hideDays: 7,
      notices: [notice('a'), notice('b'), notice('c')],
    );

    final shown = await controller().takeOnce();

    expect(shown!.notices.map((n) => n.id), ['a', 'b', 'c']);
    expect(shown.hideDays, 7);
  });

  test('N26 일부만 숨긴 상태에서 새 공지가 오면 숨기지 않은 것만 담는다', () async {
    await NoticeHideStore(
      storage,
    ).hideAll([notice('old1'), notice('old2')], days: 7, now: now);
    repo.feed = NoticeFeed(
      hideDays: 7,
      notices: [notice('old1'), notice('new'), notice('old2'), notice('b')],
    );

    final shown = await controller().takeOnce();

    expect(shown!.notices.map((n) => n.id), ['new', 'b']);
  });

  test('전부 숨겼으면 띄우지 않는다', () async {
    await NoticeHideStore(storage).hideAll([notice('a')], days: 7, now: now);
    repo.feed = NoticeFeed(hideDays: 7, notices: [notice('a')]);

    expect(await controller().takeOnce(), isNull);
  });

  test('N7 숨긴 뒤 판이 오른 공지는 다시 담긴다', () async {
    await NoticeHideStore(storage).hideAll([notice('a')], days: 7, now: now);
    repo.feed = NoticeFeed(hideDays: 7, notices: [notice('a', revision: 2)]);

    final shown = await controller().takeOnce();

    expect(shown!.notices.single.revision, 2);
  });

  test('N10 이룸이 휴대폰이면 서버에 묻지도 않는다', () async {
    await storage.setElumiDevice(true);
    repo.feed = NoticeFeed(hideDays: 7, notices: [notice('a')]);

    expect(await controller().takeOnce(), isNull);
    expect(repo.calls, 0);
  });

  group('N11 한 실행에 한 번', () {
    test('두 번째 부름은 서버에 다시 묻지 않고 띄우지 않는다', () async {
      repo.feed = NoticeFeed(hideDays: 7, notices: [notice('a')]);
      final session = NoticeSession();

      expect(await controller(session: session).takeOnce(), isNotNull);
      expect(await controller(session: session).takeOnce(), isNull);
      expect(repo.calls, 1);
    });

    test('처음에 못 받았어도 이번 실행에서는 다시 묻지 않는다', () async {
      // 홈을 오갈 때마다 실패한 요청을 되풀이하면 오프라인에서 헛돈다
      repo.feed = NoticeFeed.empty;
      final session = NoticeSession();

      await controller(session: session).takeOnce();
      repo.feed = NoticeFeed(hideDays: 7, notices: [notice('a')]);

      expect(await controller(session: session).takeOnce(), isNull);
      expect(repo.calls, 1);
    });

    test('앱을 다시 켜면(새 ProviderScope) 다시 묻는다', () async {
      repo.feed = NoticeFeed(hideDays: 7, notices: [notice('a')]);
      ProviderContainer launch() {
        final c = ProviderContainer(
          overrides: [
            localStorageProvider.overrideWithValue(storage),
            noticeRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(c.dispose);
        return c;
      }

      final first = launch();
      expect(
        await first.read(noticePopupControllerProvider).takeOnce(),
        isNotNull,
      );
      expect(
        await first.read(noticePopupControllerProvider).takeOnce(),
        isNull,
      );

      final second = launch();
      expect(
        await second.read(noticePopupControllerProvider).takeOnce(),
        isNotNull,
      );
      expect(repo.calls, 2);
    });
  });

  test('N27 체크하고 닫으면 넘겨 보지 않은 슬라이드까지 전부 숨긴다', () async {
    repo.feed = NoticeFeed(
      hideDays: 3,
      notices: [notice('a'), notice('b'), notice('c')],
    );
    final shown = await controller().takeOnce();

    // 팝업에서 첫 장만 보고 체크한 뒤 닫았다
    await controller().hide(shown!);

    final hideStore = NoticeHideStore(storage);
    for (final id in ['a', 'b', 'c']) {
      expect(hideStore.isHidden(notice(id), now), isTrue, reason: id);
    }
    // 일수는 서버 설정(hideDays)을 따른다
    expect(
      hideStore.isHidden(notice('a'), now.add(const Duration(days: 3))),
      isFalse,
    );
    // 다음 실행에서는 아무것도 뜨지 않는다
    expect(await controller().takeOnce(), isNull);
  });

  test('지금 플랫폼으로 묻는다', () async {
    repo.feed = NoticeFeed.empty;
    await NoticePopupController(
      repository: repo,
      storage: storage,
      session: NoticeSession(),
      now: () => now,
      platform: () => NoticePlatform.ios,
    ).takeOnce();

    expect(repo.platforms, [NoticePlatform.ios]);
  });
}

class _FakeRepo extends NoticeRepository {
  _FakeRepo() : super(Dio());

  NoticeFeed feed = NoticeFeed.empty;
  int calls = 0;
  final platforms = <NoticePlatform>[];

  @override
  Future<NoticeFeed> fetch(NoticePlatform platform) async {
    calls++;
    platforms.add(platform);
    return feed;
  }
}

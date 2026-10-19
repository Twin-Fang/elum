import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:elum/features/notice/application/notice_popup_controller.dart';
import 'package:elum/features/notice/data/notice_hide_store.dart';
import 'package:elum/features/notice/data/notice_repository.dart';
import 'package:elum/features/notice/domain/app_notice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elum/core/storage/in_memory_storage.dart';

/// 무엇을 띄울지 정한다 (이슈 #371 · #390).
///
/// - 보호자 홈이 **앱 실행 중 처음** 그려질 때 한 번만 서버에 묻는다
/// - 숨긴 것을 빼고 남은 것을 서버 순서대로 **차례로** 띄운다 (#390)
/// - `보지 않기` 는 **공지마다** 따로 숨긴다 (#390)
/// - 무엇을 받았고 무엇을 건너뛰었는지 원문 없이 남긴다 (#385 D)
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

  test('N10 이룸이 기기가면 서버에 묻지도 않는다', () async {
    await storage.setElumiDevice(true);
    repo.feed = NoticeFeed(hideDays: 7, notices: [notice('a')]);

    expect(await controller().takeOnce(), isNull);
    expect(repo.calls, 0);
  });


  test('R3 보지 않기는 공지마다 — 둘째만 숨기면 다음 실행에 첫째·셋째만 뜬다', () async {
    // #371 은 체크박스 하나로 팝업의 공지를 전부 숨겼다(N27). 이제 공지마다 팝업이 따로다.
    repo.feed = NoticeFeed(
      hideDays: 3,
      notices: [notice('a'), notice('b'), notice('c')],
    );
    final shown = await controller().takeOnce();
    await controller().hide(shown!.notices[1], shown.hideDays);

    final hideStore = NoticeHideStore(storage);
    expect(hideStore.isHidden(notice('a'), now), isFalse);
    expect(hideStore.isHidden(notice('b'), now), isTrue);
    expect(hideStore.isHidden(notice('c'), now), isFalse);
    // 일수는 서버 설정(hideDays)을 따른다
    expect(
      hideStore.isHidden(notice('b'), now.add(const Duration(days: 3))),
      isFalse,
    );
    expect((await controller().takeOnce())!.notices.map((n) => n.id), [
      'a',
      'c',
    ]);
  });

  group('#385 D 로그 — 원문 없이 id·판·동작만', () {
    late List<String> lines;
    late DebugPrintCallback original;

    setUp(() {
      lines = [];
      original = debugPrint;
      debugPrint = (message, {wrapWidth}) => lines.add(message ?? '');
    });
    tearDown(() => debugPrint = original);

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

import 'dart:convert';

import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/notice/data/notice_hide_store.dart';
import 'package:elum/features/notice/domain/app_notice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "보지 않기" 기록 (이슈 #371 · 명세 3-2).
///
/// 기기에 `notice.hidden.{id}` = `{revision, until}` 을 둔다. 같은 판이고 기한이
/// 안 지났으면 숨긴다. 판이 다르면 관리자가 "다시 보이게"로 고친 것이므로 다시 뜬다.
void main() {
  final now = DateTime(2026, 9, 23, 10);

  AppNotice notice(String id, {int revision = 1}) =>
      AppNotice(id: id, revision: revision, title: '제목', body: '본문');

  late InMemoryStorage storage;
  late NoticeHideStore store;

  setUp(() {
    storage = InMemoryStorage();
    store = NoticeHideStore(storage);
  });

  test('숨긴 적 없으면 보인다', () {
    expect(store.isHidden(notice('a'), now), isFalse);
  });

  test('숨기면 기한 안에서는 안 보인다', () async {
    await store.hideAll([notice('a')], days: 7, now: now);

    expect(store.isHidden(notice('a'), now), isTrue);
    expect(
      store.isHidden(notice('a'), now.add(const Duration(days: 6, hours: 23))),
      isTrue,
    );
  });

  test('기한이 지나면 다시 보인다', () async {
    await store.hideAll([notice('a')], days: 7, now: now);

    expect(
      store.isHidden(notice('a'), now.add(const Duration(days: 7))),
      isFalse,
    );
  });

  test('일수는 서버 설정을 따른다', () async {
    await store.hideAll([notice('a')], days: 3, now: now);

    expect(
      store.isHidden(notice('a'), now.add(const Duration(days: 2))),
      isTrue,
    );
    expect(
      store.isHidden(notice('a'), now.add(const Duration(days: 3))),
      isFalse,
    );
  });

  test('N7 숨긴 뒤 관리자가 "다시 보이게"로 고치면(판이 오르면) 다시 뜬다', () async {
    await store.hideAll([notice('a', revision: 1)], days: 7, now: now);

    expect(store.isHidden(notice('a', revision: 2), now), isFalse);
  });

  test('N8 숨긴 뒤 오타만 고치면(판이 그대로면) 안 뜬다', () async {
    await store.hideAll([notice('a', revision: 4)], days: 7, now: now);

    // 제목·본문이 바뀌어도 판이 같으면 같은 공지다
    final fixed = AppNotice(
      id: 'a',
      revision: 4,
      title: '고친 제목',
      body: '고친 본문',
    );
    expect(store.isHidden(fixed, now), isTrue);
  });

  test('다른 공지는 건드리지 않는다', () async {
    await store.hideAll([notice('a')], days: 7, now: now);

    expect(store.isHidden(notice('b'), now), isFalse);
  });

  test('기록이 깨져 있으면 다시 보여준다 — 예외 없이', () async {
    // 한 번 더 보이는 것은 해가 없다. 깨진 기록 때문에 홈이 죽는 쪽이 나쁘다.
    for (final broken in [
      '{',
      '[]',
      '"문자열"',
      jsonEncode({'revision': '1', 'until': 0}),
      jsonEncode({'revision': 1}),
    ]) {
      await storage.setNoticeHiddenJson('a', broken);
      expect(() => store.isHidden(notice('a'), now), returnsNormally);
      expect(store.isHidden(notice('a'), now), isFalse, reason: broken);
    }
  });

  test('저장이 실패해도 예외를 올리지 않는다 — 다음 실행에 한 번 더 뜰 뿐이다', () async {
    final failing = NoticeHideStore(_FailingStorage());
    await expectLater(
      failing.hideAll([notice('a')], days: 7, now: now),
      completes,
    );
  });

  group('로그아웃해도 남는다 — 공지 숨김은 계정이 아니라 휴대폰 기준', () {
    test('InMemoryStorage', () async {
      await store.hideAll([notice('a')], days: 7, now: now);

      await storage.clearAll();
      await storage.clearChildProfile();

      expect(store.isHidden(notice('a'), now), isTrue);
    });

    test('SharedPrefsStorage — 키는 notice.hidden.{id}', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final real = SharedPrefsStorage(prefs);
      final realStore = NoticeHideStore(real);

      await realStore.hideAll([notice('abc', revision: 2)], days: 7, now: now);
      final saved = prefs.getString('notice.hidden.abc');
      expect(saved, isNotNull);
      expect(jsonDecode(saved!), {
        'revision': 2,
        'until': now.add(const Duration(days: 7)).millisecondsSinceEpoch,
      });

      await real.clearAll();
      await real.clearChildProfile();

      expect(prefs.getString('notice.hidden.abc'), isNotNull);
      expect(realStore.isHidden(notice('abc', revision: 2), now), isTrue);
    });
  });
}

class _FailingStorage extends InMemoryStorage {
  @override
  Future<void> setNoticeHiddenJson(String noticeId, String json) async {
    throw StateError('디스크가 가득 찼다');
  }
}

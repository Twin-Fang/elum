import 'dart:convert';

import '../../../core/logger/app_logger.dart';
import '../../../core/storage/local_storage.dart';
import '../domain/app_notice.dart';

/// 공지 "보지 않기" 기록 (이슈 #371 · 명세 3-2).
///
/// 공지마다 `{revision, until(ms)}` 를 휴대폰에 둔다. 서버는 숨김을 모른다 —
/// 숨김은 이 휴대폰에서 본 것에 대한 것이라 서버가 거를 수 없다.
///
/// 기한은 **휴대폰 시계**로 잰다(N5). 게시 기간은 서버가 판단하므로 시계가
/// 틀려도 끝난 공지가 뜨지는 않는다 — 숨김이 조금 일찍·늦게 풀릴 뿐이다.
class NoticeHideStore {
  NoticeHideStore(this._storage);

  final LocalStorage _storage;

  static const _kRevision = 'revision';
  static const _kUntil = 'until';

  /// 같은 판이고 기한 전이면 숨긴다.
  ///
  /// 판이 다르면 관리자가 "다시 보이게"로 고친 것이다(N7). 오타만 고쳤으면
  /// 판이 그대로라 계속 숨는다(N8).
  ///
  /// 기록이 깨졌으면 **보여준다.** 한 번 더 보이는 것은 해가 없다.
  bool isHidden(AppNotice notice, DateTime now) {
    final raw = _storage.getNoticeHiddenJson(notice.id);
    if (raw == null) return false;
    try {
      final record = jsonDecode(raw);
      if (record is! Map) return false;
      final revision = record[_kRevision];
      final until = record[_kUntil];
      if (revision is! int || until is! int) return false;
      return revision == notice.revision && now.millisecondsSinceEpoch < until;
    } catch (e) {
      AppLogger.error('notice', e, null, {
        'step': 'readHidden',
        'id': notice.id,
      });
      return false;
    }
  }

  /// [notice] 하나를 [days] 동안 숨긴다.
  ///
  /// **공지마다 따로 숨긴다** (#390). 공지가 여러 개면 하나씩 차례로 뜨고, 각 팝업에
  /// 제 `보지 않기`가 있다. 둘째에서만 체크했으면 둘째만 숨는다.
  ///
  /// 저장이 실패해도 올리지 않는다 — 다음 실행에 한 번 더 뜰 뿐이고, 그것 때문에
  /// 홈이 멈추면 안 된다. 로그는 남긴다.
  Future<void> hide(
    AppNotice notice, {
    required int days,
    required DateTime now,
  }) async {
    final until = now.add(Duration(days: days)).millisecondsSinceEpoch;
    try {
      await _storage.setNoticeHiddenJson(
        notice.id,
        jsonEncode({_kRevision: notice.revision, _kUntil: until}),
      );
    } catch (e, st) {
      AppLogger.error('notice', e, st, {'step': 'saveHidden', 'id': notice.id});
    }
  }
}

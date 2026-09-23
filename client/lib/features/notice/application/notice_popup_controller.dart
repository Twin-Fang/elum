import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../data/notice_hide_store.dart';
import '../data/notice_repository.dart';
import '../domain/app_notice.dart';
import 'notice_log.dart';

/// 이번 실행에서 공지를 이미 물었는가.
///
/// **프로세스 단위다.** 앱의 [ProviderScope] 는 `main` 에서 한 번만 만들어지므로
/// 이 객체도 앱이 떠 있는 동안 하나다. 설정에 갔다 오거나 일과를 만들다 홈으로
/// 돌아올 때마다 뜨면 방해다(N11). 정적 변수로 두지 않는 이유는 테스트끼리
/// 값이 새지 않게 하려는 것이다.
class NoticeSession {
  bool attempted = false;
}

final noticeSessionProvider = Provider<NoticeSession>((ref) => NoticeSession());

/// 무엇을 띄울지 정한다 (이슈 #371 · #390).
class NoticePopupController {
  NoticePopupController({
    required NoticeRepository repository,
    required LocalStorage storage,
    required NoticeSession session,
    DateTime Function()? now,
    NoticePlatform Function()? platform,
  }) : _repository = repository,
       _storage = storage,
       _session = session,
       _hideStore = NoticeHideStore(storage),
       _now = now ?? DateTime.now,
       _platform = platform ?? (() => NoticePlatform.current);

  final NoticeRepository _repository;
  final LocalStorage _storage;
  final NoticeSession _session;
  final NoticeHideStore _hideStore;
  final DateTime Function() _now;
  final NoticePlatform Function() _platform;

  /// 이번 실행에서 처음이면 공지를 받아 **숨기지 않은 것만** 서버 순서대로 돌려준다.
  /// 띄울 것이 없으면 null.
  ///
  /// 표시를 **묻기 전에** 해 둔다. 응답을 기다리는 사이 홈을 다시 그리거나,
  /// 못 받았을 때(N1) 홈을 오갈 때마다 요청을 되풀이하면 안 된다.
  Future<NoticeFeed?> takeOnce() async {
    if (_session.attempted) return null;
    _session.attempted = true;

    // 보호자 홈에서만 뜬다(N10). 라우터가 이룸이 휴대폰을 보호자 홈으로 보내지는
    // 않지만, 길이 하나 새로 생겨도 이룸이 화면에 공지가 뜨지 않게 여기서 한 번 더 막는다.
    if (_storage.isElumiDevice) {
      NoticeLog.event('skip', {'why': 'elumiDevice'});
      return null;
    }

    final feed = await _repository.fetch(_platform());
    // 못 받았을 때(N1)는 저장소가 이미 에러 로그를 남겼다. 여기서는 받은 것을 적는다 —
    // 0 이면 "서버가 안 줬다", 숫자가 있는데 안 떴으면 아래 숨김을 본다.
    NoticeLog.event('fetched', {
      'count': feed.notices.length,
      'notices': NoticeLog.refs(feed.notices),
    });

    final now = _now();
    final visible = <AppNotice>[];
    for (final notice in feed.notices) {
      if (_hideStore.isHidden(notice, now)) {
        NoticeLog.event('skipHidden', {'notice': NoticeLog.ref(notice)});
      } else {
        visible.add(notice);
      }
    }
    if (visible.isEmpty) return null;
    return NoticeFeed(hideDays: feed.hideDays, notices: visible);
  }

  /// [notice] 하나를 [days] 동안 숨긴다 — `보지 않기`는 공지마다 따로다 (#390).
  Future<void> hide(AppNotice notice, int days) =>
      _hideStore.hide(notice, days: days, now: _now());
}

final noticePopupControllerProvider = Provider<NoticePopupController>(
  (ref) => NoticePopupController(
    repository: ref.watch(noticeRepositoryProvider),
    storage: ref.watch(localStorageProvider),
    session: ref.watch(noticeSessionProvider),
  ),
);

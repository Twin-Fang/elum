import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../data/notice_hide_store.dart';
import '../data/notice_repository.dart';
import '../domain/app_notice.dart';

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

/// 무엇을 띄울지 정한다 (이슈 #371 · 명세 3-2).
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

  /// 이번 실행에서 처음이면 공지를 받아 **숨기지 않은 것만** 돌려준다.
  /// 띄울 것이 없으면 null.
  ///
  /// 표시를 **묻기 전에** 해 둔다. 응답을 기다리는 사이 홈을 다시 그리거나,
  /// 못 받았을 때(N1) 홈을 오갈 때마다 요청을 되풀이하면 안 된다.
  Future<NoticeFeed?> takeOnce() async {
    if (_session.attempted) return null;
    _session.attempted = true;

    // 보호자 홈에서만 뜬다(N10). 라우터가 이룸이 휴대폰을 보호자 홈으로 보내지는
    // 않지만, 길이 하나 새로 생겨도 이룸이 화면에 공지가 뜨지 않게 여기서 한 번 더 막는다.
    if (_storage.isElumiDevice) return null;

    final feed = await _repository.fetch(_platform());
    final now = _now();
    final visible = [
      for (final notice in feed.notices)
        if (!_hideStore.isHidden(notice, now)) notice,
    ];
    if (visible.isEmpty) return null;
    return NoticeFeed(hideDays: feed.hideDays, notices: visible);
  }

  /// 팝업에 있던 공지를 **전부** 숨긴다(N27). 체크박스는 팝업 하나에 하나다.
  Future<void> hide(NoticeFeed shown) =>
      _hideStore.hideAll(shown.notices, days: shown.hideDays, now: _now());
}

final noticePopupControllerProvider = Provider<NoticePopupController>(
  (ref) => NoticePopupController(
    repository: ref.watch(noticeRepositoryProvider),
    storage: ref.watch(localStorageProvider),
    session: ref.watch(noticeSessionProvider),
  ),
);

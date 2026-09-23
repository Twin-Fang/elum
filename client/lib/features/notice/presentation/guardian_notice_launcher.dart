import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../application/notice_log.dart';
import '../application/notice_popup_controller.dart';
import 'notice_popup.dart';

/// 보호자 홈을 감싸 공지 팝업을 띄운다 (이슈 #371 · #390).
///
/// **라우터의 보호자 홈 자리에서만 감싼다.** 이룸이 화면·로그인 전·일과 만들기
/// 흐름에는 이 위젯이 없으므로 공지가 뜰 길이 없다 (명세 2장 "어디에 뜨나").
/// 홈 화면 안에 넣지 않은 이유 — 홈을 따로 세우는 테스트·시안 대조가 여럿인데,
/// 그 안에 넣으면 전부 실제 서버를 부르게 된다.
///
/// 홈의 **첫 프레임 뒤에** 묻는다. 공지를 기다리느라 홈이 늦게 뜨면 안 된다.
///
/// 공지가 여럿이면 **차례로** 띄운다 (#390). 하나를 닫으면(닫기·링크·바깥) 다음이
/// 이어서 뜬다. 한 팝업 안에서 넘기던 슬라이드(#371)를 없앴다 — 앱의 다른 팝업과
/// 같은 모양이 되면서 넘길 자리가 없어졌고, `보지 않기`도 공지마다 따로 고를 수 있다.
class GuardianNoticeLauncher extends ConsumerStatefulWidget {
  const GuardianNoticeLauncher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<GuardianNoticeLauncher> createState() =>
      _GuardianNoticeLauncherState();
}

class _GuardianNoticeLauncherState
    extends ConsumerState<GuardianNoticeLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  Future<void> _maybeShow() async {
    if (!mounted) return;
    final controller = ref.read(noticePopupControllerProvider);
    try {
      final feed = await controller.takeOnce();
      if (feed == null) return;

      final total = feed.notices.length;
      for (final (i, notice) in feed.notices.indexed) {
        if (!mounted) return;
        // 기다리는 사이(첫 공지는 응답을, 다음 공지는 앞 팝업이 닫히기를) 일과 만들기·
        // 설정으로 넘어갔거나 다른 팝업이 떠 있으면 그 위에 띄우지 않는다(N11).
        // 이번 실행 몫은 이미 썼으니 남은 공지는 다음 실행에 다시 뜬다.
        if (ModalRoute.of(context)?.isCurrent == false) {
          NoticeLog.event('skip', {
            'why': 'homeNotInFront',
            'left': NoticeLog.refs(feed.notices.skip(i)),
          });
          return;
        }

        NoticeLog.event('show', {
          'notice': NoticeLog.ref(notice),
          'order': '${i + 1}/$total',
        });
        final result = await showNoticePopup(
          context,
          notice,
          hideDays: feed.hideDays,
        );
        NoticeLog.event('closed', {
          'notice': NoticeLog.ref(notice),
          'how': result.how.name,
          'hide': result.hide,
        });
        // 보지 않기는 **공지마다** 따로다 — 이 공지만 숨긴다
        if (result.hide) await controller.hide(notice, feed.hideDays);
      }
    } catch (e, st) {
      // 공지는 부가 기능이다. 무엇이 터져도 홈은 그대로 둔다 — 대신 흔적은 남긴다.
      AppLogger.error('notice', e, st, {'step': 'launch'});
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

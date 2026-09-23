import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/text/keep_words.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../domain/app_notice.dart';
import 'show_notice_popup.dart';
import 'widgets/notice_controls.dart';
import 'widgets/notice_slide.dart';

// 띄우기·링크 열기는 옆 파일에 두고 여기서 함께 내보낸다 — 부르는 쪽은 이 파일 하나만 안다.
export 'show_notice_popup.dart';
export 'widgets/notice_slide.dart' show NoticeImageResolver;

/// 공지 팝업 — 공지 **한 건** (이슈 #390 · 시안 `팝업` 931:4878 의 `방침` 변형 1090:4922).
///
/// 앱의 다른 팝업(로그아웃·회원탈퇴·일과 삭제)과 **같은 컴포넌트**다. 카드·버튼은
/// [ElumDialogSurface]·[ElumDialogButton] 을 그대로 쓴다. #371 은 참고로 받은 웹 공지
/// 모달(위 그림, 오른쪽 위 ✕, 위쪽 체크박스, 슬라이드)을 따라 그려 앱 안에서 혼자 달랐다.
///
/// ```
/// ┌────────────────────────────┐  카드 322 · 모서리 20 · 여백 24 14 14
/// │  [ 그림 16:10 ]             │  ← 시안 밖(임시). 그림 있는 공지만. 못 받으면 자리째 없다
/// │     개인정보처리방침이        │  제목 18/500 · **강조** 민트
/// │     9월 30일에 바뀌어요       │
/// │  카드 그림을 만드는 업체가 …  │  본문 16/400 — 길면 글 자리만 스크롤
/// │      ◯✓ 일주일간 보지 않기     │  공지마다 따로
/// │ [   닫기   ][  방침 보기  ]  │  링크 없으면 [      닫기      ] 하나
/// └────────────────────────────┘
/// ```
///
/// 여러 공지는 이 팝업을 **차례로** 띄운다 — 한 팝업 안에서 넘기지 않는다
/// ([GuardianNoticeLauncher]).
class NoticePopupCard extends StatefulWidget {
  const NoticePopupCard({
    super.key,
    required this.notice,
    required this.hideDays,
    required this.hideChecked,
    required this.onClose,
    required this.onLinkOpened,
    required this.openLink,
    required this.imageFor,
  });

  final AppNotice notice;

  /// `보지 않기` 일수. 7 이면 "일주일간", 아니면 "N일간".
  final int hideDays;

  /// "보지 않기" 체크 상태. 팝업을 띄운 쪽이 닫힌 뒤에 읽는다 — 바깥을 눌러 닫혀도
  /// 값이 남게 팝업 밖에 둔다.
  final ValueNotifier<bool> hideChecked;

  /// `닫기` 를 눌렀다.
  final VoidCallback onClose;

  /// 링크를 열었다. 공통 팝업처럼 버튼을 누르면 팝업이 닫힌다.
  final VoidCallback onLinkOpened;
  final NoticeLinkOpener openLink;
  final NoticeImageResolver imageFor;

  static const cardKey = ValueKey('notice-card');
  static const closeKey = ValueKey('notice-close');

  /// 링크를 열지 못했을 때 보이는 에러 코드 — 제보를 받았을 때 링크 열기에서 터졌다는 것을 가린다.
  static const linkFailureCode = 'E-NOTICE-LINK';

  @override
  State<NoticePopupCard> createState() => _NoticePopupCardState();
}

class _NoticePopupCardState extends State<NoticePopupCard> {
  /// 카드 최대 높이 — 화면의 75%. 긴 공지도 화면을 꽉 채우지 않아 뒤에 홈이 보이고,
  /// 그 안에서 글 자리만 스크롤된다(N4). 누를 것(보지 않기·버튼)은 스크롤 밖이라 늘 보인다.
  static const _maxHeightRatio = 0.75;

  /// 화면 끝(안전영역)과 카드 사이 최소 거리.
  static const _screenMargin = 24.0;

  /// 시안 — 본문↔보지 않기 24 · 보지 않기↔버튼 14. 보지 않기의 누름 영역(44)이 보이는
  /// 줄(16)보다 위아래로 14 씩 넓으므로 그만큼 뺀다. 그래야 보이는 간격이 시안과 같다.
  static const _bodyToHide = 24.0;
  static const _hideToActions = 14.0;
  static const _hideReach = (noticeTapTarget - NoticeHideToggle.checkSize) / 2;

  /// 누를 것만 글자 확대를 2배에서 멈춘다. 그 이상이면 버튼 문구가 한 글자씩 꺾여
  /// 버튼이 카드를 밀어낸다. 제목·본문은 끝까지 키운다 — 스크롤되니까.
  static const _controlsMaxScale = 2.0;

  final _scroll = ScrollController();
  bool _imageFailed = false;
  bool _linkFailed = false;
  bool _opening = false;

  AppNotice get _notice => widget.notice;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onImageError(Object error) {
    if (_imageFailed) return;
    AppLogger.error('notice', error, null, {'step': 'image', 'id': _notice.id});
    // errorBuilder 는 그리는 중에 불린다 — 그 자리에서 setState 하면 안 된다
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _imageFailed = true);
    });
  }

  Future<void> _open() async {
    final button = _notice.button;
    // 빨리 두 번 눌러도 브라우저는 한 번만 연다
    if (button == null || _opening) return;
    _opening = true;
    final opened = await widget.openLink(button.url);
    _opening = false;
    if (!mounted) return;
    if (opened) {
      widget.onLinkOpened();
      return;
    }
    // 못 열었으면 닫지 않는다 — 닫히면 보호자는 무엇이 안 됐는지 모른다
    AppLogger.error('notice', 'link not opened', null, {
      'id': _notice.id,
      'code': NoticePopupCard.linkFailureCode,
    });
    setState(() => _linkFailed = true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final media = MediaQuery.of(context);
    final maxHeight = math.min(
      media.size.height * _maxHeightRatio,
      media.size.height - media.padding.vertical - _screenMargin * 2,
    );
    final showImage = _notice.imageUrl != null && !_imageFailed;
    final side = ElumDialogSurface.padSide.w;
    final button = _notice.button;

    final controls = MediaQuery.withClampedTextScaling(
      maxScaleFactor: _controlsMaxScale,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: math.max(0, _bodyToHide.h - _hideReach)),
          ValueListenableBuilder<bool>(
            valueListenable: widget.hideChecked,
            builder: (context, checked, _) => Center(
              child: NoticeHideToggle(
                label: noticeHideLabel(widget.hideDays),
                checked: checked,
                onChanged: (v) => widget.hideChecked.value = v,
              ),
            ),
          ),
          SizedBox(height: math.max(0, _hideToActions.h - _hideReach)),
          if (_linkFailed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '링크를 열지 못했어요 (${NoticePopupCard.linkFailureCode})',
                textAlign: TextAlign.center,
                style: context.typo.noticeHideLabel.copyWith(
                  color: colors.noticeHideLabel,
                ),
              ),
            ),
          // 링크가 없으면 `닫기` 하나를 꽉 채운다 — 공통 팝업 info·로그인 실패 변형처럼
          // 혼자 선 버튼은 주 동작 색이다. 회색 버튼이 혼자 서면 눌리지 않는 버튼으로 읽힌다.
          ElumDialogButtonRow(
            children: [
              ElumDialogButton(
                key: NoticePopupCard.closeKey,
                label: '닫기',
                tone: button == null
                    ? ElumDialogTone.primary
                    : ElumDialogTone.neutral,
                onTap: widget.onClose,
              ),
              if (button != null)
                ElumDialogButton(
                  key: ValueKey('notice-link-${_notice.id}'),
                  // 관리자가 쓴 문구라 길 수 있다(최대 20자). 말줄임 없이 어절에서 꺾는다 (R2)
                  label: keepWords(button.label),
                  semanticsLabel: button.label,
                  centerLines: true,
                  onTap: _open,
                ),
            ],
          ),
        ],
      ),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ElumDialogSurface(
          key: NoticePopupCard.cardKey,
          // 그림이 맨 위면 옆·아래와 같은 14 — 버튼 줄이 아래 가장자리에서 14 인 것과 같게
          padTop: showImage
              ? ElumDialogSurface.padSide
              : ElumDialogSurface.defaultPadTop,
          // 좌우 14 는 안에서 준다 — 긴 공지의 스크롤 막대가 글자를 덮지 않고 여백에 서게.
          padSides: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 제목까지 글 자리에 넣는다. 글꼴 2.0 · 360 폭에서 40자 제목이 여러 줄이 되면
              // 제목을 고정한 채로는 버튼이 카드 밖으로 밀린다(#371 에서 겪었다). 짧으면
              // 스크롤이 생기지 않아 본문만 스크롤되는 것과 똑같이 보인다.
              Flexible(
                child: Scrollbar(
                  controller: _scroll,
                  // 50대 보호자는 밀면 더 있다는 것을 모를 수 있다. 넘칠 때만 막대가 보인다.
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    key: ValueKey('notice-scroll-${_notice.id}'),
                    controller: _scroll,
                    padding: EdgeInsets.symmetric(horizontal: side),
                    child: NoticeContent(
                      notice: _notice,
                      showImage: showImage,
                      imageFor: widget.imageFor,
                      onImageError: _onImageError,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: side),
                child: controls,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

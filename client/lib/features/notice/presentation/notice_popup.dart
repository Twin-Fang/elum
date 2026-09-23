import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../domain/app_notice.dart';
import 'show_notice_popup.dart';
import 'widgets/notice_controls.dart';
import 'widgets/notice_slide.dart';

// 띄우기·링크 열기는 옆 파일에 두고 여기서 함께 내보낸다 — 부르는 쪽은 이 파일 하나만 안다.
export 'show_notice_popup.dart';
export 'widgets/notice_slide.dart' show NoticeImageResolver;

/// 공지 팝업 본체 (명세 2-1). 골든·테스트에서 직접 세울 수 있게 공개한다.
///
/// ```
/// ┌──────────────────────────────┐  카드: 화면 폭 90%(최대 360), 모서리 20
/// │         ☐ 일주일간 보지 않기 ✕ │  그림 위에 얹는다
/// │         [ 그림 16:10 ]        │  그림이 한 장도 없으면 자리가 없다
/// │  제목 **강조**  /  본문        │  길면 이 자리만 스크롤 (화면의 45%)
/// │         [ 버튼 ]              │
/// │   ←      ● ○ ○      →        │  한 장이면 숨긴다
/// └──────────────────────────────┘
/// ```
class NoticePopupCard extends StatefulWidget {
  const NoticePopupCard({
    super.key,
    required this.feed,
    required this.hideChecked,
    required this.onClose,
    required this.openLink,
    required this.imageFor,
  });

  final NoticeFeed feed;

  /// "보지 않기" 체크 상태. 팝업을 띄운 쪽이 닫힌 뒤에 읽는다.
  final ValueNotifier<bool> hideChecked;
  final VoidCallback onClose;
  final NoticeLinkOpener openLink;
  final NoticeImageResolver imageFor;

  static const cardKey = ValueKey('notice-card');
  static const pagesKey = ValueKey('notice-pages');
  static const dotsKey = ValueKey('notice-dots');

  @override
  State<NoticePopupCard> createState() => _NoticePopupCardState();
}

class _NoticePopupCardState extends State<NoticePopupCard> {
  static const _widthRatio = 0.9;
  static const _maxWidth = 360.0;
  static const _radius = 20.0;

  /// 카드 위아래로 화면 끝에서 떨어질 거리. 긴 공지도 화면을 꽉 채우지 않는다.
  static const _screenMargin = 24.0;

  /// 글 자리 최대 높이 — 화면의 45% (N4).
  static const _textMaxRatio = 0.45;

  /// 오른쪽 위 조작부만 글자 확대를 2.0배에서 멈춘다. 2.0(안드로이드 최대)까지는
  /// 360 화면에서도 `일주일간 보지 않기`가 ✕ 와 한 줄에 들어간다 — 테스트로 고정했다.
  /// iOS 손쉬운 사용의 더 큰 글자(3배 안팎)에서는 "일주일간 보…"로 잘려 무엇을
  /// 체크하는지 읽을 수 없어 여기서 멈춘다. 제목·본문은 끝까지 키운다.
  static const _controlsMaxScale = 2.0;
  static const _controlsInset = 4.0;
  static const _navBottom = 4.0;

  final _pages = PageController();
  int _index = 0;
  bool _precached = false;
  final Set<String> _failedImages = {};
  String? _linkFailedId;
  bool _opening = false;

  List<AppNotice> get _notices => widget.feed.notices;

  /// 그림 자리는 카드 단위다 — 불러올 수 있는 그림이 한 장이라도 있으면 모든 장에 둔다.
  bool get _hasImageArea =>
      _notices.any((n) => n.imageUrl != null && !_failedImages.contains(n.id));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 넘기기 전에 모든 장의 그림을 미리 받는다. 넘겨 보기 전에 실패를 알아야
    // 전부 실패했을 때 그림 자리를 처음부터 걷어낼 수 있다(N3).
    if (_precached) return;
    _precached = true;
    for (final notice in _notices) {
      final url = notice.imageUrl;
      if (url == null) continue;
      precacheImage(
        widget.imageFor(url),
        context,
        onError: (e, _) => _markImageFailed(notice.id, e),
      );
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _markImageFailed(String noticeId, Object error) {
    if (_failedImages.contains(noticeId)) return;
    AppLogger.error('notice', error, null, {'step': 'image', 'id': noticeId});
    // 그림의 errorBuilder 는 그리는 중에 불린다 — 그 자리에서 setState 하면 안 된다
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _failedImages.add(noticeId));
    });
  }

  void _onPageChanged(int index) {
    setState(() => _index = index);
    // 점은 눈으로 보는 것이라 낭독기 사용자에게는 위치를 말로 알린다
    SemanticsService.sendAnnouncement(
      View.of(context),
      '${index + 1}/${_notices.length}',
      Directionality.of(context),
    );
  }

  void _go(int delta) {
    final target = (_index + delta).clamp(0, _notices.length - 1);
    // 동작 줄이기를 켰으면 미끄러지지 않고 바로 바꾼다
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(target);
    } else {
      _pages.animateToPage(
        target,
        duration: AppMotion.normal,
        curve: AppMotion.standard,
      );
    }
  }

  Future<void> _open(AppNotice notice) async {
    final button = notice.button;
    // 빨리 두 번 눌러도 브라우저는 한 번만 연다
    if (button == null || _opening) return;
    _opening = true;
    final opened = await widget.openLink(button.url);
    _opening = false;
    if (!mounted) return;
    if (!opened) {
      AppLogger.error('notice', 'link not opened', null, {
        'id': notice.id,
        'code': NoticeSlide.linkFailureCode,
      });
    }
    setState(() => _linkFailedId = opened ? null : notice.id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final media = MediaQuery.of(context);
    // ScreenUtil(.w)을 쓰지 않는다. 명세가 화면 비율로 정한 카드이고, .w 를 쓰면
    // 360 폭 휴대폰에서 44 누름 영역이 40 으로 줄어든다.
    final width = math.min(media.size.width * _widthRatio, _maxWidth);
    final maxHeight =
        media.size.height - media.padding.vertical - _screenMargin * 2;
    final textMax = media.size.height * _textMaxRatio;
    final hasImageArea = _hasImageArea;

    Widget slide(AppNotice notice, {required bool measuring}) => NoticeSlide(
      notice: notice,
      showImageArea: hasImageArea,
      imageFailed: _failedImages.contains(notice.id),
      textMaxHeight: textMax,
      imageFor: widget.imageFor,
      onImageError: _markImageFailed,
      onOpenLink: () => _open(notice),
      linkFailed: _linkFailedId == notice.id,
      measuring: measuring,
    );

    final controls = MediaQuery.withClampedTextScaling(
      maxScaleFactor: _controlsMaxScale,
      child: ValueListenableBuilder<bool>(
        valueListenable: widget.hideChecked,
        builder: (context, checked, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: NoticeHideToggle(
                label: noticeHideLabel(widget.feed.hideDays),
                checked: checked,
                onChanged: (v) => widget.hideChecked.value = v,
              ),
            ),
            NoticeCloseButton(onTap: widget.onClose),
          ],
        ),
      ),
    );

    final pages = Stack(
      children: [
        // PageView 는 스스로 높이를 정하지 못한다. 모든 장을 보이지 않게 한 벌 더 그려
        // **가장 긴 장**에 카드 높이를 맞춘다 — 넘길 때마다 카드가 들썩이지 않는다.
        ExcludeSemantics(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0,
              child: Stack(
                children: [for (final n in _notices) slide(n, measuring: true)],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: PageView.builder(
            key: NoticePopupCard.pagesKey,
            controller: _pages,
            itemCount: _notices.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, i) => slide(_notices[i], measuring: false),
          ),
        ),
        if (hasImageArea)
          Positioned(
            top: _controlsInset,
            right: _controlsInset,
            left: _controlsInset,
            child: Align(alignment: Alignment.topRight, child: controls),
          ),
      ],
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          key: NoticePopupCard.cardKey,
          width: width,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(_radius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 그림이 없으면 조작부가 얹힐 자리가 없어 제 줄을 갖는다
              if (!hasImageArea)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _controlsInset,
                    _controlsInset,
                    _controlsInset,
                    0,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: controls,
                  ),
                ),
              Flexible(child: pages),
              if (_notices.length > 1)
                NoticePageNav(
                  dotsKey: NoticePopupCard.dotsKey,
                  index: _index,
                  count: _notices.length,
                  onPrev: () => _go(-1),
                  onNext: () => _go(1),
                ),
              const SizedBox(height: _navBottom),
            ],
          ),
        ),
      ),
    );
  }
}

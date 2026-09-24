import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../shared/models/action_card.dart';
import '../../../guardian/presentation/widgets/action_card_view.dart';

/// 이룸이 일과 상세의 카드 넘기기 — 가운데 카드 한 장과 **가장자리에 걸친 옆 카드**.
///
/// 시안(`309:3548`)은 가운데 카드만 그린다. 옆 카드를 조금 보이게 한 것은
/// **사용자가 승인한 시안 이탈이다 (#394).** 이룸이는 글보다 그림으로 알아챈다 —
/// 옆에 카드 끝이 보이면 "넘기면 더 있다"가 설명 없이 전해진다.
///
/// 가운데 카드의 크기·자리(345×431 @ 24,180)는 시안 그대로다. 시안의 좌우 여백
/// 24 안에서 카드 사이 간격 [cardGap]을 빼고 남는 [peekWidth]만 옆 카드가 보인다.
class ChildCardPager extends StatelessWidget {
  const ChildCardPager({
    super.key,
    required this.controller,
    required this.cards,
    required this.routineId,
    required this.currentIndex,
    required this.speakingId,
    required this.onSpeak,
    required this.onPageChanged,
    required this.onSideTap,
    required this.isChecked,
  });

  /// 시안 카드 폭 (`309:3568` — 345 @ x=24).
  static const cardWidth = 345.0;

  /// 시안 카드 왼쪽 여백 — 화면 가장자리에서 카드까지.
  static const _sideMargin = 24.0;

  /// 카드 사이 간격. `space.xs`(8)와 같은 값이다.
  ///
  /// 여백 24 안에서 간격과 보이는 폭을 나눠 가진다. 간격을 줄이면 카드가 붙어
  /// 한 장처럼 보이고, 늘리면 보이는 폭이 모서리 곡선(r20)보다 좁아져 무엇인지
  /// 알아보기 어렵다. 8 이면 16 이 보인다 — 보호자 카드확인 시안(`262:5124`)이
  /// 옆 카드를 20 걸친 것과 비슷한 정도다.
  static const cardGap = 8.0;

  /// 옆 카드가 화면 안에 보이는 폭 (393 기준).
  static const peekWidth = _sideMargin - cardGap;

  /// 한 장이 차지하는 폭(카드 + 간격)의 화면 비율. 가운데 카드가 정확히 24 에서
  /// 시작하도록 맞춘다 — 폭과 간격이 같은 비율(`.w`)로 늘고 주니 기기 폭과 무관하다.
  static const viewportFraction = (cardWidth + cardGap) / 393;

  /// 옆 카드 크기. 조금만 줄여 가운데 카드가 "지금 할 것"으로 읽히게 한다.
  /// 더 줄이면 보이는 띠가 짧아져 카드로 안 보인다.
  static const sideScale = 0.94;

  /// 옆 카드 불투명도. 가운데 카드와 같은 선명도면 체크 버튼이 어느 카드를
  /// 가리키는지 흐려진다.
  static const sideOpacity = 0.5;

  final PageController controller;
  final List<ActionCard> cards;
  final String routineId;

  /// 지금 가운데 있는 카드. 체크 버튼 대상이자 화면 낭독기가 읽는 카드다.
  final int currentIndex;

  /// 지금 읽고 있는 카드 id.
  final String? speakingId;

  final ValueChanged<ActionCard> onSpeak;
  final ValueChanged<int> onPageChanged;

  /// 옆 카드를 눌렀을 때. 그 카드로 넘어간다.
  final ValueChanged<int> onSideTap;

  /// 이 카드를 이미 했는가. 옆에 걸친 카드에 체크 표시를 둘지 정한다 (#394 P8).
  final bool Function(ActionCard card) isChecked;

  /// 옆 카드 체크 표시 지름 (#394 P8). 보이는 띠가 [peekWidth](16)라 그 안에
  /// 들어갈 만큼만 — 더 키우면 화면 끝에 잘리거나 가운데 카드에 닿는다.
  static const sideCheckSize = 16.0;

  /// 체크 표시가 옆 카드의 가운데 쪽 가장자리 밖(간격 쪽)으로 나가는 폭.
  /// 띠 안에만 두면 화면 끝에 붙는다 — 간격(8) 쪽으로 2 걸쳐 양쪽에 숨 쉴 틈을 둔다.
  static const sideCheckOverhang = 2.0;

  /// 체크 표시의 위쪽 자리 — 카드 모서리 곡선(r20)이 끝나는 아래.
  static const sideCheckTop = 16.0;

  /// [index] 카드가 가운데에서 얼마나 떨어졌는지 (0 = 가운데, 1 = 한 장 옆).
  double _distance(int index) {
    final page = _page;
    return (page - index).abs().clamp(0.0, 1.0);
  }

  /// 지금 페이지 위치(소수). 첫 프레임에는 아직 크기가 없어 [currentIndex]로 둔다.
  double get _page {
    if (!controller.hasClients) return currentIndex.toDouble();
    final position = controller.position;
    if (!position.hasContentDimensions) return currentIndex.toDouble();
    return controller.page ?? currentIndex.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    // 넘기면 위치가 바뀐다 — liveRegion 이라 화면 낭독기가 바뀐 값을 읽는다.
    // 카드 내용은 따로 읽혀야 하므로 자식을 이 이름에 합치지 않는다.
    return Semantics(
      container: true,
      explicitChildNodes: true,
      liveRegion: true,
      label: '카드 ${cards.length}장 중 ${currentIndex + 1}번째',
      child: PageView.builder(
        controller: controller,
        itemCount: cards.length,
        onPageChanged: onPageChanged,
        itemBuilder: _buildItem,
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    final card = cards[index];
    final isSide = index != currentIndex;
    // 동작 줄이기면 크기·선명도를 넘기는 손을 따라 바꾸지 않는다 — 가운데로
    // 넘어가는 순간 한 번에 바뀐다.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Padding(
      // 간격의 절반씩 양쪽에 둔다. 폭 비율과 같이 늘고 줄도록 `.w`.
      padding: EdgeInsets.symmetric(horizontal: (cardGap / 2).w),
      child: GestureDetector(
        // 옆 카드를 누르면 그 카드로 넘어간다. 미는 것보다 누르는 것이 쉽다.
        behavior: HitTestBehavior.opaque,
        onTap: isSide ? () => onSideTap(index) : null,
        // 화면 낭독기에는 이 누름 자리를 내놓지 않는다. 이름 없는 누름 자리가
        // 되고, 낭독기 사용자는 넘기기(스크롤 동작)로 옆 카드에 간다.
        excludeFromSemantics: true,
        // 옆 카드는 읽지 않는다 — 화면 낭독기가 가운데 카드와 옆 카드를
        // 섞어 읽으면 무엇을 체크하는지 모른다.
        child: ExcludeSemantics(
          excluding: isSide,
          // 옆 카드 안의 스피커가 대신 눌리지 않게 한다. 누르면 넘어가기만 한다.
          child: IgnorePointer(
            ignoring: isSide,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                final t = reduceMotion
                    ? (isSide ? 1.0 : 0.0)
                    : _distance(index);
                // 오른쪽에 걸친 카드는 왼쪽 가장자리가, 왼쪽에 걸친 카드는 오른쪽
                // 가장자리가 화면에 보이는 띠다.
                final onRight = index > _page;
                return Transform.scale(
                  scale: lerpDouble(1, sideScale, t)!,
                  // **가운데 쪽 가장자리를 붙잡고 줄인다.** 가운데를 붙잡으면
                  // 바깥 끝이 10 씩 안으로 들어와 보이는 띠가 16 → 6 으로 준다.
                  alignment: onRight
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Stack(
                    // 카드는 자리 크기를 그대로 받는다 — loose 로 풀면 카드가 줄어든다.
                    fit: StackFit.passthrough,
                    clipBehavior: Clip.none,
                    children: [
                      Opacity(
                        opacity: lerpDouble(1, sideOpacity, t)!,
                        child: child,
                      ),
                      // P8 — 시안(`309:3648`)은 체크해도 카드는 그대로고 아래 버튼만
                      // 바뀐다. 가운데 카드는 그걸로 충분하지만 옆 띠(16)에는 버튼이
                      // 없어 했는지 안 했는지 모른다. 옆으로 갈수록(t) 체크 표시가
                      // 또렷해진다 — 카드처럼 흐리게 두면 알아보기 어렵다.
                      if (t > 0 && isChecked(card))
                        Positioned(
                          top: sideCheckTop.w,
                          left: onRight ? -sideCheckOverhang.w : null,
                          right: onRight ? null : -sideCheckOverhang.w,
                          child: Opacity(
                            opacity: t,
                            child: _SideCheck(
                              key: ValueKey('side-check-${card.id}'),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
              child: ActionCardView(
                key: ValueKey(card.id),
                card: card,
                index: index,
                routineId: routineId,
                onSpeak: () => onSpeak(card),
                isSpeaking: speakingId == card.id,
                layout: ActionCardLayout.childDetail,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 옆에 걸친 카드의 체크 표시 (#394 P8) — 체크 버튼과 같은 민트 원 + 흰 체크.
///
/// 새 그림을 만들지 않고 체크 버튼(`309:3682`)의 색·그림을 줄여 쓴다. 흰 테두리는
/// 민트 계열 카드 테두리(#93DBCC) 위에서도 원이 묻히지 않게 한다.
class _SideCheck extends StatelessWidget {
  const _SideCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // 원이라 가로세로 모두 .w
    final size = ChildCardPager.sideCheckSize.w;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.checkDone,
        border: Border.all(color: colors.surface, width: 1.5.w),
      ),
      alignment: Alignment.center,
      // 체크 버튼 그림(48×35.76 in 88)과 같은 비율로 줄인다
      child: SvgPicture.asset(
        AppAssets.childCheckMark,
        width: size * 48 / 88,
        height: size * 35.76 / 88,
        colorFilter: ColorFilter.mode(colors.surface, BlendMode.srcIn),
        excludeFromSemantics: true,
      ),
    );
  }
}

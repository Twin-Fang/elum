import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../shared/models/action_card.dart';
import 'action_card_view.dart';

/// 카드확인 화면의 부품 (#444 · 시안 `1173:5541` 기본 / `1197:5798` 순서 변경).
///
/// 화면 파일이 300줄을 넘지 않게 나눴다. 좌표는 시안(393×852) 그대로다.

/// 머리 — 회색 반짝임 + `카드 N개를 만들었어요` (시안 1173:5592).
///
/// 시안은 `카드 5개를 만들었어요`로 이미 능동형이다(옛 시안은 `생성되었어요`였다).
class CardReviewHead extends StatelessWidget {
  const CardReviewHead({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(AppAssets.iconSparklesHead, width: 18.w, height: 22.w),
        SizedBox(width: 12.w),
        Text(
          '카드 $count개를 만들었어요',
          style: context.typo.promptBody.copyWith(
            color: context.colors.promptMuted,
          ),
        ),
      ],
    );
  }
}

/// 보상 줄 — `완료 시 **젤리 4개 먹기** ✎` (시안 1173:5544, 333폭·라운드 8).
///
/// 정한 보상을 다시 확인하고 고친다(#239). **건너뛴 사람에게는 정하라고 권한다** —
/// 카드를 다 보고 나서야 "무엇을 주지"가 떠오르는 경우가 있다. 시안에는 정한 모습만
/// 있어, 안 정했을 때는 같은 상자에 `보상 정하기 +` 를 둔다.
class CardReviewRewardRow extends StatelessWidget {
  const CardReviewRewardRow({
    super.key,
    required this.reward,
    required this.onTap,
  });

  /// 정해진 보상 (`🍪 젤리 먹기`). null 이면 아직 없다.
  final String? reward;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.typo.rewardLine;
    final has = reward != null;

    return AppPressable(
      onTap: onTap,
      child: Container(
        width: 333.w,
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
        decoration: BoxDecoration(
          color: colors.editChipBg,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: has
                      ? [
                          TextSpan(
                            text: '완료 시 ',
                            style: style.copyWith(color: colors.rewardLineLead),
                          ),
                          TextSpan(
                            text: reward,
                            style: style.copyWith(color: colors.textPrimary),
                          ),
                        ]
                      : [
                          TextSpan(
                            text: '보상 정하기',
                            style: style.copyWith(color: colors.textPrimary),
                          ),
                        ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(width: 8.w),
            SvgPicture.asset(
              has ? AppAssets.iconPencilEdit : AppAssets.iconPlus,
              width: 12.w,
              height: 12.w,
              // 시안의 연필은 민트다 (point_color #55CFBA)
              colorFilter: ColorFilter.mode(colors.checkDone, BlendMode.srcIn),
            ),
          ],
        ),
      ),
    );
  }
}

/// 순서 변경 모드의 안내 (시안 1197:5899). 보상 줄이 있던 자리를 채운다.
class CardReviewReorderHint extends StatelessWidget {
  const CardReviewReorderHint({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 333.w,
      // 보상 줄(46)과 같은 높이라 아래 버튼이 움직이지 않는다
      height: 46.h,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          // 시안 글자 윗변이 587 + 8
          padding: EdgeInsets.only(top: 8.h),
          // 글꼴을 키우면 두 줄로 꺾여 46 높이 밖으로 잘린다 — 한 줄로 줄인다
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '카드를 길게 눌러 순서를 변경하세요',
              maxLines: 1,
              softWrap: false,
              style: context.typo.promptBody.copyWith(
                color: context.colors.promptMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 도구 버튼 3개 — `카드 순서 변경` · `이 카드 수정` · `카드 추가` (시안 1173:5574).
///
/// 순서 변경 모드에서는 `카드 순서 변경` 만 눌린 색이고 나머지 둘은 흐려진 채
/// 눌리지 않는다 (시안 1197:5798, 투명도 0.4).
class CardReviewToolRow extends StatelessWidget {
  const CardReviewToolRow({
    super.key,
    required this.reorderMode,
    required this.onReorder,
    required this.onEdit,
    required this.onAdd,
  });

  final bool reorderMode;
  final VoidCallback onReorder;
  final VoidCallback onEdit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // 110 × 3 + 8 × 2
      width: 346.w,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ToolButton(
            icon: AppAssets.iconInterlining,
            label: '카드 순서 변경',
            pressed: reorderMode,
            // 모드 안에서 다시 눌러도 할 일이 없다 — 나가는 길은 `완료`·`✕` 다
            onTap: reorderMode ? null : onReorder,
          ),
          _ToolButton(
            icon: AppAssets.iconPencilEdit,
            label: '이 카드 수정',
            dimmed: reorderMode,
            onTap: reorderMode ? null : onEdit,
          ),
          _ToolButton(
            icon: AppAssets.iconPlus,
            label: '카드 추가',
            dimmed: reorderMode,
            onTap: reorderMode ? null : onAdd,
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.pressed = false,
    this.dimmed = false,
  });

  final String icon;
  final String label;
  final VoidCallback? onTap;

  /// 눌린 색 (#D7D3D1)
  final bool pressed;

  /// 흐리게 (투명도 0.4)
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Opacity(
      opacity: dimmed ? 0.4 : 1,
      child: AppPressable(
        onTap: onTap,
        semanticLabel: label,
        child: Container(
          width: 110.w,
          height: 60.h,
          decoration: BoxDecoration(
            color: pressed ? colors.editChipPressedBg : colors.editChipBg,
            borderRadius: BorderRadius.circular(18.r),
          ),
          alignment: Alignment.center,
          // 글꼴을 키워도 버튼 밖으로 넘치지 않게 줄인다
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(icon, width: 16.w, height: 16.w),
                SizedBox(height: 8.h),
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: context.typo.editChipLabel.copyWith(
                    color: colors.editChipLabel,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 순서 변경 모드의 상단바 — `✕` + 가운데 `카드 순서 변경` (시안 1197:5798).
///
/// 높이는 기본 상단바(위 16 + 24 + 아래 12)와 같다 — 모드를 바꿀 때 화면이 출렁이지
/// 않게 한다. 뒤로·홈·임시저장은 없다: 이 모드에서 나가는 길은 `✕`·`완료`뿐이다.
class CardReviewReorderTopBar extends StatelessWidget {
  const CardReviewReorderTopBar({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 16.h, bottom: 12.h),
      child: SizedBox(
        // 폭을 채워야 `✕` 의 left 가 화면 왼쪽에서 잰다 — 안 채우면 글자 폭에 오그라든다
        width: double.infinity,
        height: 24.w,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Text(
              '카드 순서 변경',
              style: context.typo.reorderTitle.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
            // 그림이 40×40 안에 20×20 으로 그려져 있다 (x=16, y=67)
            Positioned(
              left: 16.w,
              child: AppPressable(
                onTap: onClose,
                scaleDown: AppPressable.scaleIcon,
                semanticLabel: '순서 변경 취소',
                child: SvgPicture.asset(
                  AppAssets.iconClose,
                  width: 40.w,
                  height: 40.w,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 순서 변경 모드의 카드 줄 — 길게 눌러 옮긴다 (시안 1197:5798).
///
/// 기본 화면과 같은 자리(카드 333 @ x=30, 사이 10)에 서서, 모드를 바꿔도 카드가
/// 움직이지 않는다. 카드 X 는 그리지 않는다(시안 첫 카드에 없다).
class CardReviewReorderList extends StatelessWidget {
  const CardReviewReorderList({
    super.key,
    required this.cards,
    required this.routineId,
    required this.cardWidth,
    required this.cardGap,
    required this.onReorder,
  });

  final List<ActionCard> cards;
  final String routineId;

  /// 카드 폭과 카드 사이 (기본 화면과 같은 값 — 모드를 바꿔도 카드가 움직이지 않는다)
  final double cardWidth;
  final double cardGap;
  final void Function(int oldIndex, int newIndex) onReorder;

  /// 잡힌 카드가 커지는 비율. 카드가 화면 폭을 거의 채워 크게 키우면 옆 카드를 덮는다.
  static const _liftScale = 0.04;

  @override
  Widget build(BuildContext context) {
    final radius = context.space.cardRadius;

    return ReorderableListView.builder(
      scrollDirection: Axis.horizontal,
      // 손잡이 없이 카드 어디든 **길게** 눌러 끈다 (시안 문구)
      buildDefaultDragHandles: false,
      // 첫 카드가 x=30 에 서도록 양옆 카드 사이의 반(5)을 뺀 값
      padding: EdgeInsets.symmetric(horizontal: 25.w),
      itemCount: cards.length,
      onReorder: onReorder,
      // 잡히는 순간 진동으로 알린다. 길게 눌러 잡는 화면이라 손가락이 카드를 가리므로
      // 눈으로 보이는 변화와 함께 손끝으로도 알려 준다 (#451).
      onReorderStart: (_) => HapticFeedback.mediumImpact(),
      // 들린 카드를 조금 키우고 그림자를 깐다. 예전에는 아무 변화가 없어 잡혔는지
      // 알 수 없었다 (#451). **시안 `1197:5798`에는 없는 동작이다** — 디자이너 확인 대상.
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, inner) {
          final lift = Curves.easeOut.transform(animation.value);
          // 이 목록은 항목에 가로 제약을 주지 않고(무한) **높이만** 고정해 준다.
          // 그래서 Stack 에 넣으면 카드가 내용 높이로 줄어 아래가 잘려 보인다 —
          // `StackFit.expand` 는 무한 폭 때문에 쓸 수 없어, 받은 높이를 카드에 직접 넘긴다 (#451).
          return LayoutBuilder(
            builder: (context, box) => Transform.scale(
              scale: 1 + _liftScale * lift,
              child: Stack(
                children: [
                  // 그림자는 카드 자리(양옆 간격 절반을 뺀 폭)에 맞춰 뒤에 깐다.
                  // 항목 전체에 그리면 카드보다 10 넓게 번진다.
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: (cardGap / 2).w,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radius),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: 0.24 * lift,
                              ),
                              blurRadius: 24 * lift,
                              offset: Offset(0, 10 * lift),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: box.maxHeight,
                    child: Material(
                      type: MaterialType.transparency,
                      child: inner,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      itemBuilder: (context, index) => ReorderableDelayedDragStartListener(
        key: ValueKey('reorder_${cards[index].id}'),
        index: index,
        child: SizedBox(
          width: (cardWidth + cardGap).w,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: (cardGap / 2).w),
            child: ActionCardView(
              key: ValueKey(cards[index].id),
              card: cards[index],
              index: index,
              routineId: routineId,
              // 모드 안에서는 소리를 읽지 않는다 — 카드가 움직이는 중이다
              onSpeak: () {},
              isSpeaking: false,
              onDelete: null,
            ),
          ),
        ),
      ),
    );
  }
}

/// 카드가 없을 때. 로딩이 실패해도 여기까지 올 수 있다.
class CardReviewEmpty extends StatelessWidget {
  const CardReviewEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.space.screenH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '만들어진 카드가 없어요',
              textAlign: TextAlign.center,
              style: context.typo.promptTitle.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
            SizedBox(height: context.space.md),
            Text(
              // 에러 코드를 함께 보여줘야 제보를 추적할 수 있다
              '다시 만들어 주세요 (E-CARD)',
              style: context.typo.promptBody.copyWith(
                color: context.colors.promptMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

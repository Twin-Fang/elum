import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../shared/models/action_card.dart';
import '../../domain/card_palette.dart';
import 'card_image.dart';

/// 행동 카드 한 장.
///
/// Figma `카드확인`(262:5124)과 `아이_홈`(309:3548)이 같은 카드를 쓴다.
/// 345×431 / r20 / 2px 테두리, 안에 이미지·번호·제목·설명이 들어간다.
///
/// 보호자용에는 삭제 X가 있고, 아이용에는 없다. [onDelete]로 가른다.
/// 수정 진입점은 카드 밖(`이 카드 수정하기` 칩)으로 나갔다 — 2026-07-22 시안.
///
/// 카드 안 배치는 [layout]으로 가른다 — 두 시안이 여백·그림칸 비율부터 달라졌다.
class ActionCardView extends StatefulWidget {
  const ActionCardView({
    super.key,
    required this.card,
    required this.index,
    this.routineId = '',
    this.onDelete,
    this.onSpeak,
    this.isSpeaking = false,
    this.layout = ActionCardLayout.review,
  });

  /// 시안 그림칸 비율 (`309:3548` — 313×264).
  ///
  /// 카드 자리가 시안 높이(431)면 이 비율로 설명 **두 줄까지** 넘침 없이
  /// 들어간다. 세 줄은 시안 자리 자체가 모자라 어느 화면에서도 넘친다 (#335).
  static const designIllustrationAspect = 313 / 264;

  final ActionCard card;

  /// 이미지를 받아오는 데 쓴다. 비면 대체 일러스트를 그린다.
  final String routineId;

  /// 색을 정하는 순서. `stepOrder`가 아니라 목록 인덱스다 —
  /// 서버가 순서를 1부터 주지 않을 수도 있다.
  final int index;

  /// 카드 삭제 (Figma 262:5124 이미지 우상단 X). null이면 그리지 않는다 —
  /// 아이 모드와 마지막 한 장 남은 카드가 해당된다.
  final VoidCallback? onDelete;

  /// 소리로 읽어주기.
  final VoidCallback? onSpeak;

  /// 지금 이 카드를 읽고 있는가. 아이콘 상태가 바뀐다.
  final bool isSpeaking;

  /// 카드 안 배치. 이룸이 일과 상세만 [ActionCardLayout.childDetail]을 쓴다.
  final ActionCardLayout layout;

  @override
  State<ActionCardView> createState() => _ActionCardViewState();
}

class _ActionCardViewState extends State<ActionCardView> {
  /// 배지 줄 아래 → 설명. 카드확인은 예전 값(17)을 그대로 쓴다.
  static const _titleToBody = 17.0;

  /// 이룸이 상세 — 배지 줄 아래 → 설명 (시안 `309:3548` 배지 끝 517 → 설명 535).
  static const _childTitleToBody = 18.0;

  /// 이룸이 상세 — 그림칸 아래 → 배지 (시안 `309:3548` 그림칸 끝 460 → 배지 477).
  static const _childIllustrationToTitle = 17.0;

  /// 카드 테두리 두께 (시안 `Rectangle 30` — 2, 안쪽 선).
  static const _borderWidth = 2.0;

  /// Figma 실측 — 카드 안 스피커 아이콘 24×24
  static const _volumeIconSize = 24.0;

  final _scrollController = ScrollController();

  // 설명이 두 줄이 되면 카드 높이를 넘겨 스크롤이 생긴다(§72 참조). 스크롤
  // 가능한지 사용자가 알 수 있도록 하단에 페이드를 덧그리는데, 그 여부를
  // 이 값으로 들고 있는다 — 매 프레임 새로 계산하면 카드 수만큼 리스너가
  // 계속 붙었다 떨어지는 낭비가 생긴다.
  bool _hasMoreBelow = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateFadeVisibility);
    // 첫 프레임 이후에 실제 콘텐츠 크기가 확정되므로 그때 한 번 계산한다.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateFadeVisibility(),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateFadeVisibility);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateFadeVisibility() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final hasMore = position.maxScrollExtent - position.pixels > 1;
    if (hasMore != _hasMoreBelow) {
      setState(() => _hasMoreBelow = hasMore);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = CardPalette.at(widget.index);
    final space = context.space;
    final childLayout = widget.layout == ActionCardLayout.childDetail;
    final speaker = AppPressable(
      onTap: widget.onSpeak,
      scaleDown: AppPressable.scaleIcon,
      // 읽는 중에 다시 누르면 멈춘다. 흐려지는 것만으로는
      // 화면 낭독기에 닿지 않아 이름도 함께 바꾼다 (#339).
      semanticLabel: widget.isSpeaking ? '읽기 멈추기' : '소리로 듣기',
      // SVG가 25×25인데 Figma 배치는 24×24다. 크기만 지정하면
      // 비율이 눌려 아이콘이 찌그러진다 — contain으로 비율을 지킨다.
      // 정사각형 아이콘이라 가로세로 모두 .w로 맞춘다
      child: SizedBox(
        width: _volumeIconSize.w,
        height: _volumeIconSize.w,
        // 읽는 중에는 흐리게 — 다시 누르면 멈춘다는 신호다
        child: AnimatedOpacity(
          duration: AppMotion.fast,
          opacity: widget.isSpeaking ? 0.45 : 1,
          child: SvgPicture.asset(AppAssets.iconVolume, fit: BoxFit.contain),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: palette.fill,
        borderRadius: BorderRadius.circular(space.cardRadius),
        border: Border.all(color: palette.border, width: _borderWidth.w),
        boxShadow: [
          BoxShadow(
            color: context.colors.glassShadow,
            blurRadius: 5.w,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      // 페이드가 카드 모서리를 넘지 않게 카드 radius로 함께 잘라낸다.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(space.cardRadius),
        child: Stack(
          children: [
            Padding(
              // 이룸이 상세는 **테두리를 빼고 준다.** Container 는 테두리 두께만큼
              // 안쪽을 이미 띄운다. md(16)를 그대로 주면 그림칸이 바깥에서 18
              // 들어가 시안(16, 안쪽 선이라 테두리 포함)보다 2 안쪽에 4 좁게
              // 그려진다 (#394).
              padding: EdgeInsets.all(
                childLayout ? space.md - _borderWidth.w : space.md,
              ),
              // 제목이 두 줄이 되면 카드 높이를 넘길 수 있다. 넘치면 스크롤한다 —
              // 노란 줄무늬 오버플로 경고가 뜨면 안 된다.
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 그림칸은 **313:264**이다 — 시안(`309:3548`) 실측.
                    // 4:3으로 두고 있었는데 그러면 칸이 32 낮아지고 카드 전체가
                    // 시안보다 46 짧아진다 (#297). 그림은 `BoxFit.contain`이라
                    // 칸 비율이 바뀌어도 잘리지 않는다.
                    //
                    // Expanded로 두면 남는 공간을 다 먹어 제목 길이에 따라 카드마다 이미지
                    // 크기와 텍스트 시작 높이가 달라진다.
                    AspectRatio(
                      aspectRatio: ActionCardView.designIllustrationAspect,
                      child: _Illustration(
                        routineId: widget.routineId,
                        stepId: widget.card.id,
                        onDelete: widget.onDelete,
                      ),
                    ),
                    SizedBox(
                      height: childLayout
                          ? _childIllustrationToTitle
                          : space.md,
                    ),
                    Row(
                      // center로 두면 한 줄/두 줄 모두 별도 측정 없이 배지·제목이
                      // Row 높이(둘 중 큰 쪽) 기준으로 세로 중앙 정렬된다 — 이슈 #105
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _NumberBadge(
                          order: widget.index + 1,
                          color: palette.border,
                        ),
                        // 이룸이 상세는 배지 → 제목 8 (시안 배지 끝 80 → 제목 88).
                        SizedBox(width: childLayout ? space.xs : space.sm),
                        Expanded(
                          child: Text(
                            // 제목을 …로 자르지 않는다. 아동이 무엇을 해야 하는지
                            // 알려주는 문장이라 잘리면 의미가 사라진다.
                            widget.card.displayTitle,
                            // 제목은 25/w800(style_GKEQ8F) — 순서 배지(cardHeadline 30)와 크기가 다르다
                            style: context.typo.actionCardTitle.copyWith(
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // 제목 아래 17 — 시안 제목 끝(509) → 설명(535). 토큰(12)을
                    // 쓰면 설명이 5 올라간다 (#297).
                    SizedBox(
                      height: childLayout ? _childTitleToBody : _titleToBody,
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // **이룸이 상세는 스피커를 배지 칸 한가운데에 둔다.** 시안은
                        // 스피커를 배지(40) 아래 가운데(x=48)에, 설명을 제목과 같은
                        // x(88)에 그린다. 카드 왼끝에 붙이면 스피커가 6 왼쪽, 설명이
                        // 10 왼쪽으로 가 제목과 줄이 안 맞는다 (#394).
                        //
                        // 카드확인은 예전 자리 그대로다 — 앱 카드가 시안(333)보다
                        // 좁아 설명 칸을 8 줄이면 `차례대\n로`처럼 낱말 중간에서 꺾인다.
                        if (childLayout)
                          SizedBox(
                            width: _NumberBadge.size.w,
                            child: Center(child: speaker),
                          )
                        else
                          speaker,
                        SizedBox(width: childLayout ? space.xs : space.sm),
                        Expanded(
                          child: Text(
                            widget.card.description,
                            style: context.typo.cardDescription.copyWith(
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // 설명이 잘려서 스크롤이 필요한 카드에서만 보인다 — 짧은 카드에는
            // 안 그린다. 스크롤이 다 내려가면(더 볼 내용이 없으면) 사라진다.
            if (_hasMoreBelow)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    height: space.xl,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          palette.fill.withValues(alpha: 0),
                          palette.fill,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 카드 이미지 자리.
///
/// 서버가 만든 그림을 보여주고, 못 받으면 캐릭터 일러스트로 대체한다.
/// 자리를 비우면 카드 비율이 무너진다.
class _Illustration extends StatelessWidget {
  const _Illustration({
    required this.routineId,
    required this.stepId,
    this.onDelete,
  });

  final String routineId;
  final String stepId;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(space.xs),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(space.xs),
              child: CardImage(routineId: routineId, stepId: stepId),
            ),
          ),
        ),
        if (onDelete != null)
          Positioned(
            top: space.xs,
            right: space.xs,
            child: _DeleteButton(onTap: onDelete!),
          ),
      ],
    );
  }
}

/// 카드 삭제 버튼 (Figma 262:5124 이미지 우상단 — 흐린 원 + X, 393:4010).
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onTap});

  final VoidCallback onTap;

  /// Figma 실측 30×30. 그대로 두면 보호자 최소 터치 타겟(44)에 못 미쳐
  /// 투명 여백으로 넓힌다.
  static const _visualSize = 30.0;
  static const _touchSize = 44.0;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleIcon,
      semanticLabel: '이 카드 지우기',
      // 정사각형 버튼 — 가로세로 모두 .w
      child: SizedBox(
        width: _touchSize.w,
        height: _touchSize.w,
        child: Center(
          child: SvgPicture.asset(
            AppAssets.iconCardDelete,
            width: _visualSize.w,
            height: _visualSize.w,
          ),
        ),
      ),
    );
  }
}

/// 순서 배지 (40×40, r12)
class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.order, required this.color});

  /// 배지 한 변. 아래 줄의 스피커 칸도 이 폭을 쓴다.
  static const size = 40.0;

  final int order;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // 정사각형 배지라 가로세로 모두 .w
    return Container(
      width: size.w,
      height: size.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12.w),
      ),
      // Text만 Container.alignment로 두면 실제 렌더링 시 글자가 오른쪽으로
      // 치우쳐 보인다(폰트 line box가 advance width보다 넓게 잡힘) — 이슈 재현
      // 스크린샷에서 좌우 여백이 약 3배 차이 났다. textAlign.center로 텍스트
      // 캔버스 자체를 중앙 정렬해 이를 바로잡는다.
      child: Text(
        '$order',
        textAlign: TextAlign.center,
        style: context.typo.cardHeadline.copyWith(
          color: context.colors.surface,
        ),
      ),
    );
  }
}

/// 카드 안 배치. 두 화면의 시안이 따로 움직여 값이 다르다.
enum ActionCardLayout {
  /// 보호자 카드확인 (`262:5124`). 여백 16(테두리 밖)·배지 → 제목 12·스피커는 왼끝.
  review,

  /// 이룸이 일과 상세 (`309:3548`). 테두리 포함 여백 16·그림칸 → 배지 17·
  /// 배지 → 제목 8·스피커는 배지 칸 가운데·설명은 제목과 같은 x·배지 → 설명 18 (#394).
  childDetail,
}

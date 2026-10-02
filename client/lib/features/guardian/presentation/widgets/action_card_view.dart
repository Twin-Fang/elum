import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../shared/models/action_card.dart';
import '../../domain/card_palette.dart';
import 'card_image.dart';
import 'default_card_art.dart';

/// 행동 카드 한 장.
///
/// Figma `카드확인`(262:5124)과 `아이_홈`(309:3548)이 같은 카드를 쓴다.
/// 333×410 / r20 / 2px 테두리, 안에 이미지·번호·제목·설명이 들어간다.
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
    this.onAddPhoto,
  });

  /// 카드확인 시안 그림칸 비율 (`262:5124` — 313×230, 2026-09-24 덤프 · #401).
  ///
  /// 카드확인과 이룸이 상세(`1197:6775`, #445)가 같이 쓴다. 카드 자리가 410 이라
  /// 그림칸이 낮은 만큼 설명이 들어갈 자리가 남는다.
  static const reviewIllustrationAspect = 313 / 230;

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

  /// 그림이 없는 카드의 `사진 추가`를 눌렀을 때 (보호자 화면만 쓴다 · #458).
  ///
  /// **픽토그램이 그림 자리를 채우면(#469) 이 자리가 없어진다** — 사진은 카드 수정 시트의
  /// `사진 바꾸기` 칩(#456)에서 넣는다. 카드마다 칩을 또 얹으면 카드확인이 어수선해진다.
  ///
  /// **null 이면 누를 수 없다.** 사진 바꾸기(#456)가 이 훅에 연결한다 — 그 전에는
  /// 자리만 보이고 눌러도 아무 일이 없다. 이룸이 화면([ActionCardLayout.childDetail])은
  /// 사진을 넣는 자리가 아니라 무시한다.
  final VoidCallback? onAddPhoto;

  @override
  State<ActionCardView> createState() => _ActionCardViewState();
}

class _ActionCardViewState extends State<ActionCardView> {
  /// 카드확인 — 테두리를 포함한 안쪽 여백 (시안 `262:5124` 카드 30 → 그림칸 40 · #401).
  static const _reviewInset = 10.0;

  /// 카드확인 — 그림칸 아래 → 배지 (시안 그림칸 끝 443 → 배지 453).
  static const _reviewIllustrationToTitle = 10.0;

  /// 카드확인 — 배지 줄 아래 → 설명 (시안 배지 끝 493 → 설명 511).
  static const _reviewTitleToBody = 18.0;

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
    // 자리가 바뀌면 이 색으로 **서서히** 옮겨 간다 (#451). 아래 빌더가 맡는다.
    final target = CardPalette.at(widget.index);
    final space = context.space;
    final childLayout = widget.layout == ActionCardLayout.childDetail;
    // 이룸이 상세 시안(`1197:6775`)이 카드확인과 같은 카드로 바뀌었다 (#445).
    // 여백·그림칸·간격이 같고 **그림자만 이룸이 상세에 있다.**
    final inset = _reviewInset.w;
    final illustrationAspect = ActionCardView.reviewIllustrationAspect;
    final illustrationToTitle = _reviewIllustrationToTitle;
    final titleToBody = _reviewTitleToBody;
    final speaker = AppPressable(
      onTap: widget.onSpeak,
      scaleDown: AppPressable.scaleIcon,
      // 읽는 중에 다시 누르면 멈춘다. 흐려지는 것만으로는
      // 화면 낭독기에 닿지 않아 이름도 함께 바꾼다 (#339).
      semanticLabel: widget.isSpeaking
          ? context.l10n.cardSpeakStop
          : context.l10n.cardSpeak,
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

    // 순서를 바꾸면 카드가 새 자리 색을 입는다. 그대로 두면 카드 한 장이 통째로 한
    // 프레임에 바뀌어 어지럽다 — 배경과 테두리·배지를 [AppMotion.normal] 동안 섞는다.
    // 처음 그릴 때는 목적 색에서 시작하므로 등장 시에는 움직이지 않는다 (#451).
    return Consumer(
      // 그림이 없다는 사실을 그림 자리와 제목 줄이 **같이** 알아야 한다 (#458).
      builder: (context, ref, _) {
        final imageState = watchCardImageState(
          ref,
          routineId: widget.routineId,
          stepId: widget.card.id,
          imagePath: widget.card.imagePath,
        );
        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: target.fill),
          duration: AppMotion.normal,
          builder: (context, fillColor, _) => TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: target.border),
            duration: AppMotion.normal,
            builder: (context, borderColor, _) {
              final palette = CardPalette(
                fill: fillColor ?? target.fill,
                border: borderColor ?? target.border,
              );
              return _buildCard(
                context,
                palette: palette,
                space: space,
                childLayout: childLayout,
                inset: inset,
                illustrationAspect: illustrationAspect,
                illustrationToTitle: illustrationToTitle,
                titleToBody: titleToBody,
                speaker: speaker,
                imageState: imageState,
              );
            },
          ),
        );
      },
    );
  }

  /// 색이 정해진 카드 본체. [build] 의 색 전환 빌더가 매 프레임 부른다.
  Widget _buildCard(
    BuildContext context, {
    required CardPalette palette,
    required AppSpacing space,
    required bool childLayout,
    required double inset,
    required double illustrationAspect,
    required double illustrationToTitle,
    required double titleToBody,
    required Widget speaker,
    required CardImageState imageState,
  }) {
    // 이룸이 화면은 그림이 없을 때 제목이 그림 자리로 올라간다 (#458). 줄에 또 두면
    // 같은 글이 두 번 나온다. 받는 중에는 그림이 올 수 있어 줄에 그대로 둔다.
    // 픽토그램이 그림 자리를 채우면(#469) 제목은 줄에 그대로 둔다 — 그림이 뜻을 전하고
    // 글자는 줄에서 읽는다.
    final titleInArt = childLayout &&
        imageState == CardImageState.none &&
        !showsPictogram(imageState, widget.card.pictogramId);
    return Container(
      decoration: BoxDecoration(
        color: palette.fill,
        borderRadius: BorderRadius.circular(space.cardRadius),
        border: Border.all(color: palette.border, width: _borderWidth.w),
        // 그림자는 이룸이 상세 시안(`309:3548` 0 2 5 · 5%)에만 있다. 카드확인
        // 시안(`262:5124`)은 effects 가 비어 있다 (#401).
        boxShadow: childLayout
            ? [
                BoxShadow(
                  color: context.colors.glassShadow,
                  blurRadius: 5.w,
                  offset: Offset(0, 2.h),
                ),
              ]
            : null,
      ),
      // 페이드가 카드 모서리를 넘지 않게 카드 radius로 함께 잘라낸다.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(space.cardRadius),
        child: Stack(
          children: [
            Padding(
              // **테두리를 빼고 준다.** Container 는 테두리 두께만큼 안쪽을 이미
              // 띄운다. 시안 여백(이룸이 상세 16 · 카드확인 10)은 안쪽 선이라 테두리를
              // 포함한 값이다 — 그대로 주면 그림칸이 2 안쪽에 4 좁게 그려진다
              // (#394). 카드확인은 여백 16(실제 18)을 쓰고 있어 설명이 제목과 줄이
              // 안 맞았다 (#401).
              padding: EdgeInsets.all(inset - _borderWidth.w),
              // 제목이 두 줄이 되면 카드 높이를 넘길 수 있다. 넘치면 스크롤한다 —
              // 노란 줄무늬 오버플로 경고가 뜨면 안 된다.
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 그림칸은 **313×230**이다 — 시안(`262:5124`·`1197:6775`) 실측.
                    // 그림은 `BoxFit.cover`로 칸을 꽉 채운다(시안 objectFit cover) —
                    // 칸과 비율이 다른 그림은 넘치는 쪽이 잘린다 (`CardImage`, #461).
                    //
                    // Expanded로 두면 남는 공간을 다 먹어 제목 길이에 따라 카드마다 이미지
                    // 크기와 텍스트 시작 높이가 달라진다.
                    AspectRatio(
                      aspectRatio: illustrationAspect,
                      child: _Illustration(
                        routineId: widget.routineId,
                        stepId: widget.card.id,
                        imagePath: widget.card.imagePath,
                        pictogramId: widget.card.pictogramId,
                        pictogramLabel: widget.card.displayTitle,
                        onDelete: widget.onDelete,
                        // 이룸이 화면은 사진을 넣는 자리가 아니다
                        emptyBuilder: (context) => childLayout
                            ? DefaultCardTitleArt(
                                title: widget.card.displayTitle,
                                color: palette.border,
                              )
                            : DefaultCardPhotoSlot(onAddPhoto: widget.onAddPhoto),
                      ),
                    ),
                    SizedBox(height: illustrationToTitle),
                    // 그림이 없어 제목이 그림 자리로 올라가면 줄 높이가 배지(40)로 줄어든다.
                    // 툭 줄지 않게 부드럽게 맞춘다.
                    AnimatedSize(
                      duration: AppMotion.fast,
                      alignment: Alignment.topLeft,
                      child: Row(
                        // center로 두면 한 줄/두 줄 모두 별도 측정 없이 배지·제목이
                        // Row 높이(둘 중 큰 쪽) 기준으로 세로 중앙 정렬된다 — 이슈 #105
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _NumberBadge(
                            order: widget.index + 1,
                            color: palette.border,
                          ),
                          // 배지 → 제목 8 (두 시안 모두 배지 끝 80 → 제목 88).
                          SizedBox(width: space.xs),
                          Expanded(
                            // 제목이 그림 자리로 올라가는 순간 줄의 제목이 툭 사라지면 그림 자리가
                            // 채워지기 전 한 순간 제목이 어디에도 없다. 그림 자리가 나타나는 속도와
                            // 같이 서서히 바꾼다.
                            child: AnimatedSwitcher(
                              duration: AppMotion.fast,
                              // 기본 배치는 가운데라 제목이 왼쪽 x=88 에서 밀린다
                              layoutBuilder: (current, previous) => Stack(
                                alignment: Alignment.centerLeft,
                                children: [...previous, ?current],
                              ),
                              child: titleInArt
                                  ? const SizedBox(key: ValueKey('title-in-art'))
                                  : Text(
                                      key: const ValueKey('title-in-row'),
                                      // 제목을 …로 자르지 않는다. 아동이 무엇을 해야 하는지
                                      // 알려주는 문장이라 잘리면 의미가 사라진다.
                                      widget.card.displayTitle,
                                      // 제목은 25/w800(style_GKEQ8F) — 순서 배지(cardHeadline 30)와 크기가 다르다
                                      style: context.typo.actionCardTitle.copyWith(
                                        color: context.colors.textPrimary,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 제목 아래 17 — 시안 제목 끝(509) → 설명(535). 토큰(12)을
                    // 쓰면 설명이 5 올라간다 (#297).
                    SizedBox(height: titleToBody),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // **스피커를 배지 칸 한가운데에 둔다.** 두 시안 모두 스피커를
                        // 배지(40) 아래 가운데(x=48)에, 설명을 제목과 같은 x(88)에
                        // 그린다. 카드 왼끝에 붙이면 설명이 제목보다 왼쪽에서 시작해
                        // 줄이 안 맞는다 (이룸이 상세 #394 · 카드확인 #401).
                        SizedBox(
                          width: _NumberBadge.size.w,
                          child: Center(child: speaker),
                        ),
                        SizedBox(width: space.xs),
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
/// 서버가 만든 그림을 보여주고, 없으면 [emptyBuilder]의 기본 카드로 채운다 (#458).
/// 자리를 비우면 카드 비율이 무너진다.
class _Illustration extends StatelessWidget {
  const _Illustration({
    required this.routineId,
    required this.stepId,
    this.imagePath,
    this.pictogramId,
    this.pictogramLabel = '',
    required this.emptyBuilder,
    this.onDelete,
  });

  final String routineId;
  final String stepId;
  final String? imagePath;
  final String? pictogramId;
  final String pictogramLabel;
  final WidgetBuilder emptyBuilder;
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
              child: CardImage(
                routineId: routineId,
                stepId: stepId,
                imagePath: imagePath,
                pictogramId: pictogramId,
                pictogramLabel: pictogramLabel,
                emptyBuilder: emptyBuilder,
              ),
            ),
          ),
        ),
        // 지우기 원(30)은 그림칸 위·오른쪽에서 6 안쪽이다 (시안 `262:5124` 그림칸
        // 40,213 · 원 317,219 · #401). 누름 영역(44)이 원보다 7씩 넓어 그만큼 뺀다 —
        // 전에는 누름 영역을 8 안쪽에 둬 원이 15 안쪽에 있었다.
        if (onDelete != null)
          Positioned(
            top: _DeleteButton.designInset.w - _DeleteButton.touchPad.w,
            right: _DeleteButton.designInset.w - _DeleteButton.touchPad.w,
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

  /// 원이 그림칸 모서리에서 떨어진 거리 (시안 `262:5124`).
  static const designInset = 6.0;

  /// 누름 영역이 원보다 한쪽에 더 넓은 만큼.
  static const touchPad = (_touchSize - _visualSize) / 2;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleIcon,
      semanticLabel: context.l10n.cardDeleteLabel,
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
  /// 보호자 카드확인 (`262:5124`, 2026-09-24 덤프 · #401). 테두리 포함 여백 10·
  /// 그림칸 313×230·그림칸 → 배지 10·배지 → 제목 8·스피커는 배지 칸 가운데·
  /// 설명은 제목과 같은 x·배지 → 설명 18·그림자 없음.
  review,

  /// 이룸이 일과 상세 (`1197:6775`, 2026-09-29 시안 · #445). 카드확인과 배치가 같고
  /// (여백 10·그림칸 313×230·배지 → 설명 18) **그림자(0 2 5 · 5%)만 있다.**
  /// 예전(`309:3548` 345×431, 여백 16·그림칸 313×264)은 카드가 더 컸다.
  childDetail,
}

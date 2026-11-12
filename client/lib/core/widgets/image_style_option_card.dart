import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets/app_assets.dart';
import '../l10n/l10n_context.dart';
import '../text/keep_words.dart';
import '../theme/app_motion.dart';
import '../theme/theme_context_ext.dart';
import 'pro_badge.dart';
import '../../shared/models/character.dart';
import '../../shared/models/image_style.dart';

/// 그림 방식 선택 카드 한 장 — 온보딩과 보호자 설정이 같이 쓴다.
///
/// Figma `그림방식` 1274:9883(만화 선택)·1274:10129(직접 찍은 사진 선택). 카드는 344×94,
/// 모서리 20이고 왼쪽에 70×70 예시, 오른쪽에 20×20 라디오가 선다. 고르면 민트 면(`#B5EAEC`)과
/// 2px 테두리(`#93DBCC`)로 바뀐다.
///
/// 만화 그림 예시는 카드에 실제로 그려지는 만화 아이(이 닦기), 사진 같은 그림은 시안의 사진 에셋,
/// 이모지·그림 기호는 실제 카드에 들어가는 그림(이 닦기)이다. 잠긴 Pro 방식은 이름 옆 [ProBadge] + 라디오 자리 자물쇠 + 예시 흐림 (잠금 판단은 호출부, #1149 · #1286).
///
/// 세 화면(온보딩·보호자 설정·이룸이 정보 시트)이 같은 카드를 쓰므로 여기서만 고친다.
class ImageStyleOptionCard extends StatelessWidget {
  const ImageStyleOptionCard({
    super.key,
    required this.style,
    required this.isSelected,
    this.character = CardCharacter.cat,
    this.isLocked = false,
  });

  final ImageStyle style;
  final bool isSelected;

  /// 고른 캐릭터 (지금 예시 그림은 캐릭터와 무관한 만화 아이. 캐릭터별 예시를 다시 열 자리)
  final CardCharacter character;

  /// Free 에게 잠긴 Pro 방식인가: 이름 옆 [ProBadge] · 라디오 대신 자물쇠 · 예시 흐림 (누르면 호출부가 요금제 안내)
  final bool isLocked;

  /// 카드 높이 72 · 안쪽 여백 10 · 예시 52×52 r8 · 라디오 20×20 · 라디오 오른쪽 16.
  /// (#1286: 시안 94·12·70 에서 줄임 — 온보딩에서 크레딧 띠·안내 + 네 방식 + 다음 버튼이 한 화면에 들어오게)
  static const minHeight = 72.0;
  static const _inset = 10.0;
  static const _exampleSize = 52.0;
  static const _exampleRadius = 8.0;
  static const _radioSize = 20.0;
  static const _radioDot = 14.0;
  static const _radioRight = 16.0;

  /// 예시와 글 사이 10, 제목과 설명 사이 8.
  ///
  /// 글과 라디오 사이는 시안이 10 이지만 **2 로 둔다.** 앱 글꼴이 시안보다 3% 가량 넓어
  /// 시안의 글 칸(206)에는 `그림은 직접 찍은 사진으로 넣어요.` 가 안 들어가 세 줄이 된다.
  /// 칸을 8 넓혀 시안의 두 줄 끊김이 그대로 나오게 한다. 라디오와 겹치지는 않는다 —
  /// 칸 안에서 줄바꿈하므로 넘치면 아래로 꺾인다.
  static const _exampleToText = 10.0;
  static const _titleToBody = 8.0;
  static const _textToRadio = 2.0;

  /// 이름과 Pro 배지 사이 (인쇄 디자인 Pro 배지와 같은 6)
  static const _titleToBadge = 6.0;

  /// 잠긴 방식 예시 그림 불투명도 (고를 수 없다는 신호, 그림은 알아볼 만큼)
  static const _lockedExampleOpacity = 0.55;

  /// 문장이 둘이면 문장 끝에서 줄을 나눈다 (시안 `1274:10078` — `...넣어요.` / `글은 ...`).
  ///
  /// 글자 폭에 맡기면 시안 글꼴과 폭이 조금 달라 `사진으로` 에서 끊겨 줄이 시안과 어긋난다.
  /// 낭독기에는 원문을 주므로 읽는 데는 영향이 없다.
  static String _breakAtSentence(String text) => text.replaceFirst('. ', '.\n');

  /// 화면 낭독기가 읽는 이름. 제목과 설명을 함께 읽는다 — 이름만 들으면 어떤 그림이
  /// 들어가는지 모른다. 크레딧은 목록 위 `ImageStyleCreditBar` 가 따로 읽힌다.
  static String semanticLabel(ImageStyle style) =>
      '${style.label}, ${style.description}';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final typo = context.typo;

    // 선택하면 테두리가 두꺼워져 안쪽 내용이 밀리므로
    // 테두리 두께만큼 안쪽 여백을 줄여, 내용은 카드 바깥 끝에서 늘 12 떨어진다.
    final borderWidth =
        isSelected ? space.selectedBorderWidth : space.borderWidth;

    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      // 글자를 키우면 카드가 늘어난다 — 고정 높이면 설명이 잘린다
      constraints: BoxConstraints(minHeight: minHeight.h),
      padding: EdgeInsets.fromLTRB(
        _inset.w - borderWidth,
        _inset.w - borderWidth,
        _radioRight.w - borderWidth,
        _inset.w - borderWidth,
      ),
      decoration: BoxDecoration(
        color: isSelected ? colors.goalSelectedFill : colors.surface,
        borderRadius: BorderRadius.circular(space.cardRadius.r),
        border: Border.all(
          color: isSelected ? colors.goalSelectedBorder : colors.border,
          width: borderWidth,
        ),
      ),
      child: Row(
        children: [
          Opacity(
            opacity: isLocked ? _lockedExampleOpacity : 1,
            child: _Example(
              style: style,
              isSelected: isSelected,
            ),
          ),
          SizedBox(width: _exampleToText.w),
          Expanded(
            // 글 두 덩어리가 카드 가운데에 선다 (한 줄 설명은 위 27, 두 줄은 위 17).
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: _titleToBadge.w,
                  runSpacing: _titleToBadge.h,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      style.label,
                      style: typo.imageStyleOptionTitle.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    if (isLocked) const ProBadge(),
                  ],
                ),
                SizedBox(height: _titleToBody.h),
                Text(
                  // Flutter 는 한글을 글자 단위로 끊어 `넣어/요.` 처럼 갈라진다 —
                  // 띄어쓰기에서만 줄바꿈하게 한다. 낭독기에는 원문을 준다.
                  keepWords(
                    _breakAtSentence(style.description),
                    locale: context.appLocale,
                  ),
                  semanticsLabel: style.description,
                  // 색 `#74757D`. 두 줄인 설명만 줄 높이 1.2 다(`1274:10078`).
                  style: typo.imageStyleOptionBody.copyWith(
                    height: style == ImageStyle.symbol ? 1.2 : 1.0,
                    color: colors.routineTileLabel,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: _textToRadio.w),
          isLocked ? const _LockMark() : _Radio(isSelected: isSelected),
        ],
      ),
    );
  }
}

/// 예시 그림 자리 70×70, 모서리 8.
class _Example extends StatelessWidget {
  const _Example({
    required this.style,
    required this.isSelected,
  });

  final ImageStyle style;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final size = ImageStyleOptionCard._exampleSize.w;

    final Widget picture = switch (style) {
      // 만화 그림: 카드에 실제로 그려지는 만화 아이 (서버 CardImageSubject.CHILD)
      ImageStyle.character => Image.asset(
        AppAssets.imageStyleCartoon,
        fit: BoxFit.cover,
        // 장식 그림이다 — 카드 이름이 이미 뜻을 말한다
        excludeFromSemantics: true,
      ),
      ImageStyle.realistic => Image.asset(
        AppAssets.imageStyleRealistic,
        fit: BoxFit.contain,
        // 장식 그림이다 — 카드 이름이 이미 뜻을 말한다
        excludeFromSemantics: true,
      ),
      // 그림 기호·이모지는 흰 면 위에 그려진 그림이라 카드 면(surface)에 여백을 두고 얹는다.
      ImageStyle.symbol => const _PictureOnSurface(isEmoji: false),
      ImageStyle.emoji => const _PictureOnSurface(isEmoji: true),
    };

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          ImageStyleOptionCard._exampleRadius.r,
        ),
        child: picture,
      ),
    );
  }
}

/// 라디오 표시 — 고르면 민트 링 안에 점이 찬다 (20×20, 선 1px, 점 14).
class _Radio extends StatelessWidget {
  const _Radio({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = ImageStyleOptionCard._radioSize.w;

    return AnimatedContainer(
      duration: AppMotion.fast,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? colors.goalSelectedFill : colors.surface,
        border: Border.all(
          color: isSelected ? colors.goalSelectedBorder : colors.border,
        ),
      ),
      child: isSelected
          ? Container(
              width: ImageStyleOptionCard._radioDot.w,
              height: ImageStyleOptionCard._radioDot.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.goalSelectedBorder,
              ),
            )
          : null,
    );
  }
}

/// 잠긴 방식의 라디오 자리: 라디오와 같은 크기의 자물쇠 (회색, 고를 수 없음)
class _LockMark extends StatelessWidget {
  const _LockMark();

  @override
  Widget build(BuildContext context) {
    final size = ImageStyleOptionCard._radioSize.w;
    return SvgPicture.asset(
      AppAssets.iconLock,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(context.colors.routineTileLabel, BlendMode.srcIn),
      // 이름 옆 PRO 배지가 이미 잠김을 말한다
      excludeFromSemantics: true,
    );
  }
}

/// 카드 면 위에 여백을 두고 얹는 예시 그림 (그림 기호·이모지 공용)
class _PictureOnSurface extends StatelessWidget {
  const _PictureOnSurface({required this.isEmoji});

  final bool isEmoji;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.surface,
      child: Padding(
        padding: EdgeInsets.all(6.w),
        child: SvgPicture.asset(
          isEmoji ? AppAssets.imageStyleEmoji : AppAssets.imageStyleSymbol,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

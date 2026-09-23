import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/text/keep_words.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';

/// 누르는 곳은 모두 44×44 이상 (docs/08 §7-2). 그림은 작아도 손가락 자리는 줄이지 않는다.
const double noticeTapTarget = 44;

/// 본문 아래 `◯✓ 일주일간 보지 않기` (시안 1090:4919).
///
/// **동그라미와 글자 전체가 누름 영역이다.** 16짜리 동그라미만 누르게 하면 50대
/// 보호자가 몇 번씩 빗나간다. 누름 영역은 위아래로 44 까지 넓히되, 보이는 줄은
/// 16 이라 둘레 간격은 부르는 쪽이 그만큼 줄여 시안 자리를 지킨다.
/// 화면 낭독기에는 체크 상태까지 읽힌다.
class NoticeHideToggle extends StatelessWidget {
  const NoticeHideToggle({
    super.key,
    required this.label,
    required this.checked,
    required this.onChanged,
  });

  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;

  /// 시안 — 동그라미 16 · 글자와 사이 6.
  static const checkSize = 16.0;
  static const _checkToLabel = 6.0;

  /// 좌우로도 손가락 자리를 조금 준다. 글자 끝을 누르다 빗나가지 않게.
  static const _padH = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // AppPressable 의 semanticLabel 을 쓰지 않는다 — 그쪽은 "버튼"으로 읽혀 체크 상태를
    // 잃는다. 이름과 상태를 여기서 한 노드에 모으고, 누르는 동작도 이 노드로 모인다.
    return Semantics(
      container: true,
      checked: checked,
      label: label,
      child: AppPressable(
        onTap: () => onChanged(!checked),
        scaleDown: AppPressable.scaleIcon,
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: noticeTapTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _padH),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NoticeRoundCheck(checked: checked),
                  const SizedBox(width: _checkToLabel),
                  Flexible(
                    // 글꼴을 키우면 두 줄로 꺾는다 — 말줄임으로 자르면 무엇을 체크하는지
                    // 읽을 수 없다. 꺾을 때도 어절에서 꺾는다 ("일주일간 보지 / 않기").
                    child: Text(
                      keepWords(label),
                      textAlign: TextAlign.center,
                      style: context.typo.noticeHideLabel.copyWith(
                        color: colors.noticeHideLabel,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 동그란 체크 16 (시안 1090:4920 · 원본 컴포넌트 `채크_라운드` 726:4881).
///
/// 꺼져 있을 때 — 흰 원에 연한 청록 테두리와 체크 (`Default`, 시안 공지에 그려진 모양).
/// 켜졌을 때 — 포인트색으로 차고 체크가 흰색 (`enable`). 공지 시안은 꺼진 모양만
/// 그렸으므로 켜진 모양은 같은 컴포넌트 세트의 `enable` 을 따른다 — 약관 동의·일과
/// 완료의 동그란 체크와 같은 뜻이라 새로 만들지 않는다.
class NoticeRoundCheck extends StatelessWidget {
  const NoticeRoundCheck({super.key, required this.checked});

  final bool checked;

  static const _size = NoticeHideToggle.checkSize;

  /// 원본(20)의 테두리·체크 비율을 16 에 그대로 옮긴다 — 테두리 1.45, 체크 8.73×6.5.
  static const _ring = _size / 11;
  static const _markW = _size * 10.91 / 20;
  static const _markH = _size * 8.13 / 20;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? colors.checkDone : colors.surface,
        border: Border.all(
          color: checked ? colors.checkDone : colors.checkIdleBorder,
          width: _ring,
        ),
      ),
      // **글리프가 아니라 에셋이다.** `Icons.check` 는 정사각형이라 시안의 가로로 긴
      // 체크와 모양이 다르다 (client/CLAUDE.md §2).
      child: SvgPicture.asset(
        AppAssets.iconCheckMark,
        width: _markW,
        height: _markH,
        colorFilter: ColorFilter.mode(
          checked ? colors.surface : colors.checkIdleBorder,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}

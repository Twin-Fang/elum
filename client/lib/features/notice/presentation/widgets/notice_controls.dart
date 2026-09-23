import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';

/// 누르는 곳은 모두 44×44 이상 (명세 3-2). 그림은 작아도 손가락 자리는 줄이지 않는다.
const double noticeTapTarget = 44;

/// 오른쪽 위 `☐ 일주일간 보지 않기` (명세 2-1).
///
/// **네모와 글자 전체가 누름 영역이다.** 50대 보호자에게 18짜리 네모만 누르게 하면
/// 몇 번씩 빗나간다. 화면 낭독기에는 체크 상태까지 읽힌다.
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

  static const _box = 18.0;
  static const _boxRadius = 4.0;
  static const _boxToLabel = 6.0;
  static const _pillPadH = 10.0;
  static const _pillPadV = 7.0;

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
            child: Center(
              widthFactor: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: _pillPadH,
                  vertical: _pillPadV,
                ),
                decoration: BoxDecoration(
                  color: colors.noticeHidePillBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: AppMotion.fast,
                      width: _box,
                      height: _box,
                      decoration: BoxDecoration(
                        color: checked ? colors.checkDone : colors.surface,
                        borderRadius: BorderRadius.circular(_boxRadius),
                        border: Border.all(
                          color: checked
                              ? colors.checkDone
                              : colors.textSecondary,
                        ),
                      ),
                      alignment: Alignment.center,
                      // Material 체크는 획 끝이 달라 앱의 다른 체크와 다르게 보인다
                      child: checked
                          ? SvgPicture.asset(AppAssets.iconCheckMark, width: 11)
                          : null,
                    ),
                    const SizedBox(width: _boxToLabel),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typo.noticeHideLabel.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 오른쪽 위 ✕. 그림이 밝든 어둡든 보이게 반투명 원 위에 흰 ✕ 를 얹는다.
class NoticeCloseButton extends StatelessWidget {
  const NoticeCloseButton({super.key, required this.onTap});

  final VoidCallback onTap;

  static const _circle = 28.0;
  static const _icon = 18.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleIcon,
      semanticLabel: '공지 닫기',
      child: SizedBox.square(
        dimension: noticeTapTarget,
        child: Center(
          child: Container(
            width: _circle,
            height: _circle,
            decoration: BoxDecoration(
              color: colors.noticeCloseBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.close_rounded,
              size: _icon,
              color: colors.surface,
            ),
          ),
        ),
      ),
    );
  }
}

/// 맨 아래 `←  ● ○ ○  →` (명세 2-1).
///
/// 50대 보호자가 옆으로 미는 것을 모를 수 있어 화살표를 둔다. 첫 장에서 ←, 끝 장에서
/// → 는 숨긴다 — 눌러도 아무 일이 없는 버튼은 고장으로 읽힌다. 숨겨도 자리는 남겨
/// 점이 가운데에서 흔들리지 않게 한다.
class NoticePageNav extends StatelessWidget {
  const NoticePageNav({
    super.key,
    required this.dotsKey,
    required this.index,
    required this.count,
    required this.onPrev,
    required this.onNext,
  });

  final Key dotsKey;
  final int index;
  final int count;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  static const _dot = 8.0;
  static const _dotGap = 6.0;
  static const _arrow = 22.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasPrev = index > 0;
    final hasNext = index < count - 1;

    Widget arrow(IconData icon, String label, VoidCallback onTap) =>
        AppPressable(
          onTap: onTap,
          scaleDown: AppPressable.scaleIcon,
          semanticLabel: label,
          child: SizedBox.square(
            dimension: noticeTapTarget,
            child: Icon(icon, size: _arrow, color: colors.textSecondary),
          ),
        );

    const empty = SizedBox.square(dimension: noticeTapTarget);

    return Row(
      children: [
        hasPrev ? arrow(Icons.arrow_back, '이전 공지', onPrev) : empty,
        Expanded(
          child: Center(
            // 점은 글자 없이 위치를 말한다. 화면 낭독기에는 "2/4" 로 읽힌다.
            child: Semantics(
              key: dotsKey,
              label: '${index + 1}/$count',
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < count; i++) ...[
                      if (i > 0) const SizedBox(width: _dotGap),
                      AnimatedContainer(
                        duration: AppMotion.fast,
                        width: _dot,
                        height: _dot,
                        decoration: BoxDecoration(
                          color: i == index
                              ? colors.checkDone
                              : colors.noticeDotIdle,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        hasNext ? arrow(Icons.arrow_forward, '다음 공지', onNext) : empty,
      ],
    );
  }
}

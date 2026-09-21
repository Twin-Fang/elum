import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../domain/consent_documents.dart';

/// 약관 항목 한 줄 (Figma `726:5066` 외 · 이슈 #226).
///
/// 전에는 칩(`ConsentChip`, 344×68 테두리 박스)이었다. 디자인이 **테두리 없는 한 줄**로
/// 바뀌었다 — 전체 동의 버튼만 상자를 갖고, 항목은 목록처럼 읽힌다.
///
/// **탭 영역이 둘이다.** 왼쪽(체크 + `필수`/`선택` 배지)은 동의 토글,
/// 제목부터 오른쪽은 전문 열기. 한 덩어리로 두면 내용을 보려다 동의가 눌린다.
///
/// 🔴 배지까지 토글에 넣은 이유 (이슈 #235) — 체크만 누르게 두니 **탭 영역이
/// 50밖에 안 돼 손가락으로 맞추기 어려웠다.** 배지는 누를 것이 없는 라벨이라
/// 여기 붙이면 영역이 88로 넓어지면서 잃는 것이 없다.
class ConsentRow extends StatelessWidget {
  const ConsentRow({
    super.key,
    required this.item,
    required this.isChecked,
    required this.onToggle,
    required this.onOpen,
  });

  /// Figma 실측 — 항목 높이 50 고정 (y차 58에서 간격 8을 뺀 값)
  static const height = 50.0;

  /// 항목 사이 간격 (y차 58 - 높이 50)
  static const gap = 8.0;

  /// 체크 원 지름
  static const _checkSize = 20.0;

  /// 줄 왼쪽 → 체크 (x=18)
  static const _checkLeft = 18.0;

  /// 체크 오른쪽 → 배지 (50 - 18 - 20)
  static const _checkToBadge = 12.0;

  /// 배지 자리 (제목 x=88 - 배지 x=50). Figma는 글자 폭을 28로 재지만 실제 렌더는
  /// 그보다 넓어 **`필`/`수`로 줄바꿈된다.** 자리를 38로 잡아 한 줄로 둔다.
  static const _badgeSlot = 38.0;

  /// 화살표 상자 (24×24) 오른쪽 여백. Figma 상자 x=303, 줄 폭 344 → 344-303-24=17.
  /// 끝에 붙여 두면 19가 밖으로 나간다 (#297).
  static const _arrowRight = 17.0;

  /// 화살표 상자 크기. 안쪽 획은 8×16으로 그려진다.
  static const _arrowSize = 24.0;

  final ConsentItem item;
  final bool isChecked;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      height: height.h,
      child: Row(
        children: [
          // 체크 + 배지를 한 덩어리로 누른다 (88×50). 체크(20)만 받으면 좁다.
          AppPressable(
            onTap: onToggle,
            child: SizedBox(
              width: (_checkLeft + _checkSize + _checkToBadge + _badgeSlot).w,
              height: double.infinity,
              child: Row(
                children: [
                  SizedBox(width: _checkLeft.w),
                  _CheckCircle(checked: isChecked),
                  SizedBox(width: _checkToBadge.w),
                  SizedBox(
                    width: _badgeSlot.w,
                    child: Text(
                      item.required ? '필수' : '선택',
                      maxLines: 1,
                      softWrap: false,
                      // 필수는 포인트색으로 눈에 걸리게, 선택은 보조색으로 물러난다
                      style: context.typo.consentBadge.copyWith(
                        color: item.required
                            ? colors.checkDone
                            : colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: AppPressable(
              onTap: onOpen,
              child: SizedBox(
                height: double.infinity,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        // Figma가 #000000이다. textPrimary(#242634)가 아니다.
                        style: context.typo.consentLabel
                            .copyWith(color: colors.chipLabel, height: 1.3),
                      ),
                    ),
                    // Material 아이콘은 형태가 다르다 — 시안과 같은 SVG를 쓴다
                    // (`fi-br-angle-small-up` 356:4862). 원본이 아래를 보므로
                    // 반시계 90°를 돌려 `>`로 만든다.
                    Transform.rotate(
                      angle: -math.pi / 2,
                      child: SvgPicture.asset(
                        AppAssets.iconAngleSmall,
                        width: _arrowSize.w,
                        height: _arrowSize.w,
                        colorFilter: ColorFilter.mode(
                          colors.textSecondary,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    SizedBox(width: _arrowRight.w),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 원형 체크.
///
/// 꺼져 있어도 **체크가 보인다** — 원만 비워 두면 눌러야 할 자리인지 알기 어렵다.
/// 켜지면 포인트색으로 차고 체크가 흰색이 된다 (Figma 739:3747 ↔ 726:5056).
class _CheckCircle extends StatelessWidget {
  const _CheckCircle({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      width: ConsentRow._checkSize.w,
      height: ConsentRow._checkSize.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? colors.checkDone : Colors.transparent,
        border: Border.all(
          // border(#EFEFEF)는 배경(#F7F2EF)과 거의 같아 원이 사라진다
          color: checked ? colors.checkDone : colors.consentCheckIdle,
          width: context.space.borderWidth,
        ),
      ),
      // Material 체크는 획 끝이 달라 시안과 다르게 보인다 — 같은 에셋을 쓴다.
      // Figma 원(20) 안 10.91×8.13 (`726:4867` Union).
      child: Center(
        child: SvgPicture.asset(
          AppAssets.iconCheckMark,
          width: 10.91.w,
          height: 8.13.w,
          colorFilter: ColorFilter.mode(
            checked ? colors.surface : colors.consentCheckIdle,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}

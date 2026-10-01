import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../domain/link_code.dart';

/// 연결 암호 여섯 칸.
///
/// PIN 화면은 **점**으로 가린다 — 남이 보면 안 되기 때문이다. 연결 암호는 반대로
/// **보여 줘야** 한다. 보호자가 불러주고 이룸이가 받아적는 값이라 가리면 쓸 수 없다.
/// 그래서 크기·간격·모서리는 PIN과 맞추되 글자를 드러낸다 (명세 §5-2 와이어프레임).
class CodeBoxes extends StatelessWidget {
  const CodeBoxes({super.key, required this.value, this.hasError = false})
    : figma = false;

  /// 이룸이 휴대폰 연결 코드 입력 시안(`1274:7909` · `1274:7988`, #493)의 모양.
  ///
  /// 칸 48×64 · 모서리 8 · 선 1px · 안쪽 글자 40/w800 이고, 세 칸씩 묶어 가운데만
  /// 16 벌어진다(칸 사이는 4). 쓴 칸을 따로 강조하지 않는다 — 시안은 여섯 칸의 선이
  /// 모두 같다. 초대 코드 입력(`InviteEnterScreen`)은 시안이 없어 옛 모양을 쓴다(#479).
  const CodeBoxes.figma({super.key, required this.value, this.hasError = false})
    : figma = true;

  /// 시안 모양인가.
  final bool figma;

  /// 지금까지 입력된 글자. 여섯 자보다 짧으면 나머지는 빈 칸.
  final String value;

  /// 틀렸을 때. 테두리만 위험색으로 바꾼다 — 붉은 경고를 크게 쓰지 않는다 (§5-2).
  final bool hasError;

  static const _boxW = 44.0;
  static const _boxH = 56.0;

  // 시안 실측 — 칸 48×64, 칸 사이 4, 세 칸 묶음 사이 16, 모서리 8
  static const _figmaBoxW = 48.0;
  static const _figmaBoxH = 64.0;
  static const _figmaGap = 4.0;
  static const _figmaGroupGap = 16.0;
  static const _figmaRadius = 8.0;

  @override
  Widget build(BuildContext context) {
    if (figma) return _buildFigma(context);
    final colors = context.colors;
    final space = context.space;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < LinkCode.length; i++) ...[
          // 3-3으로 끊어 보여준다. 여섯을 붙여 두면 불러주다 자리를 놓친다.
          if (i == 3) SizedBox(width: space.md.w),
          if (i != 0 && i != 3) SizedBox(width: space.sm.w),
          Container(
            width: _boxW.w,
            height: _boxH.h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(space.buttonRadius.r),
              // 틀려도 경고색을 쓰지 않는다 — 이룸이 휴대폰 화면이다. 틀림은 흔들림과
              // 짧은 문구로 알린다 (docs/08-design-principles.md §6, #427).
              border: Border.all(
                color: hasError
                    ? colors.textSecondary
                    : (i < value.length ? colors.textPrimary : colors.border),
                width: i < value.length || hasError ? 1.5 : 1,
              ),
            ),
            child: Text(
              i < value.length ? value[i] : '',
              style: context.typo.sectionTitle
                  .copyWith(color: colors.textPrimary),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFigma(BuildContext context) {
    final colors = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < LinkCode.length; i++) ...[
          // 3-3으로 끊어 보여준다. 여섯을 붙여 두면 불러주다 자리를 놓친다.
          if (i == 3)
            SizedBox(width: _figmaGroupGap.w)
          else if (i != 0)
            SizedBox(width: _figmaGap.w),
          Container(
            width: _figmaBoxW.w,
            height: _figmaBoxH.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(_figmaRadius),
              // 틀려도 경고색을 쓰지 않는다 — 이룸이 휴대폰 화면이다 (#427).
              // 틀림은 흔들림과 짧은 문구로 알리고 선만 한 단계 진하게 한다.
              border: Border.all(
                color: hasError ? colors.textSecondary : colors.border,
              ),
            ),
            // 시안 글자 윗변은 칸 윗변에서 14(가운데면 12)다 — 2 낮게 선다
            child: Padding(
              padding: EdgeInsets.only(top: 4.w),
              child: Text(
                i < value.length ? value[i] : '',
                style: context.typo.linkCode.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

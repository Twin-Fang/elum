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
  const CodeBoxes({super.key, required this.value, this.hasError = false});

  /// 지금까지 입력된 글자. 여섯 자보다 짧으면 나머지는 빈 칸.
  final String value;

  /// 틀렸을 때. 테두리만 위험색으로 바꾼다 — 붉은 경고를 크게 쓰지 않는다 (§5-2).
  final bool hasError;

  static const _boxW = 44.0;
  static const _boxH = 56.0;

  @override
  Widget build(BuildContext context) {
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
}

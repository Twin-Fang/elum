import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/theme_context_ext.dart';
import 'elum_centered_title_row.dart';

/// 시트 머리: [왼쪽 버튼] [가운데 제목] [오른쪽 버튼] 한 줄 + 제목 아래 가운데 보조 글
/// 양옆 칸을 같은 폭으로 비워 두어 버튼이 하나뿐이어도 제목이 시트 정가운데에 선다
class ElumSheetHeader extends StatelessWidget {
  const ElumSheetHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.subtitle,
  });

  /// 가운데 제목 (textAlign: center). 글자 대신 입력칸처럼 바로 고치는 위젯도 둘 수 있다
  final Widget title;
  final Widget? leading;
  final Widget? trailing;

  /// 제목 바로 아래 가운데 한 줄 (예: 일과 2개)
  final String? subtitle;

  /// 양옆 버튼 칸 폭 (✕ 아이콘 버튼 · 두 글자 버튼이 들어가는 폭)
  static const sideSlotWidth = 56.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 큰 글자 설정에서 버튼이 칸보다 커지면 줄여 넣는다 (줄바꿈 · 넘침 방지)
        ElumCenteredTitleRow(
          sideSlotWidth: sideSlotWidth.w,
          leading: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(fit: BoxFit.scaleDown, child: leading),
          ),
          title: title,
          trailing: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(fit: BoxFit.scaleDown, child: trailing),
          ),
        ),
        if (subtitle != null) ...[
          SizedBox(height: context.space.xs.h / 2),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: context.typo.caption.copyWith(color: colors.textSecondary),
          ),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/theme_context_ext.dart';
import 'app_pressable.dart';

/// 설정 목록의 한 줄. 항목이 늘어도 이 위젯만 반복하면 된다.
///
/// 보호자 설정 화면에서만 쓰다가 약관 목록 화면이 같은 모양을 필요로 해서
/// 공통으로 올렸다 (이슈 #289). 두 화면이 각자 줄을 그리면 여백과 화살표가
/// 조금씩 달라진다.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onTap;

  /// 되돌릴 수 없는 항목. 색으로 구분해 실수로 누르는 것을 줄인다.
  final bool destructive;

  /// 시안(`1022:4467`) 실측 — 줄 높이 60, 좌우 안쪽 여백 16.
  static const _height = 60.0;
  static const _padH = 16.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppPressable(
      onTap: onTap,
      child: SizedBox(
        height: _height.h,
        // **구분선을 긋지 않는다.** 시안은 줄 사이가 배경 그대로다 — 렌더의
        // 경계 픽셀을 재 보면 배경색이 끊기지 않고 이어진다 (#349).
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: _padH.w),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: context.typo.settingsTileLabel.copyWith(
                    // 흐리게 하면 "못 누르는 항목"으로 읽힌다. 누를 수 있다는 것과
                    // 위험하다는 것을 동시에 전해야 한다 (이슈 #188).
                    color: destructive
                        ? colors.settingsDestructive
                        : colors.textPrimary,
                    // 시안은 회원탈퇴만 굵다.
                    fontWeight: destructive ? FontWeight.w500 : null,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20.w,
                color: colors.settingsChevron,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/theme_context_ext.dart';
import 'app_pressable.dart';
import 'settings_tile.dart';

/// 설정 목록의 켜고 끄는 한 줄.
///
/// 줄 높이·안쪽 여백·글자는 [SettingsTile] 과 같다. 시안에 켜고 끄는 줄이 없어 **임시 시안**이다 —
/// 디자인이 나오면 모양만 바꾼다. 줄 어디를 눌러도 바뀐다 (스위치만 눌러야 하면 작다).
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      toggled: value,
      label: label,
      onTap: () => onChanged(!value),
      child: ExcludeSemantics(
        child: AppPressable(
          onTap: () => onChanged(!value),
          // 시안 높이는 최소값이다 — 글자가 커지면 줄이 늘어난다.
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: SettingsTile.height.h),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: SettingsTile.padH.w),
              child: Row(
                children: [
                  Expanded(
                    // 줄이 늘어날 때 위아래가 붙지 않게 글에만 여백을 둔다.
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      child: Text(
                        label,
                        style: context.typo.settingsTileLabel.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  // 눌림은 줄 전체가 받는다 — 스위치는 상태만 그린다
                  IgnorePointer(
                    child: Switch(
                      value: value,
                      onChanged: (_) {},
                      activeThumbColor: Colors.white,
                      activeTrackColor: colors.brandOrange,
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

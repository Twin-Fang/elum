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
    this.isInCard = false,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// 흰 묶음 카드 안의 줄이다 (Figma `1532:7501`). 줄 높이·여백·글자는 [SettingsTile] 의 같은 모양을 따르고 토글은 시안 모양을 쓴다.
  final bool isInCard;

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
            constraints: BoxConstraints(
              minHeight: (isInCard ? SettingsTile.cardHeight : SettingsTile.height).h,
            ),
            child: Padding(
              padding: isInCard
                  ? EdgeInsets.only(
                      left: SettingsTile.cardPadLeft.w,
                      right: SettingsTile.cardPadRight.w,
                    )
                  : EdgeInsets.symmetric(horizontal: SettingsTile.padH.w),
              child: Row(
                children: [
                  Expanded(
                    // 줄이 늘어날 때 위아래가 붙지 않게 글에만 여백을 둔다.
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      child: Text(
                        label,
                        style: context.typo.settingsTileLabel.copyWith(
                          color: isInCard ? colors.settingsCardLabel : colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  // 눌림은 줄 전체가 받는다 — 스위치는 상태만 그린다
                  IgnorePointer(
                    child: isInCard
                        ? SettingsToggle(isOn: value)
                        : Switch(
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

/// 설정 묶음 카드의 켜고 끄는 토글 (Figma `1532:7619`: 56×28 알약, 안쪽 여백 4, 흰 동그라미 20)
///
/// 누름은 줄 전체가 받으므로 이 위젯은 상태만 그린다.
class SettingsToggle extends StatelessWidget {
  const SettingsToggle({super.key, required this.isOn});

  final bool isOn;

  static const width = 56.0;
  static const height = 28.0;
  static const _inset = 4.0;
  static const _thumb = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: width.w,
      height: height.h,
      padding: EdgeInsets.all(_inset.w),
      decoration: BoxDecoration(
        // 꺼짐 색은 시안에 없다 - 빈 칸 색(`textPlaceholder`)을 쓴다
        color: isOn ? colors.settingsToggleOn : colors.textPlaceholder,
        borderRadius: BorderRadius.circular((height / 2).r),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 150),
        alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: _thumb.w,
          height: _thumb.w,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

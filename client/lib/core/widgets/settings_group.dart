import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/l10n_context.dart';
import '../text/keep_words.dart';
import '../theme/theme_context_ext.dart';
import 'settings_tile.dart';

/// 설정 줄 묶음: 머리 글 > 흰 카드(줄 사이 가는 선) > 꼬리 설명.
/// iOS 설정의 inset grouped 모양. 줄은 [SettingsTile] 등 기존 위젯을 그대로 넣는다.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.hasDividers = true,
  });

  final List<Widget> children;

  /// 카드 위 작은 회색 제목 (예: `초대`). 없으면 자리도 없다.
  final String? header;

  /// 카드 아래 작은 설명 (예: 누르면 무슨 일이 생기는지).
  final String? footer;

  /// 줄 사이 가는 선. 설정 메인 시안(`1532:7501`)은 선 없이 줄만 이어진다.
  final bool hasDividers;

  /// 머리·꼬리 글과 카드 사이 간격.
  static const _labelGap = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final labelStyle = context.typo.bodySmall.copyWith(color: colors.textSecondary, height: 1.4);
    final header = this.header;
    final footer = this.footer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null)
          Padding(
            padding: EdgeInsets.fromLTRB(SettingsTile.padH.w, 0, SettingsTile.padH.w, _labelGap.h),
            child: Text(header, style: labelStyle),
          ),
        // 눌림 반응·스피너가 둥근 모서리 밖으로 새지 않게 자른다.
        ClipRRect(
          borderRadius: BorderRadius.circular(context.space.cardRadius.r),
          child: ColoredBox(
            color: colors.settingsGroupBg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  // 줄 사이 선은 글자 시작선부터 긋는다 (iOS 와 같다).
                  if (i > 0 && hasDividers)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: SettingsTile.padH.w,
                      color: colors.settingsGroupDivider,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: EdgeInsets.fromLTRB(SettingsTile.padH.w, _labelGap.h, SettingsTile.padH.w, 0),
            // 긴 설명이 단어 중간에서 꺾이지 않게 어절 단위로 줄바꿈한다.
            child: Text(
              keepWords(footer, locale: context.appLocale),
              semanticsLabel: footer,
              style: labelStyle,
            ),
          ),
      ],
    );
  }
}

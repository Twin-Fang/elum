import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/theme_context_ext.dart';

/// 입력 필드. Figma 기준 344×68 / radius 20 / 흰 배경 + 1px 테두리.
///
/// 왼쪽 아이콘은 선택이다. 아이콘이 붙으면 텍스트가 좌측 정렬로 바뀐다.
///
/// Figma 204:991 `온보딩_이름` 명세:
/// - 필드 크기: 344×68
/// - 내부 패딩: 좌우 16px, 상하 24px (텍스트가 필드 상단에서 24px 아래 위치)
/// - 아이콘 크기: 40×40 / 왼쪽 여백 14px / 오른쪽 여백 12px
class ElumTextField extends StatelessWidget {
  const ElumTextField({
    super.key,
    required this.hintText,
    this.controller,
    this.onChanged,
    this.leadingIconAssetPath,
    this.explicitTextAlign,
  });

  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  /// 필드 왼쪽에 붙는 SVG 아이콘 경로. `AppAssets.inputFieldIcon*`을 넘긴다.
  /// null이면 아이콘 영역 자체가 생기지 않는다.
  final String? leadingIconAssetPath;

  /// 정렬을 강제로 지정할 때만 넘긴다.
  /// 평소에는 null로 두고 [resolvedTextAlign]의 판단에 맡긴다.
  final TextAlign? explicitTextAlign;

  /// Figma 아이콘 크기 (40×40) — 좌표에서 역산한 값이라 상수로 고정한다
  static const _leadingIconSize = 40.0;

  /// 필드 좌측(x=24) → 아이콘 좌측(x=38)
  static const _leadingIconLeftGap = 14.0;

  /// 아이콘 우측(x=78) → 텍스트 좌측(x=90)
  static const _leadingIconRightGap = 12.0;

  /// 아이콘이 있으면 좌측, 없으면 중앙 정렬.
  /// 아이콘은 왼쪽에 붙는데 텍스트만 가운데 뜨는 조합은 디자인상 존재하지 않으므로
  /// 호출부가 매번 정렬을 넘기게 하지 않는다.
  TextAlign get resolvedTextAlign =>
      explicitTextAlign ??
      (leadingIconAssetPath != null ? TextAlign.left : TextAlign.center);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    return SizedBox(
      height: space.fieldH,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textAlign: resolvedTextAlign,
        textAlignVertical: TextAlignVertical.center,
        style: context.typo.input.copyWith(color: colors.textPrimary),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: context.typo.input.copyWith(color: colors.textPlaceholder),
          filled: true,
          fillColor: colors.surface,
          contentPadding: EdgeInsets.symmetric(horizontal: space.md, vertical: 24),
          prefixIcon: _buildLeadingIcon(),
          // 기본 최소폭 48이 적용되면 Figma 좌표가 밀린다
          prefixIconConstraints: const BoxConstraints(),
          border: _border(colors.border, space.fieldRadius),
          enabledBorder: _border(colors.border, space.fieldRadius),
          focusedBorder: _border(
            colors.goalSelectedBorder,
            space.fieldRadius,
            width: space.selectedBorderWidth,
          ),
        ),
      ),
    );
  }

  Widget? _buildLeadingIcon() {
    final assetPath = leadingIconAssetPath;
    if (assetPath == null) return null;

    return Padding(
      padding: EdgeInsets.only(
        left: _leadingIconLeftGap.w,
        right: _leadingIconRightGap.w,
      ),
      child: SvgPicture.asset(
        assetPath,
        width: _leadingIconSize.w,
        height: _leadingIconSize.w,
      ),
    );
  }

  OutlineInputBorder _border(Color color, double radius, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

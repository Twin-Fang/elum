import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/theme_context_ext.dart';

/// 입력 필드. Figma 기준 344×68 / radius 20 / 흰 배경 + 1px 테두리.
///
/// **한 줄 전용이다.** 높이 68이 Figma 명세로 고정돼 있어 두 번째 줄은 화면에
/// 보이지도 않는다. 여러 줄 입력이 필요하면 이 위젯을 쓰지 말고 별도로 만든다
/// (일과 입력은 `routine_input_screen`이 자체 TextField를 쓴다).
///
/// Figma 204:991 `온보딩_이름` 명세 (필드 좌상단 기준 상대좌표):
/// - 필드 344×68 / radius 20
/// - 텍스트 20sp, 상하 여백 각 24 → **수직 중앙**이므로 패딩이 아니라 정렬로 맞춘다
///
/// 왼쪽 아이콘(leadingIconAssetPath)은 있었으나 Figma 개정으로 제거됐다 (이슈 #83).
/// placeholder는 Figma상 필드 좌측 정렬이다(x=48, 필드는 x=24 시작 → 좌측 패딩 24).
class ElumTextField extends StatelessWidget {
  const ElumTextField({
    super.key,
    required this.hintText,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.explicitTextAlign,
  });

  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  /// 키보드의 완료(리턴) 키를 눌렀을 때. null이면 키보드만 닫힌다.
  final ValueChanged<String>? onSubmitted;

  /// 정렬을 강제로 지정할 때만 넘긴다. null이면 좌측 정렬(디자인 기본)이다.
  final TextAlign? explicitTextAlign;

  TextAlign get resolvedTextAlign => explicitTextAlign ?? TextAlign.start;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    return SizedBox(
      height: space.fieldH.h,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textAlign: resolvedTextAlign,
        textAlignVertical: TextAlignVertical.center,
        // 부모(SizedBox 68)를 꽉 채운다.
        //
        // ⚠️ expands가 없으면 TextField는 **콘텐츠 높이만큼만** 차지한다.
        // filled 배경도 그만큼만 칠해져 흰 박스가 68이 아니라 46으로 나온다
        // (실측: y=280~326). vertical 패딩으로 늘리려 하면 콘텐츠+패딩이
        // 68을 넘겨 반대로 잘린다 — 높이는 부모가, 정렬은 center가 맡는 게 맞다.
        expands: true,
        maxLines: null,
        minLines: null,
        // ⚠️ 아래 3줄이 없으면 리턴키가 줄바꿈이 된다.
        //
        // expands: true는 maxLines/minLines가 반드시 null일 것을 요구하는데,
        // Flutter는 maxLines가 null이면 이 필드를 여러 줄 입력으로 추론해
        // keyboardType을 multiline, textInputAction을 newline으로 잡는다.
        // 그러면 이름에 개행이 들어가고, 68 고정 높이라 둘째 줄은 보이지도 않아
        // 글자가 사라진 것처럼 보인다. 높이 때문에 넣은 expands의 부작용이므로
        // 세 축을 모두 명시해 추론을 끊는다. 하나만 지정하면 나머지가 여전히
        // maxLines: null을 보고 multiline으로 추론한다.
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.done,
        // 소프트키보드가 아닌 경로(붙여넣기·하드웨어 키보드·일부 IME)로 들어오는
        // 개행까지 막는다. textInputAction만으로는 이 경로가 안 막힌다.
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\n'))],
        style: context.typo.input.copyWith(color: colors.textPrimary),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: context.typo.input.copyWith(color: colors.textPlaceholder),
          filled: true,
          fillColor: colors.surface,
          // 세로 패딩을 주지 않는다 — expands + textAlignVertical.center가
          // 이미 Figma의 수직 중앙(상하 여백 각 24)을 만든다.
          contentPadding: EdgeInsets.symmetric(horizontal: space.md.w),
          border: _border(colors.border, space.fieldRadius.r),
          enabledBorder: _border(colors.border, space.fieldRadius.r),
          focusedBorder: _border(
            colors.goalSelectedBorder,
            space.fieldRadius.r,
            width: space.selectedBorderWidth,
          ),
        ),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_shake.dart';
import '../../../../core/widgets/elum_spinner.dart';
import '../../domain/link_code.dart';
import 'code_boxes.dart';

/// 여섯 글자 코드 입력 — 보이는 여섯 칸 + 화면에 보이지 않는 실제 입력칸 + 보내는 중 스피너.
///
/// 입력 상태(컨트롤러·포커스·오류·보내는 중)와 제출은 화면이 들고, 이 위젯은 그리기만 한다.
/// 부모가 `crossAxisAlignment.stretch` 인 Column 이라는 전제다.
class CodeEntryField extends StatelessWidget {
  const CodeEntryField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.value,
    required this.semanticsLabel,
    required this.onTap,
    required this.failCount,
    this.hasError = false,
    this.sending = false,
    this.enabled = true,
    this.figma = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// 지금까지 친 글자. 칸에 그려지고 낭독기에는 값으로 읽힌다.
  final String value;

  /// 낭독기가 읽는 이름. 실제 입력칸은 투명이라 키보드를 여는 길은 이 여섯 칸뿐이다.
  final String semanticsLabel;

  /// 칸을 눌렀을 때. null 이면 눌러도 고쳐지지 않는다.
  final VoidCallback? onTap;

  /// 값이 커질 때마다 칸이 흔들린다 (틀렸을 때).
  final int failCount;

  final bool hasError;

  /// 보내는 중이면 칸 아래에 스피너를 보인다.
  final bool sending;

  /// 숨은 입력칸을 받을지.
  final bool enabled;

  /// 시안(`CodeBoxes.figma`) 모양의 칸을 쓸지.
  final bool figma;

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          button: true,
          label: semanticsLabel,
          value: value,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: AppShake(
              trigger: failCount,
              // 칸마다 글자를 따로 읽으면 한 글자씩 끊겨 들린다 — 위 값 하나로
              // 읽힌다. 바깥에서 빼면 누름 동작까지 함께 빠져 안쪽에서 뺀다.
              child: ExcludeSemantics(
                child: figma
                    ? CodeBoxes.figma(value: value, hasError: hasError)
                    : CodeBoxes(value: value, hasError: hasError),
              ),
            ),
          ),
        ),
        if (sending) ...[
          SizedBox(height: space.lg),
          Center(child: ElumSpinner(size: space.lg.w)),
        ],
        // 화면에 보이지 않는 실제 입력칸. 시스템 키보드를 쓰되 자동완성·자동수정을 끈다 —
        // 켜 두면 영문 여섯 자를 단어로 고쳐 버린다.
        SizedBox(
          height: 0,
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              keyboardType: TextInputType.visiblePassword,
              // 공백·하이픈을 끼워 쳐도 받아준다 (서버도 받는다)
              maxLength: LinkCode.length + 2,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 \-]')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

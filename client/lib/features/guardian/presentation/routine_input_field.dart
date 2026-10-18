import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'routine_send_button.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/theme_context_ext.dart';

/// 반투명 유리 입력창 (Figma 362×52, r20).
///
/// 배경이 움직이므로 `backdropFilter` 너머 색이 저절로 흐른다.
/// 유리 효과 자체를 애니메이션하지 않는다.
class RoutineInputField extends StatefulWidget {
  const RoutineInputField({
    super.key,
    required this.controller,
    required this.canSubmit,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool canSubmit;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  State<RoutineInputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<RoutineInputField> {
  /// **누르면 안내 문구를 지운다** (시안 `238:1643` → `262:3074`).
  ///
  /// 커서가 들어온 순간부터는 쓰는 중이라 안내가 자리만 차지한다.
  /// 비우면 다시 나타나므로 무엇을 쓰는 칸인지 잊을 일은 없다.
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: space.buttonMarginH),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(space.cardRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            constraints: BoxConstraints(minHeight: 52.h),
            // 위아래도 18이다 (시안 `238:1723`). `space.sm`(12)을 쓰고 있어
            // 글자가 7 위에 붙어 있었다.
            // 글자 쪽은 18, 보내기 단추 쪽은 9다 — 시안 원이 오른쪽에서
            // 9 안쪽에 선다 (`262:4106`). 양쪽 18로 두면 단추가 9 안으로 들어간다.
            padding: EdgeInsets.fromLTRB(18.w, 18.h, 9.w, 18.h),
            decoration: BoxDecoration(
              color: colors.glassSurface,
              borderRadius: BorderRadius.circular(space.cardRadius),
              boxShadow: [
                BoxShadow(
                  color: colors.glassShadow,
                  blurRadius: 5.w,
                  offset: Offset(0, 2.h),
                ),
              ],
            ),
            child: Row(
              // **아래 맞춤이다.** 시안(`262:4106`)은 글자가 위에서부터 쌓이고
              // 보내기 단추가 아래에 붙는다. 가운데로 두면 두 줄일 때 단추가
              // 11 올라간다. 한 줄일 때는 둘 다 같은 높이라 차이가 없다.
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    onChanged: widget.onChanged,
                    maxLines: 4,
                    minLines: 1,
                    style: context.typo.promptBody.copyWith(
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration.collapsed(
                      // 시안(238:1723) 문구 그대로. `적어주세요`로 바꿔 두었던 것을 되돌린다.
                      hintText: _focusNode.hasFocus
                          ? ''
                          : context.l10n.routineInputHint,
                      // 플레이스홀더는 입력 텍스트(promptBody, w500)보다 가늘다 (Figma style_7YRXS7)
                      hintStyle: context.typo.promptPlaceholder.copyWith(
                        color: colors.promptMuted,
                      ),
                    ),
                  ),
                ),
                // 입력이 있을 때만 나타난다 (Figma 262:4106)
                if (widget.canSubmit) ...[
                  SizedBox(width: space.xs),
                  RoutineSendButton(onTap: widget.onSubmit),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

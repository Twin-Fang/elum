import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/theme_context_ext.dart';

/// OS 시스템 숫자 키패드를 띄우는 보이지 않는 입력 필드.
///
/// 자체 키패드를 그리지 않는 이유: iOS·Android 각각의 입력 관습(햅틱, 접근성
/// 낭독, 외부 키보드, 붙여넣기)을 전부 다시 구현해야 한다. 시스템 키패드를 쓰면
/// OS가 알아서 해준다. 화면에는 [PinDots]로 자릿수만 보여준다.
///
/// 필드 자체는 보이지 않게 두되 **크기를 0으로 만들지 않는다.** 0이면 일부
/// 플랫폼에서 포커스를 받지 못해 키패드가 올라오지 않는다.
class PinInputField extends StatelessWidget {
  const PinInputField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.maxLength,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: Opacity(
        opacity: 0,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(maxLength),
          ],
          // 키패드의 완료 버튼으로 화면을 닫아버리면 입력을 이어갈 수 없다
          showCursor: false,
          enableInteractiveSelection: false,
        ),
      ),
    );
  }
}

/// 입력된 자릿수를 점으로 표시한다.
///
/// Figma `Group 22`(238:1996) — 20×20 점 4개, x=109부터 52 간격.
/// 점 폭이 20이므로 사이 여백은 32다.
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.length, required this.filled});

  /// Figma 실측 — 점 지름 20
  static const _size = 20.0;

  /// 점 사이 여백 (좌표 간격 52 - 점 지름 20)
  static const _gap = 32.0;

  final int length;
  final int filled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < length; i++) ...[
          if (i > 0) const SizedBox(width: _gap),
          Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // 채워진 점은 진하게, 빈 점은 Figma의 회색(#CDC8C3)
              color: i < filled ? colors.textPrimary : colors.pinDotEmpty,
            ),
          ),
        ],
      ],
    );
  }
}

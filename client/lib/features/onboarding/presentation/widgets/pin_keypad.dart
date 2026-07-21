import 'package:flutter/material.dart';

import '../../../../core/theme/theme_context_ext.dart';

/// PIN 입력 키패드. 이 화면에서만 쓰이므로 core로 올리지 않는다.
class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  /// 지우기 키를 나타내는 내부 표식. 화면에는 아이콘으로 그린다.
  static const _backspaceKey = 'backspace';

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', _backspaceKey],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in _rows)
          Row(
            children: [
              for (final key in row)
                Expanded(child: _key(context, key)),
            ],
          ),
      ],
    );
  }

  Widget _key(BuildContext context, String key) {
    if (key.isEmpty) return const SizedBox(height: 64);

    final isBackspace = key == _backspaceKey;

    return SizedBox(
      // 터치 타겟을 넉넉히 둔다
      height: 64,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isBackspace ? onBackspace : () => onDigit(key),
          borderRadius: BorderRadius.circular(context.space.cardRadius),
          child: Center(
            // 지우기는 글리프 대신 아이콘을 쓴다. 폰트에 없는 문자면 두부가 나온다.
            child: isBackspace
                ? Icon(
                    Icons.backspace_outlined,
                    color: context.colors.textPrimary,
                  )
                : Text(
                    key,
                    style: context.typo.headline.copyWith(
                      color: context.colors.textPrimary,
                    ),
                  ),
          ),
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

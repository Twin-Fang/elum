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

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', '⌫'],
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

    final isBackspace = key == '⌫';

    return SizedBox(
      // 터치 타겟을 넉넉히 둔다
      height: 64,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isBackspace ? onBackspace : () => onDigit(key),
          borderRadius: BorderRadius.circular(context.space.cardRadius),
          child: Center(
            child: Text(
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
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.length, required this.filled});

  final int length;
  final int filled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < length; i++)
          Container(
            width: 16,
            height: 16,
            margin: EdgeInsets.symmetric(horizontal: context.space.xs),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? colors.highlightBorder : colors.border,
            ),
          ),
      ],
    );
  }
}

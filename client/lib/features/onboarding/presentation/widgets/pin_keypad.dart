import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_motion.dart';
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
      height: 1.h,
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
          if (i > 0) SizedBox(width: _gap.w),
          // 점은 원이라 가로세로 모두 .w — .h를 섞으면 타원이 된다
          Container(
            width: _size.w,
            height: _size.w,
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

/// 점 아래 별도 줄의 틀림 안내: 진한 글씨, 경고색 없음 (아이도 보는 화면)
///
/// 안내가 없을 때도 한 줄 자리를 비워 둔다 — 안내가 뜰 때 아래 글자 버튼이 밀려 튀지 않게
class PinErrorMessage extends StatelessWidget {
  const PinErrorMessage({super.key, required this.message});

  /// null 이면 안내 없음
  final String? message;

  @override
  Widget build(BuildContext context) {
    final isVisible = message != null;
    return Padding(
      padding: EdgeInsets.only(top: context.space.md.h),
      // 바뀌면 낭독기가 바로 읽는다 (점만 흔들리면 화면을 못 보는 사용자는 모른다)
      child: Semantics(
        liveRegion: true,
        child: AnimatedOpacity(
          opacity: isVisible ? 1 : 0,
          duration: AppMotion.fast,
          child: Text(
            message ?? ' ',
            textAlign: TextAlign.center,
            style: context.typo.body.copyWith(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// 암호 확인 중 점 깜박임 (확인이 끝날 때까지 반복)
///
/// 꺼져 있으면 자식을 그대로 둔다. 동작 줄이기가 켜져 있으면 깜박이지 않고 흐리게만 둔다
class PinVerifyingPulse extends StatefulWidget {
  const PinVerifyingPulse({
    super.key,
    required this.isVerifying,
    required this.child,
  });

  final bool isVerifying;
  final Widget child;

  @override
  State<PinVerifyingPulse> createState() => _PinVerifyingPulseState();
}

class _PinVerifyingPulseState extends State<PinVerifyingPulse>
    with SingleTickerProviderStateMixin {
  /// 깜박임 가장 흐린 불투명도 (점이 사라져 보이지 않을 만큼)
  static const _dimmestOpacity = 0.35;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  );

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(PinVerifyingPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVerifying != widget.isVerifying) _syncPulse();
  }

  /// 확인 중이면 흐린 쪽(0)부터 반복 (첫 프레임부터 흐려 보이게), 끝나면 멈춤
  void _syncPulse() {
    if (widget.isVerifying) {
      _pulse
        ..value = 0
        ..repeat(reverse: true);
    } else {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVerifying) return widget.child;
    if (MediaQuery.disableAnimationsOf(context)) {
      return Opacity(opacity: _dimmestOpacity, child: widget.child);
    }
    return FadeTransition(
      opacity: Tween<double>(begin: _dimmestOpacity, end: 1).animate(_pulse),
      child: widget.child,
    );
  }
}

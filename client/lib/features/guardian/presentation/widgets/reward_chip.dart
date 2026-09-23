import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';

/// 최근에 쓴 보상 칩 (이슈 #239 · 시안 `1082:4717`).
///
/// 일과 입력 화면의 추천 칩과 **같은 유리 칩**이다 — 흰 50% · r20 · 10×16.
/// 시안(#380)은 칩에 이모지를 붙이지 않고, 고른 칩을 따로 칠하지도 않는다
/// (`1082:4709`와 `1082:4801`의 칩 자리가 픽셀까지 같다). 누르면 글자가
/// 입력칸으로 올라가고, 거기서 고른 것이 보인다.
///
/// 프리셋 칩을 나열하던 것은 #241 에서 걷어냈다 — **보상은 보호자가 자기 말로
/// 적는 것**이지 넷 중에 고르는 것이 아니다. 여기 남은 것은 "전에 쓴 걸 다시
/// 쓰기"뿐이다.
class RewardChip extends StatelessWidget {
  const RewardChip({super.key, required this.label, required this.onTap});

  /// 칩 사이 가로 간격 (시안 195.5 → 201.5)
  static const gapH = 6.0;

  /// 줄 사이 세로 간격 (시안 523 → 531)
  static const gapV = 8.0;

  static const _padV = 10.0;
  static const _padH = 16.0;

  /// 유리 흐림 — 시안 `Frame 9`의 BACKGROUND_BLUR 10.
  static const _blur = 10.0;

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(context.space.cardRadius);

    return AppPressable(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: _padV.h,
              horizontal: _padH.w,
            ),
            decoration: BoxDecoration(
              color: colors.glassChip,
              borderRadius: radius,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typo.chipLabel.copyWith(color: colors.chipLabel),
            ),
          ),
        ),
      ),
    );
  }
}

/// 보상을 적는 유리 입력칸 (이슈 #239 · 시안 `1082:4730`).
///
/// **이 화면의 주인공이다.** `젤리 먹기`처럼 그 집에서만 통하는 말이 진짜
/// 보상이라, 프리셋에서 고르지 않고 보호자가 자기 말로 적는다.
///
/// 시안은 일과 입력 화면(`238:1847`)의 입력칸을 **그대로 복제**했다 —
/// 362×52 · r20 · 흰 60% · 그림자(0,2) 5 · 배경블러 10 · 안쪽 18.
class RewardInputField extends StatelessWidget {
  const RewardInputField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  /// 보상 문구 최대 길이. 이룸이 화면 배너 한 줄에 들어가야 한다.
  static const maxLength = 30;

  static const _padH = 18.0;

  /// 한 줄 칸이라 높이를 박는다. 위아래 18 + 글자로 쌓으면 글줄 높이(1.1)
  /// 때문에 53.6이 되어 아래 칩이 통째로 2 내려간다 (대조 렌더에서 잰 값).
  static const _height = 52.0;
  static const _blur = 10.0;
  static const _shadowBlur = 5.0;
  static const _shadowDy = 2.0;

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(context.space.cardRadius);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
        child: Container(
          height: _height.h,
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.symmetric(horizontal: _padH.w),
          decoration: BoxDecoration(
            color: colors.glassSurface,
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: colors.glassShadow,
                blurRadius: _shadowBlur.w,
                offset: Offset(0, _shadowDy.h),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            // 글자 수 표시(`12/30`)는 시안에 없다 — 세지 않고 막기만 한다.
            inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
            textInputAction: TextInputAction.done,
            // 시안(`1082:4823`)은 적은 글자도 안내와 같은 16/400 이다.
            // 일과 입력(w500)과 다르다.
            style: context.typo.promptPlaceholder.copyWith(
              color: colors.textPrimary,
            ),
            decoration: InputDecoration.collapsed(
              hintText: '예) 유튜브 10분 보기',
              hintStyle: context.typo.promptPlaceholder.copyWith(
                color: colors.promptMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/theme_context_ext.dart';

/// "지난번에 이걸로" 안내.
///
/// 로그인 수단이 여럿이면 무엇을 썼는지 잊는다. 다른 것으로 들어오면 별개 계정이
/// 생겨 아이 정보가 사라진 것처럼 보인다. 그것을 막는 장치다.
/// `지난번에 이걸로 로그인했어요` — 마지막으로 쓴 제공자 위에 붙는다.
///
/// **글자 뒤에 옅은 알약을 깐다.** 이 문구는 병아리 그림 위에 얹히는데 회색
/// 글자라 그냥 두면 묻힌다. 안드로이드에서는 얼굴을 그리므로 부리와
/// 정확히 겹쳐 `이걸로` 가 읽히지 않는다 — 부리 y614~638, 문구 y623~633.
/// iOS 도 노란 몸통 위라 대비가 좋지 않아 **양쪽 다** 깐다.
///
/// 반투명이라 뒤 그림이 비쳐 덧댄 것처럼 보이지 않는다.
/// 제공자 버튼 위에 `최근 로그인` 알약을 얹는 자리.
///
/// Figma `로그인_iOS`(238:1808) 실측 — 알약 **91×28 · r20**, 버튼 **우측에서 16**,
/// 버튼 상단에서 **위로 10** 겹친다. 배경은 `#FFFADC` 투명도 50%이라 아래 버튼
/// 색이 비쳐, 세 제공자에서 각각 다른 색으로 보인다.
///
/// **줄을 따로 차지하지 않는다.** 이전 구현은 버튼 위에 한 줄을 깔아, 최근 로그인이
/// 있을 때만 버튼 묶음이 통째로 밀렸다 — 누르려던 자리가 움직인다. 버튼 간격이
/// 12라 위로 10 겹쳐도 레이아웃은 그대로다.
///
/// [show]가 거짓이면 버튼만 그대로 내보낸다 — `Stack`을 세우지 않는다.
class LoginLastUsedSlot extends StatelessWidget {
  const LoginLastUsedSlot({super.key, required this.show, required this.child});

  final bool show;
  final Widget child;

  /// 시안 실측 — 알약 91×28 · r20.
  static const _pillWidth = 91.0;
  static const _pillHeight = 28.0;
  static const _pillRadius = 20.0;

  /// 글자가 알약 가장자리에 붙지 않게 하는 좌우 여백. 글꼴 1.0 에서는 최소 폭 안에 묻힌다.
  static const _pillPadding = 8.0;

  /// 버튼 우측에서 16 · 버튼 위로 10.
  static const _right = 16.0;
  static const _top = 10.0;

  @override
  Widget build(BuildContext context) {
    if (!show) return child;

    return Stack(
      // 알약이 버튼 위로 삐져나온다. 자르면 시안과 달라진다.
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: _right.w,
          top: -_top.h,
          child: Container(
            // 시안 91×28 은 **최소 크기**다. 글꼴이 커져 글자가 들어가지 않으면
            // 알약이 자란다 — 고정이면 글자가 줄바꿈돼 잘렸다.
            constraints: BoxConstraints(
              minWidth: _pillWidth.w,
              minHeight: _pillHeight.h,
            ),
            padding: EdgeInsets.symmetric(horizontal: _pillPadding.w),
            decoration: BoxDecoration(
              color: context.colors.loginLastUsedBg,
              borderRadius: BorderRadius.circular(_pillRadius.r),
            ),
            // 글자 크기만큼만 차지하고 알약 안 가운데에 둔다.
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                context.l10n.loginLastUsed,
                maxLines: 1,
                softWrap: false,
                style: context.typo.lastLoginBadge.copyWith(
                  color: context.colors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/theme_context_ext.dart';
import 'show_failure.dart';

/// 당겨서 새로고침 단일 위젯: 받기 > 실패면 실패 팝업(에러 코드), 보이던 내용은 그대로
///
/// [child] 는 세로 스크롤이어야 하고, 짧은 내용도 당겨지게 [physics] · [calmPhysics] 중 하나를 준다.
class ElumPullToRefresh extends StatelessWidget {
  const ElumPullToRefresh({
    super.key,
    required this.onRefresh,
    required this.failureMessage,
    required this.failureCode,
    required this.child,
  });

  /// 내용이 짧거나 0건이어도 당겨지는 스크롤 (끝 튕김은 기기 기본값)
  static const physics = AlwaysScrollableScrollPhysics();

  /// 이룸이 화면용: 끝에서 튕겨 늘어나지 않고 동그라미만 내려옴 (급격한 흔들림 없음)
  static const calmPhysics = AlwaysScrollableScrollPhysics(
    parent: ClampingScrollPhysics(),
  );

  /// 다시 받기. 던지면 실패로 본다 (받는 중 또 당기면 끝날 때까지 새로 부르지 않음)
  final Future<void> Function() onRefresh;

  /// 서버 문구가 없을 때 실패 팝업 문장
  final String failureMessage;

  /// 서버 코드가 없을 때 실패 팝업에 붙는 코드 (예: `E-HOME`)
  final String failureCode;

  final Widget child;

  Future<void> _refreshOrShowFailure(BuildContext context) async {
    try {
      await onRefresh();
    } catch (error) {
      if (!context.mounted) return;
      // 스피너가 팝업을 기다리지 않게 await 하지 않음
      unawaited(
        showFailure(
          context,
          error,
          fallback: failureMessage,
          fallbackCode: failureCode,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return RefreshIndicator(
      color: colors.textPrimary,
      backgroundColor: colors.surface,
      onRefresh: () => _refreshOrShowFailure(context),
      child: child,
    );
  }
}

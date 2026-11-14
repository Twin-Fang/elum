import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/widgets/elum_guide_panel.dart';
import '../../../core/widgets/elum_spinner.dart';
import '../../../core/widgets/show_failure.dart';
import '../application/ad_reward_flow.dart';
import '../application/credit_start_gate.dart';
import '../application/credit_top_up_entry.dart';
import '../data/credit_repository.dart';
import 'ad_reward_celebration.dart';

/// 광고 보고 크레딧 받기: 대기 팝업 > 광고 > 서버 지급 확인 > 받은 순간 팝업 (실패면 코드 있는 실패 팝업)
///
/// [retry] 가 있으면 받은 순간 팝업 버튼이 그 동작 (`이어서 만들기` 등), 없으면 `확인` 하고 제자리
Future<void> watchAdRewardAndCelebrate(
  BuildContext context,
  WidgetRef ref, {
  CreditTopUpRetry? retry,
}) async {
  final l10n = context.l10n; // await 뒤에서 context 를 읽지 않으려고 미리 잡음
  final flow = ref.read(adRewardFlowProvider);
  final repository = ref.read(creditRepositoryProvider);
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  final stage = ValueNotifier(AdRewardStage.preparing);
  // 광고를 불러오고 서버 확인을 기다리는 동안 뒤 화면을 누를 수 없게 막음
  unawaited(
    showElumGuideDialog<void>(
      context: context,
      builder: (_) => PopScope(canPop: false, child: _WaitPanel(stage: stage)),
    ),
  );

  final result = await flow.run(onStage: (s) => stage.value = s);
  // 대기 팝업 닫기 (부른 화면이 사라졌어도 루트에 남지 않게)
  rootNavigator.pop();
  // 오늘 남은 횟수가 바뀌고 불러 둔 광고는 썼음 > 둘 다 다시 받음 (성공·실패 공통)
  ref.invalidate(adRewardAvailabilityProvider);
  ref.invalidate(rewardedAdPreloadProvider);
  if (!context.mounted) return;

  final failure = result.failure;
  if (failure != null) {
    await showFailureMessage(context, sentence: failure.sentence, code: failure.code);
    return;
  }

  // 서버가 지급한 뒤에야 잔액을 다시 읽음. 그 전에는 어디서도 늘리지 않음
  ref.invalidate(creditSummaryProvider);
  final balance = await _readBalance(repository);
  if (!context.mounted) return;
  final shouldContinue = await showElumGuideDialog<bool>(
    context: context,
    builder: (_) => AdRewardCelebration(
      grantedCredits: result.grantedCredits,
      balance: balance,
      buttonLabel: retry?.label ?? l10n.commonConfirm,
    ),
  );
  if (shouldContinue == true && retry != null) await retry.run();
}

/// 받은 뒤 잔액 (조회 실패 · 크레딧 꺼짐이면 null > 잔액 줄 없이 축하만)
Future<int?> _readBalance(CreditRepository repository) async {
  try {
    final summary = await repository.getMine().timeout(creditStartCheckTimeout);
    return summary.enabled ? summary.available : null;
  } catch (e) {
    AppLogger.error('watchAdRewardAndCelebrate (잔액 조회 실패 — 잔액 줄을 뺀다)', e);
    return null;
  }
}

/// 광고 준비·지급 확인 중 대기 창 (안내 뼈대, 스피너가 그림 자리). 닫을 수 없음 — 끝나면 흐름이 직접 닫음
class _WaitPanel extends StatelessWidget {
  const _WaitPanel({required this.stage});

  final ValueListenable<AdRewardStage> stage;

  /// 스피너 크기 · 선 굵기
  static const _spinnerSize = 32.0;
  static const _spinnerStroke = 3.0;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AdRewardStage>(
      valueListenable: stage,
      builder: (context, value, _) => ElumGuidePanel(
        placement: ElumGuidePlacement.dialog,
        // 앱 기본 스피너 색 (남색) — 주황은 포포 그림 색이라 UI 에 쓰지 않음
        illustration: ElumSpinner(size: _spinnerSize.w, strokeWidth: _spinnerStroke),
        title: switch (value) {
          AdRewardStage.preparing => context.l10n.adRewardPreparing,
          AdRewardStage.confirming => context.l10n.adRewardConfirming,
        },
      ),
    );
  }
}

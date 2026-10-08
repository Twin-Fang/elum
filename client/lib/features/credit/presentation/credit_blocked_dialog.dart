import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../application/ad_reward_flow.dart';
import '../data/credit_repository.dart';
import '../domain/credit_summary.dart';

/// 홈 `새로운 일과 만들기`가 막혔을 때의 안내 + 광고 보고 더 만들기.
///
/// **광고를 제안하는 곳은 여기 하나다.** 일과 만들기 흐름 안·이룸이 화면·보상 연출에는
/// 광고를 두지 않는다(설계 §2) — 이 안내는 흐름에 들어가기 **전**이라 허용된 자리다.
///
/// ⚠️ 시안이 없는 임시 배치다. 기존 팝업 컴포넌트로 만들었고, 시안이
/// 나오면 시안을 따른다.
///
/// 광고 버튼은 서버가 켜 두었고 오늘 횟수가 남았을 때만 보인다([AdRewardFlow.offer]).
/// 지금 운영은 꺼져 있어 이 팝업은 `확인` 하나다. 진행 중인 일과 때문에
/// 막힌 경우에도 광고를 제안하지 않는다 — 크레딧을 늘려도 끝나기 전에는 만들 수 없다.
Future<void> showCreditBlockedDialog(
  BuildContext context,
  WidgetRef ref,
  CreditSummary blocked,
) async {
  final l10n = context.l10n; // await 뒤에서 context 를 읽지 않으려고 미리 잡는다
  // 다 쓴 것이 먼저다 — 진행 중인 것이 끝나도 새로 만들 수 없기 때문이다.
  final generating = blocked.canStartRoutine && blocked.isGeneratingRoutine;
  final flow = ref.read(adRewardFlowProvider);
  final offer = generating ? null : await flow.offer();
  if (!context.mounted) return;

  final wantsAd = await showElumDialog<bool>(
    context: context,
    // 시안 `로그인실패` 변형 모양 — 느낌표 + 두 줄 문장 + 붉은 확인.
    icon: ElumDialogIcon.alert,
    title: generating
        ? l10n.creditBlockedBusy
        : l10n.creditBlockedExhausted(blocked.resetLabel),
    message: offer == null ? null : l10n.creditAdOffer(offer.creditsPerView),
    actions: offer == null
        ? [
            ElumDialogAction<bool>(
              label: l10n.commonConfirm,
              tone: ElumDialogTone.danger,
            ),
          ]
        : [
            ElumDialogAction<bool>(
              label: l10n.commonClose,
              value: false,
              tone: ElumDialogTone.neutral,
            ),
            ElumDialogAction<bool>(
              label: l10n.creditAdWatchMore,
              value: true,
              centerLines: true,
            ),
          ],
  );
  if (wantsAd != true || !context.mounted) return;

  await _watchAd(context, ref, flow);
}

/// 광고를 보여 주고 서버가 지급했는지 확인한다. 끝나면 결과를 알리고 **홈에 남는다** —
/// 일과 만들기로 자동으로 넘기지 않는다(받은 크레딧을 보고 보호자가 정한다).
Future<void> _watchAd(
  BuildContext context,
  WidgetRef ref,
  AdRewardFlow flow,
) async {
  final l10n = context.l10n; // await 뒤에서 context 를 읽지 않으려고 미리 잡는다
  final stage = ValueNotifier(AdRewardStage.preparing);
  // 광고를 불러오고 서버 확인을 기다리는 동안 홈을 누를 수 없게 막는다.
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      useSafeArea: false,
      builder: (_) => PopScope(canPop: false, child: _WaitDialog(stage: stage)),
    ),
  );

  final result = await flow.run(onStage: (s) => stage.value = s);

  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();

  if (result.granted) {
    // 서버가 지급한 뒤에야 잔액을 다시 읽는다. 그 전에는 어디서도 늘리지 않는다.
    ref.invalidate(creditSummaryProvider);
    final n = result.grantedCredits;
    await showElumDialog<void>(
      context: context,
      icon: ElumDialogIcon.success,
      title: n > 0
          ? l10n.creditReceivedTitle(n)
          : l10n.creditReceivedTitleNoCount,
    );
    return;
  }

  final failure = result.failure!;
  await showElumDialog<void>(
    context: context,
    icon: ElumDialogIcon.alert,
    title: failure.sentence,
    code: failure.code,
    actions: [
      ElumDialogAction(label: l10n.commonConfirm, tone: ElumDialogTone.danger),
    ],
  );
}

/// 광고 준비·지급 확인 중 대기 팝업. 닫을 수 없다 — 끝나면 흐름이 직접 닫는다.
class _WaitDialog extends StatelessWidget {
  const _WaitDialog({required this.stage});

  final ValueListenable<AdRewardStage> stage;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: ElumDialogSurface(
        child: ValueListenableBuilder<AdRewardStage>(
          valueListenable: stage,
          builder: (context, value, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32.w,
                height: 32.w,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: colors.brandOrange,
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                switch (value) {
                  AdRewardStage.preparing => context.l10n.adRewardPreparing,
                  AdRewardStage.confirming => context.l10n.adRewardConfirming,
                },
                textAlign: TextAlign.center,
                style: context.typo.dialogTitle.copyWith(
                  color: colors.dialogTitleText,
                ),
              ),
              SizedBox(height: 10.h),
            ],
          ),
        ),
      ),
    );
  }
}

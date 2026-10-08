import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/current_l10n.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../../core/widgets/show_failure.dart';
import '../../../shared/models/reward_preset.dart';
import '../../../shared/models/routine.dart';
import '../application/routine_notifier.dart';
import 'widgets/aurora_background.dart';
import 'widgets/reward_chip.dart';
import 'widgets/routine_flow_scaffold.dart';
import '../../../core/router/pop_or_home.dart';
import '../application/reward_setup_controller.dart';
import '../../../core/router/routes.dart';

/// 최근 보상. 실패하면 빈 목록이라 화면이 칩 자리를 비운다.
final recentRewardsProvider = FutureProvider.autoDispose<List<RecentReward>>(
  (ref) => ref.read(rewardSetupControllerProvider).recentRewards(),
);

/// 보상 설정 — Figma `보호자_보상설정` `1082:4709`(비어 있음) · `1082:4801`(적은 뒤).
///
/// 흐름 자리는 **일과 입력 바로 다음**, 질문 준비 로딩 앞이다 (Figma 섹션
/// `1049:4654` · `docs/03-screens.md` 8-1).
///
/// 일과를 끝내는 힘은 별(⭐) 연출이 아니라 **끝나면 무엇을 받는지**에서 나온다.
/// 배경은 입력 화면의 두 원 색만 바꾼 분홍이며 흐름 공용 배경(`RoutineFlowBackdrop`)이 번진다.
/// 보상은 선택이다 — 건너뛰면 배너 없이 기존 별 연출만 돈다.
class RewardSetupScreen extends ConsumerStatefulWidget {
  const RewardSetupScreen({super.key, this.fromReview = false});

  /// 이 화면의 배경 색 — 분홍 (시안 `1082:4710` Gradient).
  static const aurora = AuroraTone.reward;

  /// `보상이 왜 필요한가요?` 팝업 본문 (시안이 없어 개발에서 정한 문구).
  static String get whyMessage => appL10n.rewardWhyMessage;

  /// 카드 검토 화면에서 뒤늦게 고치러 들어왔는가.
  ///
  /// true면 카드를 만들지 않고 **서버에 보상만 고친 뒤 되돌아간다.**
  /// 건너뛰었던 사람이 나중에 정할 수 있어야 한다.
  final bool fromReview;

  @override
  ConsumerState<RewardSetupScreen> createState() => _RewardSetupScreenState();
}

class _RewardSetupScreenState extends ConsumerState<RewardSetupScreen>
    with LeaveOnceMixin {
  /// 보상 문구. **이 화면의 주인공이다** — 보호자가 자기 말로 적는다.
  final _controller = TextEditingController();

  /// 최근 보상을 다시 골랐을 때 그 프리셋 키를 이어받는다.
  /// 직접 적었으면 `CUSTOM`이다.
  String _presetKey = RewardPreset.custom.key;

  /// 시안이 그린 칩은 넷이다 (2·2). 서버도 넷까지 준다.
  static const _maxChips = 4;

  @override
  void initState() {
    super.initState();
    // 고치러 들어왔으면 지금 값을 채워 둔다 — 빈 화면이면 뭘 정했었는지 알 수 없다.
    final state = ref.read(routineFlowProvider);
    final existing = (state.routine?.rewardText ?? '').trim().isNotEmpty
        ? state.routine!.rewardText
        : state.rewardText;
    if (existing.trim().isEmpty) return;

    _controller.text = existing;
    final key = (state.routine?.rewardPresetKey ?? '').trim().isNotEmpty
        ? state.routine!.rewardPresetKey
        : state.rewardPresetKey;
    if (key.trim().isNotEmpty) _presetKey = key;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 지금 정해진 보상 문구. 비어 있으면 `다음`이 눌리지 않는다.
  String get _rewardText => _controller.text.trim();

  /// 최근에 쓴 것을 그대로 다시 쓴다 — 두 번째 일과부터 탭 한 번이다.
  ///
  /// **프리셋 키를 함께 가져온다.** 키가 빠지면 이룸이 화면의 그림이 ⭐로 바뀐다.
  void _pickRecent(RecentReward recent) {
    setState(() {
      _controller.text = recent.rewardText;
      _presetKey = recent.rewardPresetKey.trim().isEmpty
          ? RewardPreset.custom.key
          : recent.rewardPresetKey;
    });
  }

  /// 손으로 고치면 더 이상 그 프리셋이 아니다.
  void _onTyped(String _) {
    setState(() => _presetKey = RewardPreset.custom.key);
  }

  /// 두 번 누르면 질문 준비 로딩이 두 장 쌓이고 **AI 호출이 두 번 나간다** (E8).
  Future<void> _next() => leaveOnce(() async {
    final notifier = ref.read(routineFlowProvider.notifier);
    dismissKeyboard();

    if (widget.fromReview) {
      final failure = await notifier.updateRewardOnRoutine(
        _rewardText,
        presetKey: _presetKey,
      );
      if (!mounted) return;
      // 저장에 실패해도 화면은 되돌아간다 — 로컬에는 반영됐다. 다만 말은 해 준다.
      // **서버가 이유를 알려줬으면 그 문구가 아래 기본 문구를 이긴다**.
      // 팝업을 닫은 뒤에 돌아간다 — 먼저 돌아가면 팝업이 다음 화면 위에 남는다.
      if (failure != null) {
        await showFailure(
          context,
          failure,
          title: context.l10n.rewardSaveFailedTitle,
          fallback: context.l10n.rewardSaveFailedFallback,
          fallbackCode: 'E-REWARD',
        );
        if (!mounted) return;
      }
      context.popOrHome();
      return;
    }

    notifier.setReward(_rewardText, presetKey: _presetKey);
    // 다음은 질문 준비 로딩이다. 기다리지 않는다 — 풀어 주는 것은
    // 이 화면이 다시 맨 위가 될 때다 ([LeaveOnceMixin]).
    unawaited(context.push(Routes.routineMasking));
  });

  Future<void> _later() => leaveOnce(() async {
    final notifier = ref.read(routineFlowProvider.notifier);
    dismissKeyboard();

    // 카드 검토에서 고치러 왔으면 **정해 둔 보상을 그대로 두고** 돌아간다.
    // 빈 값으로 저장하면 확인도 없이 '젤리 2개'가 지워진다.
    // "나중에"는 지금 안 고친다는 뜻이지 없앤다는 뜻이 아니다.
    if (widget.fromReview) {
      context.popOrHome();
      return;
    }

    notifier.skipReward();
    unawaited(context.push(Routes.routineMasking));
  });

  /// `보상이 왜 필요한가요?` (E14).
  ///
  /// 시안에 누른 뒤 화면이 없어 **개발에서 정한 문구**다. 보호자에게 한 가지만 말한다 — 왜 정해 두면 좋은가. 줄마다
  /// 이유 · 어떤 것이 좋은가 · 안 정해도 된다(되돌릴 수 있다고 먼저 말한다,
  /// `08-design-principles.md` ④). 자문의 "한 달 뒤 선물보다 오늘 받을 수
  /// 있는 것"을 살렸다.
  Future<void> _explain() => showElumDialog<void>(
    context: context,
    title: context.l10n.rewardWhyTitle,
    message: RewardSetupScreen.whyMessage,
    barrierDismissible: true,
    // 360 폭에서 `이룸이 / 가`처럼 낱말 가운데서 꺾였다
    keepWordsInMessage: true,
  );

  @override
  Widget build(BuildContext context) {
    final recents = ref.watch(recentRewardsProvider);

    return RoutineFlowScaffold(
      aurora: RewardSetupScreen.aurora,
      // 여기서 홈으로 나가면 앞서 적은 것까지 사라진다.
      // 카드 만들기 전이라 나가면 적은 것이 남지 않는다. 고치러 온 길은 잃을 것이 없다.
      // 뒤로는 입력으로 한 칸이라 묻지 않는다 — 적은 것이 그대로 남는다.
      leave: widget.fromReview ? null : RoutineLeave.discard,
      onBack: context.popOrHome,
      // 시안은 CTA를 y=675에 둔다 — 약관·목표·추가질문과 같은 자리다.
      pinCtaToFigmaY: true,
      // 크레딧 경고 띠는 두지 않는다. 도움말은 버튼 곁에 남긴다.
      bottomButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ⚠️ 시안은 이 줄을 **가운데가 아니라 x=116**에 둔다 (묶음 116~258,
          // 중심 187 — 화면 중심 196.5보다 9.5 왼쪽). 다른 줄은 모두 가운데라
          // 실수로 보이지만 시안대로 둔다.
          Padding(
            padding: EdgeInsets.only(left: _RewardLayout.helpLeft),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _HelpLink(onTap: _explain),
            ),
          ),
          // 도움말 하단(659) → CTA(675)
          SizedBox(height: _RewardLayout.helpToCta),
          ElumButton(
            label: context.l10n.commonNext,
            onPressed: _rewardText.isEmpty ? null : _next,
          ),
        ],
      ),
      // 건너뛰기를 버튼으로 두지 않는다 — 같은 무게면 무엇이 주 동작인지 흐려진다.
      belowButton: Center(child: _LaterLink(onTap: _later)),
      child: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: _RewardLayout.topToSparkles),
            // 30×36 비정사각형이라 가로 .w / 세로 .h
            SvgPicture.asset(
              AppAssets.iconSparklesLarge,
              width: 30.w,
              height: 36.h,
            ),
            SizedBox(height: _RewardLayout.sparklesToTitle),
            const _Headline(),
            SizedBox(height: _RewardLayout.bodyToInput),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.space.buttonMarginH,
              ),
              child: RewardInputField(
                controller: _controller,
                onChanged: _onTyped,
              ),
            ),
            SizedBox(height: _RewardLayout.inputToChips),
            // 최근에 쓴 보상 — 없으면 자리째 비운다 (빈 칩 틀은 로딩 실패처럼 보인다)
            recents.maybeWhen(
              data: (list) => _RecentChips(
                rewards: list.where((r) => r.isValid).take(_maxChips).toList(),
                onTap: _pickRecent,
              ),
              orElse: () => const SizedBox.shrink(),
            ),
            SizedBox(height: context.space.lg),
          ],
        ),
      ),
    );
  }
}

/// 시안(`1082:4709`)에서 뽑은 세로 간격.
///
/// 시안은 절대 좌표로 그렸고 앱은 간격을 쌓는다. 토큰을 쌓으면 아래로 갈수록
/// 벌어져 좌표의 **차**를 그대로 적어 둔다.
///
/// 시안 절대 y — 상단바 끝 111 · 반짝임 185 · 제목 245 · 부제 323 ·
/// 입력칸 389 · 칩 489 · 도움말 642 · CTA 675 · 나중에 할게요 765.
class _RewardLayout {
  /// 상단바 끝(111) → 반짝임(185).
  static double get topToSparkles => 74.h;

  /// 반짝임 끝(221) → 제목(245).
  static double get sparklesToTitle => 24.h;

  /// 제목 끝(311) → 부제(323).
  static double get titleToBody => 12.h;

  /// 부제 끝(341) → 입력칸(389).
  static double get bodyToInput => 48.h;

  /// 입력칸 끝(441) → 칩(489).
  static double get inputToChips => 48.h;

  /// 도움말 끝(659) → CTA(675).
  static double get helpToCta => 16.h;

  /// 도움말 왼쪽 — 시안 x=116 에서 CTA 여백(16)을 뺀 값.
  static double get helpLeft => (116 - 16).w;
}

/// 반짝임 아래 제목 + 부제 (시안 가운데 정렬).
///
/// 시안 부제에는 이룸이 이름이 없다.
class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      children: [
        Text(
          // 줄바꿈 위치는 시안이 정한 대로다
          context.l10n.rewardHeadlineTitle,
          textAlign: TextAlign.center,
          style: context.typo.promptTitle.copyWith(color: colors.textPrimary),
        ),
        SizedBox(height: _RewardLayout.titleToBody),
        Text(
          context.l10n.rewardHeadlineBody,
          textAlign: TextAlign.center,
          style: context.typo.promptBody.copyWith(color: colors.promptMuted),
        ),
      ],
    );
  }
}

/// 최근 보상 칩 — 시안 2·2 가운데 정렬.
///
/// `Wrap`으로 두면 글자 길이에 따라 줄이 밀린다. 일과 입력의 추천 칩과 같은
/// 짜임(두 개씩 한 줄, 남는 하나는 마지막 줄 가운데)이다.
class _RecentChips extends StatelessWidget {
  const _RecentChips({required this.rewards, required this.onTap});

  final List<RecentReward> rewards;
  final ValueChanged<RecentReward> onTap;

  @override
  Widget build(BuildContext context) {
    if (rewards.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.space.buttonMarginH),
      child: Column(
        children: [
          for (var row = 0; row < rewards.length; row += 2) ...[
            if (row > 0) SizedBox(height: RewardChip.gapV.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final (index, r) in rewards.skip(row).take(2).indexed) ...[
                  if (index > 0) SizedBox(width: RewardChip.gapH.w),
                  Flexible(
                    child: RewardChip(
                      label: r.rewardText,
                      onTap: () => onTap(r),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// `ⓘ 보상이 왜 필요한가요?` (시안 `1082:4800` — 142×17, 가운데).
class _HelpLink extends StatelessWidget {
  const _HelpLink({required this.onTap});

  final VoidCallback onTap;

  /// 물음표 글자 상자 17 (안의 그림은 14) · 글자까지 2.
  static const _iconBox = 17.0;
  static const _icon = 14.0;
  static const _gap = 2.0;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.linkLaterLabel;

    return AppPressable(
      onTap: onTap,
      semanticLabel: context.l10n.rewardWhyTitle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _iconBox.w,
            height: _iconBox.w,
            child: Center(
              child: SvgPicture.asset(
                AppAssets.iconQuestionCircle,
                width: _icon.w,
                height: _icon.w,
              ),
            ),
          ),
          SizedBox(width: _gap.w),
          Flexible(
            child: Text(
              context.l10n.rewardWhyTitle,
              style: context.typo.helpLink.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// `나중에 할게요` — CTA 아래 빠져나가는 길 (시안 `1082:4764`, y=765).
///
/// **높이를 못 박지 않는다.** 16 으로 고정하면 글꼴을 키울 때 글자 아래가 잘리고,
/// OverflowBox 로 넓힌 누름 영역은 부모 상자 밖이라 눌러도 받지 못한다.
/// 글자 높이가 곧 자리다 — 글꼴 1.0 에서는 16 그대로라 시안 자리(765)가 같고,
/// 커지면 자리도 함께 커진다. 누름 영역은 **옆으로만** 넓힌다 (세로를 넓히면 자리가
/// 바뀐다).
class _LaterLink extends StatelessWidget {
  const _LaterLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final colors = context.colors;

    return AppPressable(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: space.md.w),
        child: Text(
          context.l10n.rewardLater,
          textAlign: TextAlign.center,
          style: context.typo.linkLater.copyWith(
            color: colors.linkLaterLabel,
            decoration: TextDecoration.underline,
            decorationColor: colors.linkLaterLabel,
          ),
        ),
      ),
    );
  }
}

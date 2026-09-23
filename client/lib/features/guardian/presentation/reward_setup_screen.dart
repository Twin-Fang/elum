import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../../core/widgets/show_failure.dart';
import '../../../shared/models/reward_preset.dart';
import '../../../shared/models/routine.dart';
import '../application/routine_notifier.dart';
import '../data/routine_repository.dart';
import 'widgets/aurora_background.dart';
import 'widgets/reward_chip.dart';
import 'widgets/routine_flow_scaffold.dart';

/// 최근 보상. 실패하면 빈 목록이라 화면이 칩 자리를 비운다.
final recentRewardsProvider = FutureProvider.autoDispose<List<RecentReward>>(
  (ref) => ref.read(routineRepositoryProvider).getRecentRewards(),
);

/// 보상 설정 — Figma `보호자_보상설정` `1082:4709`(비어 있음) · `1082:4801`(적은 뒤).
///
/// 흐름 자리는 **AI 추가 질문 다음, 카드 생성 전**이다 (#239 · `docs/03-screens.md`
/// 8-1). 새 시안 섹션(`1049:4654`)은 입력 바로 다음에 놓여 있지만 프로토타입
/// 연결이 없어 순서는 바꾸지 않았다 — #380 확인 필요 1.
///
/// ## 왜 이 화면이 필요한가
///
/// 2026-09-13 서울 ABA연구소 자문의 **최대 지적**이 "보상이 통째로 빠져 있다"였다.
/// 일과를 끝내는 힘은 별(⭐) 연출이 아니라 **끝나면 무엇을 받는지**에서 나온다.
///
/// ## 배경이 분홍이다
///
/// 시안은 입력 화면의 두 원을 **색만 바꿔** 그렸다 ([aurora]). 앞 화면에서 넘어올
/// 때 배경은 흐름이 함께 쓰는 한 장(`RoutineFlowBackdrop`)이 그 자리에서 번진다.
///
/// ## 나중에 할 수 있다
///
/// 보상은 선택이다. 건너뛰면 이룸이 화면에 배너를 띄우지 않고 기존 별 연출만
/// 돈다. **필수로 만들면 일과 만들기가 한 단계 더 무거워진다.**
class RewardSetupScreen extends ConsumerStatefulWidget {
  const RewardSetupScreen({super.key, this.fromReview = false});

  /// 이 화면의 배경 색 — 분홍 (시안 `1082:4710` Gradient).
  static const aurora = AuroraTone.reward;

  /// 카드 검토 화면에서 뒤늦게 고치러 들어왔는가 (이슈 #239).
  ///
  /// true면 카드를 만들지 않고 **서버에 보상만 고친 뒤 되돌아간다.**
  /// 건너뛰었던 사람이 나중에 정할 수 있어야 한다.
  final bool fromReview;

  @override
  ConsumerState<RewardSetupScreen> createState() => _RewardSetupScreenState();
}

class _RewardSetupScreenState extends ConsumerState<RewardSetupScreen> {
  /// 보상 문구. **이 화면의 주인공이다** — 보호자가 자기 말로 적는다 (#241).
  final _controller = TextEditingController();

  /// 최근 보상을 다시 골랐을 때 그 프리셋 키를 이어받는다.
  /// 직접 적었으면 `CUSTOM`이다.
  String _presetKey = RewardPreset.custom.key;

  /// 다음 화면으로 넘기는 중인가 (E8).
  ///
  /// 두 번 누르면 카드 생성 로딩이 두 장 쌓이고 **AI 호출이 두 번 나간다.**
  /// 넘어간 화면이 닫혀 이 화면이 다시 맨 위가 되면 풀린다.
  bool _leaving = false;

  /// 직전에 이 화면이 맨 위였는가 — 맨 위로 **돌아온 순간**을 잡는다.
  bool _wasCurrent = true;

  /// 시안이 그린 칩은 넷이다 (2·2). 서버는 지금 셋까지 준다 — #380 확인 필요 2.
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `push`가 돌려주는 Future로 풀지 않는다. 로딩이 검토 화면으로 **교체**되면
    // (pushReplacement) 그 Future는 끝나지 않아, 검토에서 돌아왔을 때 버튼이
    // 죽어 있다. 이 화면이 다시 맨 위가 된 사실로 푼다.
    final isCurrent = ModalRoute.isCurrentOf(context) ?? true;
    if (isCurrent && !_wasCurrent) _leaving = false;
    _wasCurrent = isCurrent;
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

  /// 한 번만 넘긴다. 넘어간 화면이 닫혀 돌아오면 다시 누를 수 있다
  /// ([didChangeDependencies]).
  Future<void> _leaveOnce(Future<void> Function() go) async {
    if (_leaving) return;
    _leaving = true;
    await go();
  }

  Future<void> _next() => _leaveOnce(() async {
    final notifier = ref.read(routineFlowProvider.notifier);
    dismissKeyboard();

    if (widget.fromReview) {
      final failure = await notifier.updateRewardOnRoutine(
        _rewardText,
        presetKey: _presetKey,
      );
      if (!mounted) return;
      // 저장에 실패해도 화면은 되돌아간다 — 로컬에는 반영됐다. 다만 말은 해 준다.
      // **서버가 이유를 알려줬으면 그 문구가 아래 기본 문구를 이긴다** (#352).
      if (failure != null) {
        showFailureSnack(
          context,
          failure,
          fallback: '보상을 저장하지 못했어요',
          fallbackCode: 'E-REWARD',
        );
      }
      context.pop();
      return;
    }

    notifier.setReward(_rewardText, presetKey: _presetKey);
    // 기다리지 않는다 — 풀어 주는 것은 이 화면이 다시 맨 위가 될 때다.
    unawaited(context.push(Routes.routineGenerating));
  });

  Future<void> _later() => _leaveOnce(() async {
    final notifier = ref.read(routineFlowProvider.notifier);
    dismissKeyboard();

    if (widget.fromReview) {
      await notifier.updateRewardOnRoutine('');
      if (mounted) context.pop();
      return;
    }

    notifier.skipReward();
    unawaited(context.push(Routes.routineGenerating));
  });

  /// `보상이 왜 필요한가요?` (E14).
  ///
  /// ⚠️ 시안에 누른 뒤 화면이 없다 — #380 확인 필요 3. 자문(#239)에서 온 문구로
  /// 공통 팝업을 띄워 둔다. 도움말처럼 생긴 줄이 눌러도 아무 일 없으면 고장으로 읽힌다.
  Future<void> _explain() => showElumDialog<void>(
    context: context,
    title: '보상이 왜 필요한가요?',
    message:
        '끝나면 무엇을 받는지 알면 일과를 끝까지 해낼 힘이 생겨요.\n'
        '한 달 뒤 선물보다 오늘 받을 수 있는 것이 더 효과적이에요.',
    barrierDismissible: true,
  );

  @override
  Widget build(BuildContext context) {
    final recents = ref.watch(recentRewardsProvider);

    return RoutineFlowScaffold(
      aurora: RewardSetupScreen.aurora,
      // 여기서 나가면 앞서 만든 답까지 사라진다 (#242).
      confirmExit: !widget.fromReview,
      onBack: () => context.pop(),
      // 시안은 CTA를 y=675에 둔다 — 약관·목표·추가질문과 같은 자리다.
      pinCtaToFigmaY: true,
      bottomButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ⚠️ 시안은 이 줄을 **가운데가 아니라 x=116**에 둔다 (묶음 116~258,
          // 중심 187 — 화면 중심 196.5보다 9.5 왼쪽). 다른 줄은 모두 가운데라
          // 실수로 보이지만 시안대로 둔다 — #380 확인 필요 6.
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
            label: '다음',
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
/// 벌어져(#297) 좌표의 **차**를 그대로 적어 둔다.
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
/// 시안 부제에는 이룸이 이름이 없다 — 옛 화면(`하늘이가 좋아하는 걸…`)과 다르다.
class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      children: [
        Text(
          // 줄바꿈 위치는 시안이 정한 대로다
          '일과가 끝나면\n어떤 보상을 줄까요?',
          textAlign: TextAlign.center,
          style: context.typo.promptTitle.copyWith(color: colors.textPrimary),
        ),
        SizedBox(height: _RewardLayout.titleToBody),
        Text(
          '일과를 완료하는 데 큰 동기가 될 거예요',
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
      semanticLabel: '보상이 왜 필요한가요?',
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
              '보상이 왜 필요한가요?',
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
/// 자리는 글자 높이(16) 그대로 두고 누름 영역만 위아래로 넓힌다. 자리째 키우면
/// CTA가 위로 밀린다 (연결 암호 화면과 같은 방식).
class _LaterLink extends StatelessWidget {
  const _LaterLink({required this.onTap});

  final VoidCallback onTap;

  static const _height = 16.0;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final colors = context.colors;

    return SizedBox(
      height: _height.h,
      child: OverflowBox(
        maxHeight: (_height + space.xs * 2).h,
        child: AppPressable(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(space.xs.h),
            child: Text(
              '나중에 할게요',
              style: context.typo.linkLater.copyWith(
                color: colors.linkLaterLabel,
                decoration: TextDecoration.underline,
                decorationColor: colors.linkLaterLabel,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

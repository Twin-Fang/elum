import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../shared/models/reward_preset.dart';
import '../../../shared/utils/korean_particle.dart';
import '../../../shared/models/routine.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../application/routine_notifier.dart';
import '../data/routine_repository.dart';
import 'widgets/reward_chip.dart';
import 'widgets/routine_flow_scaffold.dart';

/// 최근 보상 3개. 실패하면 빈 목록이라 화면이 섹션을 통째로 숨긴다.
final recentRewardsProvider = FutureProvider.autoDispose<List<RecentReward>>(
  (ref) => ref.read(routineRepositoryProvider).getRecentRewards(),
);

/// 보상(강화물) 정하기 — 화면 8-1 (`docs/03-screens.md` · 이슈 #239).
///
/// **AI 추가 질문 다음, 카드 생성 전**에 선다. 질문에 답하는 맥락이 그대로
/// 이어지는 자리다. 카드를 만든 뒤로 미루면 "이미 다 끝났는데 왜 또"가 된다.
///
/// ## 왜 이 화면이 필요한가
///
/// 2026-09-13 서울 ABA연구소 자문의 **최대 지적**이 "보상이 통째로 빠져 있다"였다.
/// 일과를 끝내는 힘은 별(⭐) 연출이 아니라 **끝나면 무엇을 받는지**에서 나온다.
///
/// ## 건너뛸 수 있다
///
/// 보상은 선택이다. 건너뛰면 이룸이 화면에 배너를 띄우지 않고 기존 별 연출만
/// 돈다. **필수로 만들면 일과 만들기가 한 단계 더 무거워진다.**
class RewardSetupScreen extends ConsumerStatefulWidget {
  const RewardSetupScreen({super.key, this.fromReview = false});

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

  /// 제목(y=131) 아래 여백 — 다른 일과 화면과 같은 리듬.
  static const _headerTop = 114.0;
  static const _titleToSubtitle = 12.0;
  static const _sectionGap = 28.0;
  static const _labelToContent = 12.0;

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

  Future<void> _next() async {
    final notifier = ref.read(routineFlowProvider.notifier);

    if (widget.fromReview) {
      final synced = await notifier.updateRewardOnRoutine(
        _rewardText,
        presetKey: _presetKey,
      );
      if (!mounted) return;
      // 저장에 실패해도 화면은 되돌아간다 — 로컬에는 반영됐다. 다만 말은 해 준다.
      if (!synced) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('보상을 저장하지 못했어요 (E-REWARD)')),
        );
      }
      context.pop();
      return;
    }

    notifier.setReward(_rewardText, presetKey: _presetKey);
    if (mounted) context.push(Routes.routineGenerating);
  }

  Future<void> _skip() async {
    final notifier = ref.read(routineFlowProvider.notifier);

    if (widget.fromReview) {
      await notifier.updateRewardOnRoutine('');
      if (mounted) context.pop();
      return;
    }

    notifier.skipReward();
    if (mounted) context.push(Routes.routineGenerating);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final name = ref.watch(onboardingProvider).childNickname.trim();
    final who = name.isEmpty ? '이룸이' : name;
    final recents = ref.watch(recentRewardsProvider);

    return RoutineFlowScaffold(
      onBack: () => context.pop(),
      bottomButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElumButton(
            label: '다음',
            onPressed: _rewardText.isEmpty ? null : _next,
          ),
          SizedBox(height: space.sm.h),
          // 건너뛰기를 버튼으로 두지 않는다 — 같은 무게면 무엇이 주 동작인지 흐려진다.
          AppPressable(
            onTap: _skip,
            child: Padding(
              padding: EdgeInsets.all(space.xs.h),
              child: Text(
                '건너뛰기',
                style: context.typo.body.copyWith(
                  color: colors.textSecondary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
      // RoutineFlowScaffold는 좌우 여백을 주지 않는다 — 화면이 직접 준다.
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: space.screenH.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: _headerTop.h),
            Text(
              '다 하면\n무엇을 할 수 있나요?',
              style: context.typo.title.copyWith(color: colors.textPrimary),
            ),
            SizedBox(height: _titleToSubtitle.h),
            Text(
              // 조사를 손으로 붙이면 `민준가`가 된다 — 받침을 봐야 한다 (#196).
              // `고르다`가 아니라 `적다` — 프리셋을 걷어냈다 (#241).
              '$who${who.subjectParticle} 좋아하는 걸 적어주세요',
              style: context.typo.body.copyWith(color: colors.textSecondary),
            ),

            // 🔴 입력칸이 주인공이다 (#241). 프리셋에서 고르는 것이 아니라
            // `젤리 먹기`처럼 그 집에서만 통하는 말을 적는 자리다.
            SizedBox(height: _sectionGap.h),
            RewardInputField(
              controller: _controller,
              onChanged: (v) {
                _onTyped(v);
              },
            ),

            // 최근에 쓴 보상 — 없으면 섹션째 사라진다 (빈 영역은 로딩 실패처럼 보인다)
            recents.maybeWhen(
              data: (list) {
                final valid = list.where((r) => r.isValid).take(3).toList();
                if (valid.isEmpty) return const SizedBox.shrink();
                return _section(
                  context,
                  '최근 보상',
                  Wrap(
                    spacing: RewardChip.gap.w,
                    runSpacing: RewardChip.gap.h,
                    children: [
                      for (final r in valid)
                        RewardChip(
                          emoji: r.emoji,
                          label: r.rewardText,
                          isSelected: _controller.text == r.rewardText,
                          onTap: () => _pickRecent(r),
                        ),
                    ],
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),

            SizedBox(height: _sectionGap.h),
            // 자문 문구 그대로다. 보호자가 "큰 것"을 떠올리기 쉬워 먼저 말해 준다.
            Text(
              '한 달 뒤 선물보다 오늘 받을 수 있는 것이 더 효과적이에요',
              style: context.typo.caption.copyWith(color: colors.textSecondary),
            ),
            SizedBox(height: space.xl.h),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String label, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: _sectionGap.h),
        Text(
          label,
          style: context.typo.sectionTitle
              .copyWith(color: context.colors.textPrimary),
        ),
        SizedBox(height: _labelToContent.h),
        content,
      ],
    );
  }
}

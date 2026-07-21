import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../application/routine_notifier.dart';
import '../data/routine_repository.dart';
import '../domain/routine_suggestion.dart';
import 'widgets/aurora_background.dart';

/// Figma `보호자_새로운 일과 만들기`(238:1643) — 자연어로 일과를 받는다.
///
/// **하단 고정 CTA가 없다.** 전송은 입력창 안 화살표가 담당하며, 입력이 있을
/// 때만 나타난다(Figma 262:4106). 이 화면군만 Pretendard를 쓴다.
class RoutineInputScreen extends ConsumerStatefulWidget {
  const RoutineInputScreen({super.key});

  /// 전송 버튼. 입력이 있을 때만 존재하므로 테스트가 키로 찾는다.
  static const sendButtonKey = Key('routineInputSend');

  @override
  ConsumerState<RoutineInputScreen> createState() => _RoutineInputScreenState();
}

class _RoutineInputScreenState extends ConsumerState<RoutineInputScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // 뒤로 갔다 와도 입력이 남아있어야 한다
    _controller = TextEditingController(
      text: ref.read(routineFlowProvider).rawInput,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 로딩 화면으로 넘긴다 (Figma 262:4569).
  ///
  /// **여기서 DLP·질문 생성을 시작하지 않는다.** 로딩 화면이 직접 부른다 —
  /// 시작 지점이 둘이면 화면이 재생성될 때 요청이 겹쳐 나간다. (이슈 #41)
  void _askQuestions(BuildContext context) {
    context.push(Routes.routineMasking);
  }

  void _fill(RoutineSuggestion suggestion) {
    final text = suggestion.inputText;
    _controller
      ..text = text
      // 커서를 끝으로 보내야 이어서 고칠 수 있다
      ..selection = TextSelection.collapsed(offset: text.length);
    ref.read(routineFlowProvider.notifier).setRawInput(text);
  }

  @override
  Widget build(BuildContext context) {
    final rawInput = ref.watch(routineFlowProvider).rawInput;
    final canSubmit = rawInput.trim().isNotEmpty;
    final space = context.space;

    return Scaffold(
      backgroundColor: context.colors.background,
      // 키보드가 올라와도 배경이 밀려 찌그러지지 않게 한다
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraBackground()),
          SafeArea(
            child: Column(
              children: [
                const _BackRow(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: space.xl),
                        const _Headline(),
                        SizedBox(height: space.xl),
                        _InputField(
                          controller: _controller,
                          canSubmit: canSubmit,
                          onChanged: ref
                              .read(routineFlowProvider.notifier)
                              .setRawInput,
                          onSubmit: () => _askQuestions(context),
                        ),
                        SizedBox(height: space.lg),
                        _SuggestionChips(onTap: _fill),
                      ],
                    ),
                  ),
                ),
                const _PrivacyNote(),
                SizedBox(height: space.md),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 뒤로가기 (Figma x=24, y=87)
class _BackRow extends StatelessWidget {
  const _BackRow();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(left: context.space.screenH, top: 12),
        child: AppPressable(
          onTap: () => context.pop(),
          scaleDown: AppPressable.scaleIcon,
          child: SvgPicture.asset(AppAssets.iconBack, width: 24, height: 24),
        ),
      ),
    );
  }
}

/// sparkles + 제목 + 설명 (Figma 중앙정렬)
class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      children: [
        SvgPicture.asset(AppAssets.iconSparklesLarge, width: 30, height: 36),
        SizedBox(height: context.space.lg),
        Text(
          // 줄바꿈 위치는 디자인이 정한 대로다
          '오늘은 어떤 준비가\n필요한가요?',
          textAlign: TextAlign.center,
          style: context.typo.promptTitle.copyWith(color: colors.textPrimary),
        ),
        SizedBox(height: context.space.sm),
        Text(
          'AI 루미가 작은 행동 단계로 나눠드려요',
          textAlign: TextAlign.center,
          style: context.typo.promptBody.copyWith(color: colors.promptMuted),
        ),
      ],
    );
  }
}

/// 반투명 유리 입력창 (Figma 362×52, r20).
///
/// 배경이 움직이므로 `backdropFilter` 너머 색이 저절로 흐른다.
/// 유리 효과 자체를 애니메이션하지 않는다.
class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.canSubmit,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool canSubmit;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: space.buttonMarginH),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(space.cardRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: space.sm),
            decoration: BoxDecoration(
              color: colors.glassSurface,
              borderRadius: BorderRadius.circular(space.cardRadius),
              boxShadow: [
                BoxShadow(
                  color: colors.glassShadow,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    maxLines: 4,
                    minLines: 1,
                    style: context.typo.promptBody
                        .copyWith(color: colors.textPrimary),
                    decoration: InputDecoration.collapsed(
                      hintText: '평소 이야기하듯 입력해주세요',
                      hintStyle: context.typo.promptBody
                          .copyWith(color: colors.promptMuted),
                    ),
                  ),
                ),
                // 입력이 있을 때만 나타난다 (Figma 262:4106)
                if (canSubmit) ...[
                  SizedBox(width: space.xs),
                  _SendButton(onTap: onSubmit),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 입력창 안 전송 버튼 (Figma 32×32 원)
class _SendButton extends StatelessWidget {
  const _SendButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      key: RoutineInputScreen.sendButtonKey,
      onTap: onTap,
      scaleDown: AppPressable.scaleIcon,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: context.colors.textPrimary,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.arrow_upward_rounded,
          size: 18,
          color: context.colors.surface,
        ),
      ),
    );
  }
}

/// 추천 문구 칩 — Figma 2·2·1 배치.
///
/// `Wrap`으로 두면 글자 길이에 따라 줄이 밀린다. Figma 구조를 그대로 만든다.
///
/// 목록은 서버에서 오고 **개수가 고정이 아니다.** 2개씩 채우고 남는 하나는
/// 마지막 줄에 혼자 둔다(Figma 5개 = 2·2·1). 홀수·짝수 모두 대응된다. (이슈 #36)
class _SuggestionChips extends ConsumerWidget {
  const _SuggestionChips({required this.onTap});

  final ValueChanged<RoutineSuggestion> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(routineSuggestionsProvider).maybeWhen(
          data: (list) => list,
          // 로딩·실패 중에는 칩을 감춘다. 입력창은 그대로 쓸 수 있으므로
          // 흐름이 막히지 않는다.
          orElse: () => const <RoutineSuggestion>[],
        );

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (var row = 0; row < items.length; row += 2) ...[
          if (row > 0) SizedBox(height: context.space.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final (index, s) in items.skip(row).take(2).indexed) ...[
                if (index > 0) const SizedBox(width: 6),
                Flexible(child: _Chip(suggestion: s, onTap: onTap)),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.suggestion, required this.onTap});

  final RoutineSuggestion suggestion;
  final ValueChanged<RoutineSuggestion> onTap;

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return AppPressable(
      onTap: () => onTap(suggestion),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(space.cardRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            // Figma padding 10×16
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: context.colors.glassChip,
              borderRadius: BorderRadius.circular(space.cardRadius),
            ),
            child: Text(
              suggestion.label,
              style: context.typo.chipLabel
                  .copyWith(color: context.colors.chipLabel),
            ),
          ),
        ),
      ),
    );
  }
}

/// 하단 안내 (Figma y=794)
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      '아이의 정보를 안전하게 보호해요',
      style: context.typo.caption.copyWith(color: context.colors.promptMuted),
    );
  }
}

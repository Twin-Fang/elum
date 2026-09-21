import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_context_ext.dart';
import 'widgets/routine_flow_scaffold.dart';
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

    return PopScope(
      // 쓴 글이 있으면 시스템 뒤로가기도 잡는다 (#242).
      canPop: !canSubmit,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!await confirmLeaveRoutineFlow(context) || !context.mounted) {
          return;
        }
        dismissKeyboard();
        context.pop();
      },
      child: _scaffold(context, canSubmit, space),
    );
  }

  Widget _scaffold(BuildContext context, bool canSubmit, AppSpacing space) {
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
                _BackRow(confirmExit: canSubmit),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // **간격을 시안 좌표에서 뽑는다.** 토큰(32·24)을 쓰던
                        // 동안 화면 전체가 시안보다 90~140 위로 떠 있었고,
                        // 아래로 갈수록 벌어졌다 (#297).
                        //
                        // 시안(238:1643) 절대 y — 뒤로가기 79 · 반짝임 225 ·
                        // 제목 285 · 부제 363 · 입력칸 429 · 칩 529.
                        SizedBox(height: _RoutineInputLayout.topToSparkles),
                        const _Headline(),
                        SizedBox(height: _RoutineInputLayout.bodyToInput),
                        _InputField(
                          controller: _controller,
                          canSubmit: canSubmit,
                          onChanged: ref
                              .read(routineFlowProvider.notifier)
                              .setRawInput,
                          onSubmit: () => _askQuestions(context),
                        ),
                        SizedBox(height: _RoutineInputLayout.inputToChips),
                        _SuggestionChips(onTap: _fill),
                      ],
                    ),
                  ),
                ),
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
  const _BackRow({required this.confirmExit});

  /// 쓴 글이 있으면 나가기 전에 묻는다 (#242).
  final bool confirmExit;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          // 시안(976:4611)은 x=16 이다. 화면 좌우 여백(24)이 아니라 이 값이다 —
          // 아이콘이 40×40 이라 그림 자체에 여백이 들어 있다.
          left: _RoutineInputLayout.backLeft,
          top: _RoutineInputLayout.backTop,
        ),
        child: AppPressable(
          onTap: () async {
            if (!confirmExit) {
              dismissKeyboard();
              return context.pop();
            }
            if (!await confirmLeaveRoutineFlow(context) || !context.mounted) {
              return;
            }
            dismissKeyboard();
            context.pop();
          },
          scaleDown: AppPressable.scaleIcon,
          // **자리가 40×40 이다.** 시안(976:4611)이 그 크기로 두고, 안에
          // 화살표를 가운데 놓는다 — 박스 중심과 화살표 중심이 같다.
          // 아래 여백은 이 40을 감안해 잡혀 있으므로(topToSparkles) 여기를
          // 바꾸면 그쪽도 함께 고쳐야 한다.
          //
          // 정사각형이라 가로세로 모두 .w — .h를 섞으면 찌그러진다.
          child: SizedBox(
            width: 40.w,
            height: 40.w,
            child: Center(
              child: SvgPicture.asset(
                AppAssets.iconBack,
                width: 24.w,
                height: 24.w,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 시안(238:1643)에서 뽑은 세로 간격.
///
/// 시안은 절대 좌표로 그려져 있고 앱은 간격을 쌓아 올린다. 토큰(32·24)을
/// 그대로 쓰면 **쌓을수록 어긋나** 맨 아래 칩이 140이나 떠 버린다.
/// 그래서 이 화면만큼은 **시안 좌표의 차**를 그대로 적어 둔다.
class _RoutineInputLayout {
  /// 안전영역(59) 안에서 뒤로가기 윗변까지 — 시안 79.
  static double get backTop => 20.h;

  /// 뒤로가기 왼쪽 — 시안 16.
  static double get backLeft => 16.w;

  /// 뒤로가기 줄(20 + 40) 아래부터 반짝임(225)까지 — 시안 계산 그대로 106.
  ///
  /// 한때 99였다. "반짝임 SVG가 시안보다 7 작게 그려진다"는 이유였는데
  /// **다시 재 보니 양쪽 다 36으로 같았다** — 근거가 사라진 보정이라 걷어냈다.
  /// 그 7 때문에 반짝임이 통째로 위에 떠 있었다 (#297).
  static double get topToSparkles => 106.h;

  /// 반짝임 → 제목 — 시안 간격 24.
  static double get sparklesToTitle => 24.h;

  /// 부제 끝(381) → 입력칸(429).
  static double get bodyToInput => 48.h;

  /// 입력칸 끝(481) → 칩 묶음(529).
  static double get inputToChips => 48.h;
}

/// sparkles + 제목 + 설명 (Figma 중앙정렬)
class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      children: [
        // 30×36 비정사각형이라 가로 .w / 세로 .h
        SvgPicture.asset(
          AppAssets.iconSparklesLarge,
          width: 30.w,
          height: 36.h,
        ),
        SizedBox(height: _RoutineInputLayout.sparklesToTitle),
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
            constraints: BoxConstraints(minHeight: 52.h),
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: space.sm),
            decoration: BoxDecoration(
              color: colors.glassSurface,
              borderRadius: BorderRadius.circular(space.cardRadius),
              boxShadow: [
                BoxShadow(
                  color: colors.glassShadow,
                  blurRadius: 5.w,
                  offset: Offset(0, 2.h),
                ),
              ],
            ),
            child: Row(
              // 가운데 맞춤이다. 아래 맞춤으로 두면 한 줄일 때 글자가 박스 바닥에
              // 붙는다 — 시안은 위아래 여백을 18씩 같게 뒀다 (238:1723).
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    maxLines: 4,
                    minLines: 1,
                    style: context.typo.promptBody.copyWith(
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration.collapsed(
                      // 시안(238:1723) 문구 그대로. `적어주세요`로 바꿔 두었던 것을 되돌린다.
                      hintText: '평소 이야기하듯 입력해주세요',
                      // 플레이스홀더는 입력 텍스트(promptBody, w500)보다 가늘다 (Figma style_7YRXS7)
                      hintStyle: context.typo.promptPlaceholder.copyWith(
                        color: colors.promptMuted,
                      ),
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
        // 원형 버튼이라 가로세로 모두 .w
        width: 32.w,
        height: 32.w,
        decoration: BoxDecoration(
          color: context.colors.textPrimary,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.arrow_upward_rounded,
          size: 18.w,
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
    final items = ref
        .watch(routineSuggestionsProvider)
        .maybeWhen(
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
                if (index > 0) SizedBox(width: 6.w),
                Flexible(
                  child: _Chip(suggestion: s, onTap: onTap),
                ),
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
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: context.colors.glassChip,
              borderRadius: BorderRadius.circular(space.cardRadius),
            ),
            child: Text(
              suggestion.label,
              style: context.typo.chipLabel.copyWith(
                color: context.colors.chipLabel,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

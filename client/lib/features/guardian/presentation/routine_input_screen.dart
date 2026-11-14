import 'dart:async';
import 'routine_input_field.dart';
import 'routine_suggestion_chips.dart';
import 'widgets/guide_tip_card.dart';
import 'widgets/routine_image_style_pill.dart';
import 'routine_template_sheet.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_context_ext.dart';
import 'widgets/routine_flow_scaffold.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_secondary_button.dart';
import '../application/routine_notifier.dart';
import '../domain/guide_tip.dart';
import '../domain/routine_suggestion.dart';
import 'widgets/aurora_background.dart';
import 'widgets/routine_flow_backdrop.dart';
import 'widgets/routine_flow_step_icon.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/router/routes.dart';

/// Figma `보호자_새로운 일과 만들기`(238:1643) — 자연어로 일과를 받는다.
///
/// 루미 얼굴 > 제목 > 입력칸 > 개인정보 안내 > 칩, 하단 고정 `다음` 버튼 (#1297).
/// 보내기는 다른 단계와 같은 하단 버튼 (입력칸 안 작은 원은 버튼으로 안 보임). 글이 비면 흐린 상태. 이 화면군만 Pretendard를 쓴다.
class RoutineInputScreen extends ConsumerStatefulWidget {
  const RoutineInputScreen({super.key});

  /// 이 화면의 배경 색 — 민트·보라·노랑 (시안 `238:1728`).
  static const aurora = AuroraTone.input;

  /// 하단 `다음` 버튼
  static const sendButtonKey = Key('routineInputSend');

  @override
  ConsumerState<RoutineInputScreen> createState() => _RoutineInputScreenState();
}

class _RoutineInputScreenState extends ConsumerState<RoutineInputScreen>
    with LeaveOnceMixin {
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

  /// 보상 설정으로 넘긴다 (Figma 1082:4709 — 입력 바로 다음).
  ///
  /// **여기서 DLP·질문 생성을 시작하지 않는다.** 보상 다음의 로딩 화면이 직접
  /// 부른다 — 시작 지점이 둘이면 화면이 재생성될 때 요청이 겹쳐 나간다.
  /// 두 번 눌러도 보상 화면이 두 장 쌓이지 않게 한 번만 넘긴다.
  Future<void> _next() => leaveOnce(() async {
    dismissKeyboard();
    unawaited(context.push(Routes.routineReward));
  });

  void _fill(RoutineSuggestion suggestion) => _setInput(suggestion.inputText);

  void _setInput(String text) {
    _controller
      ..text = text
      // 커서를 끝으로 보내야 이어서 고칠 수 있다
      ..selection = TextSelection.collapsed(offset: text.length);
    ref.read(routineFlowProvider.notifier).setRawInput(text);
  }

  /// 예시 일과 시트 > 고른 문장을 입력칸에 채운다
  Future<void> _openTemplates() async {
    dismissKeyboard();
    final template = await RoutineTemplateSheet.show(context);
    if (template == null || !mounted) return;
    _setInput(template.promptOf(context.l10n));
  }

  @override
  Widget build(BuildContext context) {
    final rawInput = ref.watch(routineFlowProvider).rawInput;
    final canSubmit = rawInput.trim().isNotEmpty;
    final space = context.space;

    return PopScope(
      // 쓴 글이 있으면 시스템 뒤로가기도 잡는다.
      canPop: !canSubmit,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!await confirmLeaveRoutineFlow(context) || !context.mounted) {
          return;
        }
        dismissKeyboard();
        context.popOrHome();
      },
      child: _scaffold(context, canSubmit, space),
    );
  }

  Widget _scaffold(BuildContext context, bool canSubmit, AppSpacing space) {
    // 흐름 배경 위라면 바탕도 오로라도 그리지 않는다 — 흐름이 하나를 함께 쓴다.
    final onBackdrop = RoutineFlowBackdrop.isPresent(context);

    return Scaffold(
      backgroundColor: onBackdrop
          ? Colors.transparent
          : context.colors.background,
      // 키보드가 올라와도 배경이 밀려 찌그러지지 않게 한다
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          if (!onBackdrop)
            const Positioned.fill(
              child: AuroraBackground(tone: RoutineInputScreen.aurora),
            ),
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
                        // 아래로 갈수록 벌어졌다.
                        //
                        // 시안(238:1643) 절대 y — 뒤로가기 79 ·
                        // 반짝임 185 · 제목 245 · 부제 323 · 입력칸 389 · 칩 489.
                        SizedBox(height: _RoutineInputLayout.topToLumiFace - RoutineFlowStepIcon.extraHeightOverLumiFace.h),
                        const _Headline(),
                        SizedBox(height: _RoutineInputLayout.bodyToInput),
                        RoutineInputField(
                          controller: _controller,
                          onChanged: ref
                              .read(routineFlowProvider.notifier)
                              .setRawInput,
                        ),
                        SizedBox(height: space.sm),
                        // 개인정보 안내 (서비스 원칙 2: 적은 글은 그대로 AI 로 감, #377·#1297)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: space.buttonMarginH,
                          ),
                          child: Text(
                            context.l10n.routineInputPrivacyNotice,
                            textAlign: TextAlign.center,
                            style: context.typo.promptCaption.copyWith(
                              color: context.colors.promptNotice,
                            ),
                          ),
                        ),
                        // 이번 일과의 그림 방식 + 그 자리에서 바꾸기 (#1287)
                        SizedBox(height: space.md.h),
                        const RoutineImageStylePill(),
                        SizedBox(height: space.lg.h),
                        RoutineSuggestionChips(onTap: _fill),
                        SizedBox(height: space.md),
                        // 카테고리별 예시 일과 (#777)
                        _TemplateButton(onPressed: _openTemplates),
                        // 가이드 팁: 한 줄 쓰는 요령 > 단계 나누기
                        GuideTipSlot(
                          placement: GuideTipPlacement.routineInput,
                          padding: EdgeInsets.fromLTRB(space.buttonMarginH, space.lg.h, space.buttonMarginH, 0),
                        ),
                      ],
                    ),
                  ),
                ),
                _SubmitBar(canSubmit: canSubmit, onSubmit: _next),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 하단 고정 `다음` 버튼. 키보드가 올라오면 키보드 바로 위로 따라 올라간다
/// (배경은 키보드에 밀리지 않게 스캐폴드가 늘지 않으므로 여기서 키보드 높이만큼 띄운다)
class _SubmitBar extends StatelessWidget {
  const _SubmitBar({required this.canSubmit, required this.onSubmit});

  final bool canSubmit;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        space.buttonMarginH,
        space.md,
        space.buttonMarginH,
        keyboardHeight > 0 ? keyboardHeight + space.sm : space.lg,
      ),
      child: ElumButton(
        key: RoutineInputScreen.sendButtonKey,
        label: context.l10n.commonNext,
        onPressed: canSubmit ? onSubmit : null,
      ),
    );
  }
}

/// 예시 일과 시트를 여는 글자 폭 보조 버튼 (추천 칩 아래 흐르는 내용 안)
class _TemplateButton extends StatelessWidget {
  const _TemplateButton({required this.onPressed});

  final VoidCallback onPressed;

  static const buttonKey = Key('routineInputTemplates');

  @override
  Widget build(BuildContext context) {
    return ElumSecondaryButton(
      key: buttonKey,
      label: context.l10n.routineTemplateOpen,
      onTap: onPressed,
      isCompact: true,
      // 겹친 그림 카드 (네모·동그라미 격자 아이콘 대신, #1287)
      leading: Image.asset(
        AppAssets.routineTemplateCards,
        width: 24.w,
        height: 24.w,
        excludeFromSemantics: true,
      ),
    );
  }
}

/// 뒤로가기 (Figma x=24, y=87)
class _BackRow extends StatelessWidget {
  const _BackRow({required this.confirmExit});

  /// 쓴 글이 있으면 나가기 전에 묻는다.
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
              return context.popOrHome();
            }
            if (!await confirmLeaveRoutineFlow(context) || !context.mounted) {
              return;
            }
            dismissKeyboard();
            context.popOrHome();
          },
          scaleDown: AppPressable.scaleIcon,
          semanticLabel: context.l10n.commonBack,
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
  /// 안전영역(59) 안에서 뒤로가기 윗변까지 — 시안 67.
  static double get backTop => 8.h;

  /// 뒤로가기 왼쪽 — 시안 16.
  static double get backLeft => 16.w;

  /// 뒤로가기 줄(8 + 40) 아래부터 루미 얼굴까지 66.
  ///
  /// 시안 반짝임(36) 자리 78 에서 루미 얼굴(48)과의 차이 12 를 뺀 값.
  /// 제목이 보상 설정(1082:4709)과 같은 높이에 선다 (#1297).
  static double get topToLumiFace => 66.h;

  /// 루미 얼굴 → 제목 — 시안 간격 24.
  static double get lumiFaceToTitle => 24.h;

  /// 부제 끝(341) → 입력칸(389).
  static double get bodyToInput => 48.h;

}

/// 루미 얼굴 + 제목 + 설명 (Figma 중앙정렬). 부제가 `AI 도우미 루미` 를 처음 소개한다 (#1297)
class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      children: [
        // 단계 그림: AI 도우미 루미 얼굴 (질문 · 보상 단계 그림과 같은 자리 · 크기)
        const RoutineFlowStepIcon(illustrationAsset: AppAssets.guardianProfileLumi),
        SizedBox(height: _RoutineInputLayout.lumiFaceToTitle),
        Text(
          // 줄바꿈 위치는 디자인이 정한 대로다
          context.l10n.routineInputTitle,
          textAlign: TextAlign.center,
          style: context.typo.promptTitle.copyWith(color: colors.textPrimary),
        ),
        SizedBox(height: context.space.sm),
        // 큰 글자에서 화면 끝에 붙지 않게 좌우 여백
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.space.buttonMarginH,
          ),
          child: Text(
            context.l10n.routineInputSubtitle,
            textAlign: TextAlign.center,
            style: context.typo.promptBody.copyWith(color: colors.promptMuted),
          ),
        ),
      ],
    );
  }
}

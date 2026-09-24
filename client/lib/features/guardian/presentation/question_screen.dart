import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/text/keep_words.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../shared/models/routine.dart';
import '../application/routine_notifier.dart';
import 'widgets/aurora_background.dart';
import 'widgets/routine_flow_scaffold.dart';

/// Figma `보호자_새로운 일과 만들기_추가질문`(262:4766 / 262:4854).
///
/// AI가 생활 맥락을 되묻는다. "가방을 챙겨요" 카드가 있어도 병원엔 진료카드,
/// 학교엔 필통처럼 준비물이 상황마다 다르고 그 맥락은 보호자만 안다.
///
/// **서버가 질문을 여러 개 준다** — 선택한 도움 목표마다 하나씩이다.
/// Figma는 한 개만 그렸지만 실제로는 2개 이상 올 수 있어 세로로 이어 붙인다.
///
/// 두 프레임의 차이는 선택 여부다. 아무것도 고르지 않으면 CTA가 없고(262:4766),
/// 하나라도 고르면 `카드 만들기`가 나타난다(262:4854).
///
/// 흐름 자리는 보상 **다음**, 카드 생성 앞이다 (#380 결정 1). 그래서 CTA 가 곧
/// 카드 생성(AI)을 부른다 — 두 번 누르기를 막는다([LeaveOnceMixin]).
class QuestionScreen extends ConsumerStatefulWidget {
  const QuestionScreen({super.key});

  /// 이 화면의 배경 색 — 파랑 (시안 `262:4767`).
  static const aurora = AuroraTone.question;

  @override
  ConsumerState<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends ConsumerState<QuestionScreen>
    with LeaveOnceMixin {
  /// 카드 생성 로딩으로. **기다리지 않는다** — 로딩이 검토로 교체되면 Future 가
  /// 끝나지 않는다. 풀어 주는 것은 이 화면이 다시 맨 위가 될 때다.
  Future<void> _makeCards() => leaveOnce(() async {
    unawaited(context.push(Routes.routineGenerating));
  });

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(routineFlowProvider);
    final notifier = ref.read(routineFlowProvider.notifier);
    final questions = state.question?.askable ?? const <QuestionItem>[];
    final space = context.space;

    // 앞의 로딩 화면(262:4569)이 질문을 받아온 뒤에야 여기로 넘어온다.
    // 그래도 null이면 이례적인 상황이므로 빈 화면 대신 대기 표시를 둔다.
    if (state.question == null) {
      return const RoutineFlowScaffold(
        aurora: QuestionScreen.aurora,
        child: _Waiting(),
      );
    }

    // 질문이 없으면 여기 있을 이유가 없다. 바로 카드 생성으로 보낸다.
    // (도움 목표를 고르지 않으면 서버가 빈 배열을 준다)
    //
    // 앞의 로딩이 이미 질문이 없으면 이 화면을 건너뛴다. 여기는 그래도 들어온
    // 경우(화면 이동 도구 등)의 안전망이다.
    //
    // ⚠️ 이 화면은 routineFlowProvider를 watch하므로 생성 중 상태가 바뀔 때마다
    // 다시 빌드된다. 가드가 없으면 그때마다 로딩 화면을 또 밀어 넣어
    // 카드 생성 요청이 겹쳐 나간다 — AI 호출이라 한 번이 곧 비용이다. (이슈 #41)
    if (questions.isEmpty) {
      final alreadyStarted = state.step == RoutineFlowStep.generating ||
          state.routine != null;
      if (alreadyStarted) {
        debugPrint('[cost] 질문 화면 리빌드 — 이미 생성이 시작돼 로딩 화면을 다시 열지 않는다');
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            // 보상은 이미 앞에서 정했다 (#380 결정 1) — 곧장 카드를 만든다.
            context.pushReplacement(Routes.routineGenerating);
          }
        });
      }
      return const RoutineFlowScaffold(
        aurora: QuestionScreen.aurora,
        child: SizedBox.shrink(),
      );
    }

    return RoutineFlowScaffold(
      aurora: QuestionScreen.aurora,
      // 홈으로 나갈 때만 묻는다. 뒤로는 보상으로 한 칸이라 고른 답이 남는다 (#387 D3).
      leave: RoutineLeave.discard,
      onBack: () => context.pop(),
      // 시안(`262:4854`)은 CTA를 y=675에 둔다 — 약관·목표와 같은 자리다 (#297).
      pinCtaToFigmaY: true,
      // 답을 하나라도 골랐을 때만 CTA가 나타난다 (Figma 262:4854)
      bottomButton: state.answers.isEmpty
          ? null
          : ElumButton(
              // 시안(262:4854) 그대로다. 보상이 앞으로 옮겨 오면서(#380) 이 버튼이
              // 여는 것이 정말로 카드 생성이 됐다 — 규칙(바로 다음 화면 이름)과도 맞는다.
              label: '카드 만들기',
              onPressed: _makeCards,
            ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Figma(262:4766)는 sparkles를 y=225에 둔다. 상단바(약 111)를 뺀
            // 만큼 띄워야 화면 중간에서 시작한다 — 그냥 쌓으면 전부 위로 몰린다.
            //
            // 질문이 2개 이상 오면 스크롤이 필요하므로 Stack 대신 여백을 쓴다.
            SizedBox(height: (225 - 111).h),
            SvgPicture.asset(
              AppAssets.iconSparklesLarge,
              width: 30.w,
              height: 36.h,
            ),
            // sparkles 하단(261) → 제목(285)
            SizedBox(height: 24.h),
            for (final (index, item) in questions.indexed) ...[
              if (index > 0) SizedBox(height: space.xl),
              _QuestionBlock(
                item: item,
                selected: state.answers,
                custom: state.customOptions[item.question] ?? const [],
                onToggle: notifier.toggleAnswer,
                onAddCustom: (value) =>
                    notifier.addCustomOption(item.question, value),
                onRemoveCustom: (value) =>
                    notifier.removeCustomOption(item.question, value),
              ),
            ],
            SizedBox(height: space.xl),
          ],
        ),
      ),
    );
  }
}

/// 질문 하나 — 제목 + 선택지 칩들 + 직접 입력.
///
/// 입력 필드를 여닫는 상태를 스스로 들고 있다. 질문이 여러 개일 때
/// 화면이 통째로 관리하면 어느 질문의 입력창인지 매번 따져야 한다.
class _QuestionBlock extends StatefulWidget {
  const _QuestionBlock({
    required this.item,
    required this.selected,
    required this.custom,
    required this.onToggle,
    required this.onAddCustom,
    required this.onRemoveCustom,
  });

  final QuestionItem item;
  final List<String> selected;

  /// 보호자가 직접 적어 넣은 선택지. 서버 선택지 뒤에 이어 붙인다.
  final List<String> custom;

  final ValueChanged<String> onToggle;
  final ValueChanged<String> onAddCustom;
  final ValueChanged<String> onRemoveCustom;

  @override
  State<_QuestionBlock> createState() => _QuestionBlockState();
}

class _QuestionBlockState extends State<_QuestionBlock> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isWriting = false;

  /// 준비물 이름이 길면 칩이 화면 폭을 넘겨 Wrap이 깨진다
  static const _maxLength = 20;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _open() {
    setState(() => _isWriting = true);
    // 필드가 그려진 뒤에야 포커스를 줄 수 있다
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  void _close() {
    _controller.clear();
    setState(() => _isWriting = false);
  }

  void _submit(String value) {
    // 빈 값이어도 조용히 닫는다 — 오타로 열었을 뿐인데 에러를 띄울 일이 아니다
    if (value.trim().isNotEmpty) widget.onAddCustom(value);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return Column(
      children: [
        // Figma 제목 상자는 307(x=43)이지만 **그 값을 그대로 쓰면 꺾인다.**
        // 시안에서 가장 긴 줄이 305인데 앱 글자 렌더가 그보다 조금 넓어,
        // 307로 묶으면 `…챙겨야 하 / 는`으로 넷째 줄이 생긴다 (#297).
        //
        // 줄바꿈 위치는 문구의 `\n`이 이미 정한다 — 폭은 **그 줄이 안 꺾일
        // 만큼**만 있으면 된다. 좌우 24를 남겨 345로 둔다.
        SizedBox(
          width: 345.w,
          // AI 가 주는 질문은 `\n` 없이 온다. 엔진이 글자 단위로 꺾어 `있나 / 요?`가
          // 됐다 — 띄어쓰기에서만 꺾는다 (#393 S5). 낭독기에는 원문을 준다.
          child: Text(
            keepWords(widget.item.question),
            semanticsLabel: widget.item.question,
            textAlign: TextAlign.center,
            style: context.typo.promptTitle
                .copyWith(color: context.colors.textPrimary),
          ),
        ),
        // 제목 하단(384) → 칩(424)
        SizedBox(height: 40.h),
        // 선택지 길이가 제각각이라 Wrap이 자연스럽다.
        // 입력 화면의 추천 칩과 달리 Figma도 고정 배치가 아니다.
        Padding(
          padding: EdgeInsets.symmetric(horizontal: space.screenH),
          child: AnimatedOpacity(
            // 쓰는 동안 칩을 흐리게 해 입력에 집중시킨다.
            // 어둡게 하면 '선택됨'과 색이 같아져 정반대 의미가 된다.
            opacity: _isWriting ? 0.4 : 1,
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            child: Wrap(
              alignment: WrapAlignment.center,
              // Figma: 칩 사이 6, 줄 사이 8
              spacing: 6.w,
              runSpacing: 8.h,
              children: [
                // 선택·서버 전송 값은 label만 쓴다. 화면 표시는 emoji를 붙인
                // displayLabel — 이 둘을 섞으면 이모지가 선택값에 끼어
                // 서버가 모르는 문자열이 answers로 나간다.
                for (final option in widget.item.options)
                  _OptionChip(
                    label: option.displayLabel,
                    isSelected: widget.selected.contains(option.label),
                    onTap: () => widget.onToggle(option.label),
                  ),
                // 직접 적은 것은 서버 선택지 뒤에 온다. 지울 수 있는 건 이쪽뿐이다.
                for (final option in widget.custom)
                  _OptionChip(
                    label: option,
                    isSelected: widget.selected.contains(option),
                    onTap: () => widget.onToggle(option),
                    onRemove: () => widget.onRemoveCustom(option),
                  ),
                if (!_isWriting)
                  _OptionChip(
                    // 시안 `262:4854` 문구 그대로 — `직접 적기`로 줄여 두었었다 (#297)
                    label: '+ 직접 입력하기',
                    isSelected: false,
                    onTap: _open,
                  ),
              ],
            ),
          ),
        ),
        if (_isWriting) ...[
          SizedBox(height: space.md),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: space.screenH),
            child: _CustomOptionField(
              controller: _controller,
              focusNode: _focusNode,
              maxLength: _maxLength,
              onSubmitted: _submit,
              onCancel: _close,
            ),
          ),
        ],
      ],
    );
  }
}

/// 직접 입력 필드 (Figma 262:4089 — 362×52, r20, 반투명 유리 + blur 10).
///
/// `ElumTextField`(68h, 불투명 흰 배경)와는 다른 물건이다. 이 화면의 칩과
/// 같은 유리 재질이라 배경 위에 떠 보여야 한다.
class _CustomOptionField extends StatelessWidget {
  const _CustomOptionField({
    required this.controller,
    required this.focusNode,
    required this.maxLength,
    required this.onSubmitted,
    required this.onCancel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int maxLength;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    return ClipRRect(
      borderRadius: BorderRadius.circular(space.cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 52.h,
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
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  maxLength: maxLength,
                  textInputAction: TextInputAction.done,
                  onSubmitted: onSubmitted,
                  style: context.typo.chipLabel
                      .copyWith(color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: '직접 적어주세요',
                    hintStyle: context.typo.chipLabel
                        .copyWith(color: colors.textPlaceholder),
                    // 글자수 카운터가 52 높이를 밀어낸다
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: space.md),
                  ),
                ),
              ),
              // 키보드를 닫지 않고도 빠져나갈 길을 준다
              AppPressable(
                onTap: onCancel,
                scaleDown: AppPressable.scaleIcon,
                semanticLabel: '직접 입력 닫기',
                child: Padding(
                  padding: EdgeInsets.only(right: space.md),
                  child: Icon(Icons.close_rounded,
                      size: 20, color: colors.chipLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 선택지 칩 (Figma padding 10×16, r20, 반투명 유리).
///
/// 고르면 배경이 진해진다(Figma 262:4870 — `text_title` 채움).
class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.onRemove,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  /// null이 아니면 라벨 뒤에 X가 붙는다.
  /// **직접 추가한 칩에만 준다** — 서버 선택지는 지울 대상이 아니다.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final labelColor = isSelected ? colors.surface : colors.chipLabel;

    return AppPressable(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(space.cardRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            // Figma 실측 padding 10×16.
            // X가 붙으면 오른쪽 여백을 줄여 X가 그 자리를 대신한다.
            padding: EdgeInsets.only(
              left: 16.w,
              right: (onRemove == null ? 16 : 8).w,
              top: 10.h,
              bottom: 10.h,
            ),
            decoration: BoxDecoration(
              color: isSelected ? colors.textPrimary : colors.glassChip,
              borderRadius: BorderRadius.circular(space.cardRadius),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: context.typo.chipLabel.copyWith(color: labelColor),
                ),
                if (onRemove != null) ...[
                  SizedBox(width: 4.w),
                  // 칩 안의 X 는 칩과 따로 읽혀야 한다. 이름이 없으면 칩 이름만
                  // 들려 누르면 고르는지 지우는지 알 수 없다 (#339).
                  Semantics(
                    container: true,
                    button: true,
                    label: '$label 지우기',
                    child: GestureDetector(
                      key: ValueKey('remove-$label'),
                      onTap: onRemove,
                      // 아이콘만으로는 터치 영역이 좁아 누르기 어렵다
                      behavior: HitTestBehavior.opaque,
                      child: Icon(
                        Icons.close_rounded,
                        size: 16.w,
                        color: labelColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 질문을 받아오는 동안 잠깐 보이는 상태.
/// 빈 화면을 두면 앱이 멈춘 것처럼 보인다.
class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: context.colors.promptMuted,
        ),
      ),
    );
  }
}

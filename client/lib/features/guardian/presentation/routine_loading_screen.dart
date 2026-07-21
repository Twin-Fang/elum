import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../application/routine_notifier.dart';
import '../domain/routine_stage.dart';
import 'widgets/routine_flow_scaffold.dart';

/// Figma `보호자_새로운 일과 만들기_로딩`.
///
/// 프레임이 둘이고 흐름의 서로 다른 자리에 놓인다 — [RoutineLoadingKind] 참조.
///
/// ```
/// 입력 → prepare(262:4569) → 추가질문 → generate(262:4703) → 카드확인
/// ```
///
/// 단순 스피너 대신 3단계를 하나씩 체크해 **무엇을 하고 있는지** 보여준다.
/// 특히 개인정보를 가린다는 사실은 보호자가 봐야 의미가 있다.
///
/// ## 진행과 대기를 분리한다
///
/// 단계 전진(연출)과 실제 작업(서버 응답)은 별개로 돌아간다.
///
/// - 응답이 **빨리 오면** — 스텝별 [RoutineStage.hold]를 다 채울 때까지 기다린다.
///   순식간에 스쳐 지나가면 연출이 없는 것과 같다.
/// - 응답이 **늦으면** — 마지막 단계에 머문 채 계속 기다린다. 단계를 다
///   소진했다고 넘기지 않는다. 아직 결과가 없기 때문이다. 가짜 100%도 없다.
class RoutineLoadingScreen extends ConsumerStatefulWidget {
  const RoutineLoadingScreen({super.key, required this.kind});

  /// 어느 로딩 화면인가 — 문구·진행률·다음 목적지가 여기서 갈린다
  final RoutineLoadingKind kind;

  @override
  ConsumerState<RoutineLoadingScreen> createState() =>
      _RoutineLoadingScreenState();
}

class _RoutineLoadingScreenState extends ConsumerState<RoutineLoadingScreen> {
  /// 지금까지 드러난 스텝 수. 0이면 아무것도 안 보인다.
  ///
  /// 인덱스가 아니라 **개수**로 센다. 마지막 스텝까지 드러난 뒤에도
  /// 계속 대기할 수 있어야 하는데, 인덱스면 "다 끝났다"와 구분이 안 된다.
  var _revealed = 0;

  /// 스텝 노출이 전부 끝났는지. 화면을 넘길 수 있는 조건 중 하나다.
  var _stagesDone = false;

  /// 실제 작업(서버 응답)이 끝났는지. 나머지 한 조건이다.
  var _workDone = false;

  /// 화면을 이미 넘겼는가. 두 조건이 거의 동시에 충족될 때
  /// 양쪽에서 각각 넘겨 화면이 두 번 쌓이는 것을 막는다.
  var _navigated = false;

  @override
  void initState() {
    super.initState();
    _revealStages();
    // initState에서 provider를 건드리면 "빌드 중 수정" 오류가 난다.
    // 첫 프레임이 끝난 뒤로 미룬다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _runWork());
  }

  /// 스텝을 하나씩 드러낸다. 각자 정해진 [RoutineStage.hold]만큼 머문다.
  ///
  /// `Timer.periodic`이 아니라 순차 `await`인 이유 — 스텝마다 시간이 다르다.
  /// 주기 타이머로는 4·3·4초를 표현할 수 없다.
  Future<void> _revealStages() async {
    for (final stage in widget.kind.stages) {
      if (!mounted) return;
      setState(() => _revealed++);
      await Future<void>.delayed(stage.hold);
    }
    if (!mounted) return;

    _stagesDone = true;
    _tryNavigate();
  }

  /// 이 화면이 담당하는 작업을 수행한다.
  ///
  /// repository가 실패를 흡수하므로 여기서 예외를 다루지 않는다.
  /// 서버가 죽어도 로컬 카드로 진행된다 (docs 원칙 6번).
  Future<void> _runWork() async {
    final notifier = ref.read(routineFlowProvider.notifier);

    switch (widget.kind) {
      case RoutineLoadingKind.prepare:
        // DLP는 화면 전환 없이 상태만 갱신한다. 전/후 비교는 카드 확인
        // 화면에서 보여주므로 여기서 멈추지 않는다.
        await notifier.runDlp();
        await notifier.askQuestion();

      case RoutineLoadingKind.generate:
        await _generateCards(notifier);
    }

    if (!mounted) return;
    _workDone = true;
    _tryNavigate();
  }

  /// 카드 생성. **`POST /api/routines`는 AI 호출이라 한 번이 곧 비용이다.**
  ///
  /// notifier에도 가드가 있지만 여기서 한 번 더 막는다 — 이 화면이 재생성되면
  /// `initState`가 다시 돌아 요청이 겹쳐 나간 사고가 있었다. (이슈 #41)
  Future<void> _generateCards(RoutineFlowNotifier notifier) async {
    final flow = ref.read(routineFlowProvider);

    // 이미 만들어 둔 결과가 있으면 재요청하지 않는다.
    // 연출은 그대로 두고 넘어가기만 한다 — 스텝을 건너뛰지 않는다.
    if (flow.routine != null) {
      debugPrint('[cost] 로딩 화면 재생성 — 이미 만든 카드가 있어 요청하지 않는다');
      return;
    }

    await notifier.generateCards();
  }

  /// 두 조건이 **모두** 충족됐을 때만 넘어간다.
  ///
  /// 연출이 끝나도 결과가 없으면 기다리고, 결과가 와도 연출이 남았으면 기다린다.
  void _tryNavigate() {
    if (_navigated || !_stagesDone || !_workDone || !mounted) return;
    _navigated = true;

    context.pushReplacement(switch (widget.kind) {
      RoutineLoadingKind.prepare => Routes.routineQuestion,
      RoutineLoadingKind.generate => Routes.routineReview,
    });
  }

  /// 지금 보여줄 진행률 — 마지막으로 드러난 스텝의 값.
  int get _percent {
    if (_revealed == 0) return widget.kind.stages.first.percent;
    return widget.kind.stages[_revealed - 1].percent;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final stages = widget.kind.stages;

    return RoutineFlowScaffold(
      // 생성 중에는 되돌릴 수 없다 — 중간에 끊으면 어중간한 상태가 남는다
      child: Column(
        children: [
          SizedBox(height: space.xl),
          SvgPicture.asset(AppAssets.iconSparklesLarge, width: 30, height: 36),
          SizedBox(height: space.lg),
          Text(
            widget.kind.title,
            textAlign: TextAlign.center,
            style: context.typo.promptTitle.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: space.md),
          // 진행률이 튀지 않게 숫자 자체를 부드럽게 잇는다
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _percent.toDouble()),
            duration: AppMotion.slow,
            curve: AppMotion.decelerate,
            builder: (context, value, _) => Text(
              '${value.round()}% 진행 되었어요',
              style: context.typo.promptBody
                  .copyWith(color: colors.promptMuted),
            ),
          ),
          const Spacer(),
          // Figma는 스텝을 좌측 정렬한다(x=54 / x=83 고정).
          // 가운데 정렬하면 줄마다 시작점이 달라 체크리스트로 안 보인다.
          Padding(
            padding: EdgeInsets.symmetric(horizontal: space.xl + space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (index, stage) in stages.indexed) ...[
                  if (index > 0) SizedBox(height: space.md),
                  _StageRow(
                    stage: stage,
                    // 뒤에 드러난 스텝이 있으면 이 스텝은 끝난 것이다
                    isDone: index < _revealed - 1,
                    isVisible: index < _revealed,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: space.xl),
        ],
      ),
    );
  }
}

/// 체크 표시 + 문구 한 줄.
///
/// 아래에서 위로 올라오며 나타난다. 끝난 단계는 원이 채워지고 문구가 진해진다.
class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.stage,
    required this.isDone,
    required this.isVisible,
  });

  final RoutineStage stage;
  final bool isDone;
  final bool isVisible;

  /// Figma 실측 — 체크 원 20×20
  static const _dotSize = 20.0;

  /// 등장할 때 아래에서 올라오는 거리
  static const _riseFrom = 16.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // 자리는 처음부터 잡아둔다. 나타날 때 높이가 늘면 아래 스텝이 밀려
    // 이미 뜬 줄까지 함께 움직인다.
    return AnimatedOpacity(
      opacity: isVisible ? 1 : 0,
      duration: AppMotion.slow,
      curve: AppMotion.entry,
      child: AnimatedSlide(
        offset: isVisible ? Offset.zero : const Offset(0, _riseFrom / _dotSize),
        duration: AppMotion.slow,
        curve: AppMotion.decelerate,
        child: Row(
          children: [
            SizedBox(
              width: _dotSize,
              height: _dotSize,
              child: AnimatedSwitcher(
                duration: AppMotion.normal,
                child: isDone
                    ? Container(
                        key: const ValueKey('done'),
                        decoration: BoxDecoration(
                          color: colors.stageDone,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(5),
                        child: SvgPicture.asset(AppAssets.iconCheck),
                      )
                    : DecoratedBox(
                        key: const ValueKey('pending'),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: colors.stagePending, width: 3),
                        ),
                      ),
              ),
            ),
            SizedBox(width: context.space.xs),
            // 색만 바뀌므로 문구가 갑자기 진해지지 않고 서서히 넘어간다
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: AppMotion.normal,
                curve: AppMotion.standard,
                style: context.typo.stageLabel.copyWith(
                  color: isDone ? colors.stageDone : colors.stagePendingText,
                ),
                child: Text(stage.label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

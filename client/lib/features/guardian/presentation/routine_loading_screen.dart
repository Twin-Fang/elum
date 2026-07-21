import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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

    // ⚠️ Figma는 요소를 **절대 좌표**로 둔다(852 높이 기준).
    //
    // Column + Spacer로 남는 공간을 배분하면 체크리스트가 화면 바닥에 붙어
    // 시안과 전혀 달라진다 — 실제로 그렇게 만들었다가 아래로 박혔다.
    // 좌표를 그대로 옮기고 `.h`로 환산해 기기 높이에 맞춘다.
    //
    // 상단바(뒤로가기·홈)를 [RoutineFlowScaffold]가 이미 그리므로,
    // 그만큼(약 111) 뺀 값이 이 영역 안에서의 y가 된다.
    const topBarH = 111.0;

    return RoutineFlowScaffold(
      // 생성 중에는 되돌릴 수 없다 — 중간에 끊으면 어중간한 상태가 남는다
      child: Stack(
        children: [
          // 루미는 준비 화면에만 나온다 (Figma 262:4569 `Group 26`, y=383).
          // 카드 생성 화면(262:4703)에는 없다.
          if (widget.kind == RoutineLoadingKind.prepare)
            Positioned(
              top: (383 - topBarH).h,
              left: 0,
              child: const _LumiPeek(),
            ),

          // sparkles y=225 → 제목 y=285 → 진행률 y=363
          Positioned(
            top: (225 - topBarH).h,
            left: 0,
            right: 0,
            child: Column(
              children: [
                SvgPicture.asset(
                  AppAssets.iconSparklesLarge,
                  width: 30.w,
                  height: 36.h,
                ),
                SizedBox(height: space.lg),
                Text(
                  widget.kind.title,
                  textAlign: TextAlign.center,
                  style: context.typo.promptTitle
                      .copyWith(color: colors.textPrimary),
                ),
                SizedBox(height: space.md),
                // 진행률 숫자(70 → 80 등)가 단계마다 튀지 않게 세면서 올라간다.
                // 진행 중임을 알리는 스피너는 [_StageRow]가 보여준다.
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
              ],
            ),
          ),

          // 체크리스트 — Figma x=54, y=569. 줄 간격 34(569→603→637).
          // 좌측 정렬해야 체크 아이콘이 한 줄로 선다.
          Positioned(
            top: (569 - topBarH).h,
            left: 54.w,
            right: 54.w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (index, stage) in stages.indexed) ...[
                  if (index > 0) SizedBox(height: 14.h),
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
        ],
      ),
    );
  }
}

/// 왼쪽에서 나타나 손을 흔들고 다시 숨는 루미 (Figma 262:4569 `Group 26`).
///
/// 기다리는 동안 화면이 정지해 보이지 않게 하는 장치다. 계속 흔들면 시선을
/// 뺏으므로 **나왔다 → 흔들고 → 들어간 뒤 쉰다**를 반복한다.
///
/// Figma는 x=-48에 두어 화면 밖에 걸쳐 몸통 일부만 보인다. 정지 시안이라
/// 등장·퇴장은 그리지 않았지만, 그 위치가 "옆에서 빼꼼 내민" 상태다.
class _LumiPeek extends StatefulWidget {
  const _LumiPeek();

  @override
  State<_LumiPeek> createState() => _LumiPeekState();
}

class _LumiPeekState extends State<_LumiPeek>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// 한 번 나왔다 들어가는 데 걸리는 시간. 쉬는 구간까지 포함한다.
  static const _cycle = Duration(milliseconds: 5200);

  /// Figma 실측 — `Group 26`은 122×123이다.
  /// SVG 자체(113×99)가 아니라 **배치 크기**를 따라야 시안과 같아 보인다.
  static const _width = 122.0;
  static const _height = 123.0;

  /// 다 나왔을 때의 위치. Figma는 x=-48에 두어 **화면 왼쪽 밖으로 걸친다**
  /// (폭 122의 약 40%가 잘려 몸통 일부만 보인다).
  static const _restX = -48.0;

  /// 숨을 때는 완전히 가려질 만큼 더 빠진다
  static const _hiddenX = -_width;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _cycle)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 등장(0~15%) → 흔들기(15~65%) → 퇴장(65~80%) → 쉼(80~100%).
  ///
  /// 시간 비율로 나눈 이유 — 컨트롤러 하나로 전체를 돌리면 중간에 화면이
  /// 사라져도 상태가 어긋나지 않는다.
  double _slideX(double t) {
    if (t < 0.15) {
      return _lerp(_hiddenX, _restX, Curves.easeOutBack.transform(t / 0.15));
    }
    if (t < 0.65) return _restX;
    if (t < 0.80) {
      return _lerp(
        _restX,
        _hiddenX,
        Curves.easeInCubic.transform((t - 0.65) / 0.15),
      );
    }
    return _hiddenX;
  }

  /// 팔 흔들기 — 다 나온 뒤에만 흔든다. 나오면서 흔들면 어수선하다.
  double _armAngle(double t) {
    if (t < 0.18 || t > 0.62) return 0;
    final progress = (t - 0.18) / (0.62 - 0.18);
    // 2.5번 왕복. 끝에서 부드럽게 멎도록 진폭을 점점 줄인다.
    final decay = 1 - progress;
    return math.sin(progress * math.pi * 5) * 0.22 * decay;
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    // 세로 위치는 부모 [Positioned]가 잡는다. 여기선 가로 이동만 맡는다.
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Transform.translate(
          // Figma 좌표(393 폭 기준)를 기기 폭에 맞춰 환산한다
          offset: Offset(_slideX(t).w, 0),
          child: Transform.rotate(
            // 몸 전체를 살짝 기울여 손 흔드는 느낌을 낸다.
            // SVG가 통짜라 팔만 따로 돌릴 수 없다.
            angle: _armAngle(t),
            // 발치를 축으로 삼아야 몸이 붕 뜨지 않는다
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        );
      },
      child: SvgPicture.asset(
        AppAssets.lumiThinking,
        width: _width.w,
        height: _height.h,
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
              width: _dotSize.w,
              height: _dotSize.w,
              child: AnimatedSwitcher(
                duration: AppMotion.normal,
                child: isDone
                    ? Container(
                        key: const ValueKey('done'),
                        decoration: BoxDecoration(
                          color: colors.stageDone,
                          shape: BoxShape.circle,
                        ),
                        padding: EdgeInsets.all(5.w),
                        child: SvgPicture.asset(AppAssets.iconCheck),
                      )
                    // 지금 진행 중인 단계는 원이 돌아간다.
                    //
                    // Figma 262:4736 `Ellipse 22`는 정지된 테두리 원이지만,
                    // 그대로 두면 완료도 대기도 아닌 상태가 멈춰 보인다.
                    // 서버 응답이 늦으면 이 단계에 수 초간 머무르므로
                    // 움직임이 있어야 진행 중임이 전달된다.
                    : SizedBox.square(
                        key: const ValueKey('pending'),
                        dimension: _dotSize.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 3.w,
                          // Figma 원의 테두리 색을 그대로 쓴다
                          color: colors.stagePending,
                          backgroundColor: Colors.transparent,
                        ),
                      ),
              ),
            ),
            // Figma: 아이콘 우측(x=20) → 문구 좌측(x=28)
            SizedBox(width: 8.w),
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../application/routine_notifier.dart';
import '../domain/routine_stage.dart';
import 'widgets/routine_flow_scaffold.dart';

/// Figma `보호자_새로운 일과 만들기_로딩`(262:4569 / 262:4703).
///
/// AI가 카드를 만드는 동안 무엇을 하고 있는지 보여준다. 단순 스피너 대신
/// 3단계를 하나씩 체크해 **개인정보를 가린다는 사실을 보호자가 보게** 한다.
///
/// ⚠️ 진행률은 서버가 주지 않아 예상 시간으로 움직인다(이슈 #33).
/// 그래서 마지막 단계에서 멈추고 기다린다 — 가짜 100%를 만들지 않는다.
class RoutineLoadingScreen extends ConsumerStatefulWidget {
  const RoutineLoadingScreen({super.key});

  /// 한 단계에 머무는 시간.
  ///
  /// 실측상 카드 생성이 수십 초 걸린다. 단계를 너무 빨리 넘기면 마지막 단계에서
  /// 하염없이 기다리게 되므로 여유 있게 잡는다.
  static const stageDuration = Duration(seconds: 6);

  @override
  ConsumerState<RoutineLoadingScreen> createState() =>
      _RoutineLoadingScreenState();
}

class _RoutineLoadingScreenState extends ConsumerState<RoutineLoadingScreen> {
  var _stage = RoutineStage.masking;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _advanceStages();
    // initState에서 provider를 건드리면 "빌드 중 수정" 오류가 난다.
    // 첫 프레임이 끝난 뒤로 미룬다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 마지막 단계까지만 진행시키고 멈춘다.
  void _advanceStages() {
    _timer = Timer.periodic(RoutineLoadingScreen.stageDuration, (timer) {
      final next = _stage.index + 1;
      if (next >= RoutineStage.values.length) {
        timer.cancel();
        return;
      }
      if (mounted) setState(() => _stage = RoutineStage.values[next]);
    });
  }

  /// 카드 생성을 시작하고, 끝나면 다음 화면으로 넘긴다.
  ///
  /// repository가 실패를 흡수하므로 여기서 예외를 다루지 않는다.
  /// 서버가 죽어도 로컬 카드로 진행된다 (docs 원칙 6번).
  ///
  /// **`POST /api/routines`는 AI 호출이라 한 번이 곧 비용이다.**
  /// notifier에도 가드가 있지만 여기서 한 번 더 막는다 — 이 화면이 재생성되면
  /// `initState`가 다시 돌아 요청이 겹쳐 나간 사고가 있었다. (이슈 #41)
  Future<void> _generate() async {
    final flow = ref.read(routineFlowProvider);

    // 이미 만들어 둔 결과가 있으면 재요청하지 않고 바로 넘어간다.
    if (flow.routine != null) {
      debugPrint('[cost] 로딩 화면 재생성 — 이미 만든 카드가 있어 바로 넘어간다');
      if (mounted) context.pushReplacement(Routes.routineReview);
      return;
    }
    // 다른 인스턴스가 생성 중이면 손대지 않는다. 그쪽이 화면을 넘긴다.
    if (flow.step == RoutineFlowStep.generating) {
      debugPrint('[cost] 로딩 화면 재생성 — 이미 생성 중이라 요청하지 않는다');
      return;
    }

    await ref.read(routineFlowProvider.notifier).generateCards();
    if (mounted) context.pushReplacement(Routes.routineReview);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    return RoutineFlowScaffold(
      // 생성 중에는 되돌릴 수 없다 — 중간에 끊으면 어중간한 상태가 남는다
      child: Column(
        children: [
          SizedBox(height: space.xl),
          SvgPicture.asset(AppAssets.iconSparklesLarge, width: 30, height: 36),
          SizedBox(height: space.lg),
          Text(
            '루미가 내용을\n정리하고 있어요',
            textAlign: TextAlign.center,
            style: context.typo.promptTitle.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: space.md),
          Text(
            '${_stage.percent}% 진행 되었어요',
            style: context.typo.promptBody.copyWith(color: colors.promptMuted),
          ),
          const Spacer(),
          for (final stage in RoutineStage.values) ...[
            _StageRow(stage: stage, current: _stage),
            SizedBox(height: space.md),
          ],
          SizedBox(height: space.xl),
        ],
      ),
    );
  }
}

/// 체크 표시 + 문구 한 줄.
///
/// 끝난 단계는 원이 채워지고 문구가 진해진다. 아직인 단계는 빈 테두리다.
class _StageRow extends StatelessWidget {
  const _StageRow({required this.stage, required this.current});

  final RoutineStage stage;
  final RoutineStage current;

  /// Figma 실측 — 체크 원 20×20
  static const _dotSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDone = stage.isCompletedAt(current);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: _dotSize,
          height: _dotSize,
          child: isDone
              ? Container(
                  decoration: BoxDecoration(
                    color: colors.stageDone,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(5),
                  child: SvgPicture.asset(AppAssets.iconCheck),
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.stagePending, width: 3),
                  ),
                ),
        ),
        SizedBox(width: context.space.xs),
        Text(
          stage.label,
          style: context.typo.stageLabel.copyWith(
            color: isDone ? colors.stageDone : colors.stagePendingText,
          ),
        ),
      ],
    );
  }
}

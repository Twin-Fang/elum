import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/show_failure.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../shared/models/action_card.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../child/data/speech_service.dart';
import '../application/routine_notifier.dart';
import 'widgets/action_card_view.dart';
import 'widgets/card_edit_sheet.dart';
import 'widgets/aurora_background.dart';
import 'widgets/routine_flow_scaffold.dart';

/// Figma `보호자_새로운 일과 만들기_카드확인`(262:5124 / 309:2763).
///
/// AI가 만든 카드를 보호자가 확인하고 저장한다. **승인 전에는 아동에게
/// 노출되지 않는다** (docs 원칙 3번).
///
/// 카드가 가로로 넘어가고 뒤 카드가 살짝 보인다. 몇 장인지 한눈에 알 수 있게
/// `viewportFraction`으로 옆 카드를 걸쳐 보여준다.
class CardReviewScreen extends ConsumerStatefulWidget {
  const CardReviewScreen({super.key});

  /// Figma 262:5124의 배경은 단색 #F7F2EF뿐이다 — 글로우가 없다 (이슈 #79).
  /// 흐름 배경(#380)이 이 값을 보고 오로라를 가라앉힌다.
  static const aurora = AuroraTone.none;

  /// 옆 카드가 걸쳐 보이는 정도. 1.0이면 한 장만 꽉 찬다.
  static const _viewportFraction = 0.88;

  @override
  ConsumerState<CardReviewScreen> createState() => _CardReviewScreenState();
}

class _CardReviewScreenState extends ConsumerState<CardReviewScreen> {
  late final _controller = PageController(
    viewportFraction: CardReviewScreen._viewportFraction,
  );

  /// 지금 읽고 있는 카드 id. null이면 아무것도 안 읽고 있다.
  String? _speakingId;

  /// 지금 보고 있는 카드 인덱스. `이 카드 수정하기`가 이 카드를 대상으로 한다.
  int _currentIndex = 0;

  /// dispose에서 `ref`를 읽으면 "unmounted" 오류가 난다.
  /// 미리 잡아두고 정리할 때 쓴다.
  SpeechService? _speech;

  @override
  void initState() {
    super.initState();
    // 첫 프레임 뒤에 잡는다. initState에서 읽어도 되지만 일관되게 둔다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _speech = ref.read(speechServiceProvider);
    });
  }

  @override
  void dispose() {
    // 화면을 벗어나도 소리가 남으면 다음 화면까지 따라온다
    _speech?.stop();
    _controller.dispose();
    super.dispose();
  }

  /// 카드를 읽어준다. 읽는 중에 다시 누르면 멈춘다.
  ///
  /// 아동이 여러 번 누를 때 소리가 겹치면 알아들을 수 없다.
  Future<void> _speak(ActionCard card) async {
    final speech = ref.read(speechServiceProvider);

    if (_speakingId == card.id) {
      await speech.stop();
      if (mounted) setState(() => _speakingId = null);
      return;
    }

    setState(() => _speakingId = card.id);

    // 제목만 읽으면 무엇을 해야 하는지가 빠지고, 설명만 읽으면 화면의
    // 큰 제목과 어긋난다. 둘을 이어 붙인다.
    final ok = await speech.speak('${card.displayTitle}. ${card.description}');

    if (!mounted) return;
    setState(() => _speakingId = null);

    if (!ok) _showFailure();
  }

  /// 소리를 낼 수 없을 때. 아동은 못 읽지만 보호자가 제보할 때 필요하다.
  void _showFailure() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('소리를 재생할 수 없어요 (E-TTS)')));
  }

  Future<void> _save() async {
    // 저장해야 이룸이 화면에 나간다. 뺀 카드를 서버에서 지우고, 만들기 흐름에서
    // 온 일과만 승인한다 — 이미 저장한 일과에 승인을 부르면 서버가 거절한다 (#405).
    final failure = await ref.read(routineFlowProvider.notifier).save();

    if (!mounted) return;

    // **실패하면 홈으로 보내지 않는다.** 홈으로 가면 저장된 것처럼 보이는데,
    // 정작 이룸이 휴대폰에는 아무것도 뜨지 않는다. 그때 보호자가 의심할 곳은
    // 앱이 아니라 이룸이다.
    if (failure != null) {
      showFailureSnack(
        context,
        failure,
        fallback: '일과를 저장하지 못했어요. 다시 해주세요',
        fallbackCode: 'E-CONFIRM',
      );
      return;
    }
    context.go(Routes.guardian);
  }

  /// 지금 보고 있는 카드의 제목·설명을 바텀시트로 수정한다.
  Future<void> _edit(ActionCard card) async {
    final edited = await CardEditSheet.show(
      context,
      // displayTitle이 아니라 실제 title을 넘긴다. 예전 카드는 title이 없어
      // displayTitle이 description을 대신 돌려주는데, 그 값이 제목칸에 채워지면
      // 사용자가 제목을 안 고쳤을 때 title=description으로 저장돼 제목·설명이
      // 똑같아진다. title이 비면 제목칸도 비워 사용자가 직접 채우게 한다.
      title: card.title,
      description: card.description,
    );
    // 저장 없이 닫았다 — 아무것도 바꾸지 않는다
    if (edited == null || !mounted) return;

    final failure = await ref
        .read(routineFlowProvider.notifier)
        .updateStep(
          stepId: card.id,
          title: edited.title,
          description: edited.description,
        );

    // 서버 반영 실패 — 로컬에는 반영됐지만 저장하기(승인) 전에 앱을 끄면
    // 사라진다. 에러 코드가 있어야 제보를 추적할 수 있다.
    if (failure != null && mounted) {
      showFailureSnack(
        context,
        failure,
        fallback: '고친 내용을 저장하지 못했어요',
        fallbackCode: 'E-STEP',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final routine = ref.watch(routineFlowProvider).routine;
    final cards = routine?.steps ?? const [];
    final routineId = routine?.id ?? '';
    final space = context.space;

    // 만들어진 카드가 없으면 확인할 것이 없다. 홈으로 돌려보낸다.
    if (cards.isEmpty) {
      return const RoutineFlowScaffold(
        aurora: CardReviewScreen.aurora,
        child: _EmptyCards(),
      );
    }

    return RoutineFlowScaffold(
      // 카드를 만든 순간 서버에 임시저장으로 남는다 — 나가도 날아가지 않는다 (#387).
      // 홈에서 편집하러 온 이미 저장한 일과는 뺀 카드만 저장하기를 기다린다.
      leave: routine?.status == 'PENDING_REVIEW'
          ? RoutineLeave.draft
          : RoutineLeave.edit,
      // 뒤로도 흐름을 떠난다 — 홈과 같이 묻고, 나가면 흐름을 연 화면(홈·임시저장)으로
      // 간다. 카드를 만든 뒤 흐름 안으로 되돌아가면 앞 화면들이 `남지 않아요` 라고
      // 사실과 다르게 말하고, 거기서 바꾼 보상·답은 다시 만들지 않아 버려진다 (#387 D1).
      backLeavesFlow: true,
      onBack: () => leaveRoutineFlow(context),
      bottomButton: ElumButton(label: '저장하기', onPressed: _save),
      aurora: CardReviewScreen.aurora,
      child: Column(
        children: [
          // 시안(262:5124)은 상단 아이콘이 110 에서 끝나고 반짝임이 117 에서
          // 시작한다 — 사이가 7 이다. 토큰(16)을 쓰면 12 내려간다 (#297).
          SizedBox(height: 4.h),
          SvgPicture.asset(
            AppAssets.iconSparklesLarge,
            width: 30.w,
            height: 36.h,
          ),
          SizedBox(height: space.md),
          Text(
            // 시안은 `카드 5개가 생성되었어요`인데 **피동형이라 쓸 수 없다**
            // (루트 CLAUDE.md 말투 규칙). 능동으로 바꿔 둔다.
            '카드 ${cards.length}개를 만들었어요',
            style: context.typo.reviewTitle.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
          // 시안은 제목이 190 에서 끝나고 카드가 바로 이어진다 — 토큰(24)을
          // 쓰면 카드가 17 내려간다 (#297).
          SizedBox(height: 7.h),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: cards.length,
              // 카드를 넘기면 수정 칩의 대상도 바뀐다
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) => Padding(
                padding: EdgeInsets.symmetric(horizontal: space.xs),
                child: ActionCardView(
                  key: ValueKey(cards[index].id),
                  card: cards[index],
                  index: index,
                  routineId: routineId,
                  onSpeak: () => _speak(cards[index]),
                  isSpeaking: _speakingId == cards[index].id,
                  // 마지막 한 장은 지울 수 없다 — 버튼 자체를 숨긴다
                  onDelete: cards.length > 1
                      ? () => ref
                            .read(routineFlowProvider.notifier)
                            .removeStep(cards[index].id)
                      : null,
                ),
              ),
            ),
          ),
          // **아래 간격을 md(16)가 아니라 xs(8)로 둔다.** 보상 줄(#239)이
          // 들어오면서 카드가 시안보다 41 짧아졌다. 셋을 줄여 24를 카드에
          // 돌려준다 — 그만큼 설명이 잘리는 양이 준다 (이슈 #335).
          SizedBox(height: space.xs),
          // 보상 줄 — 정한 것을 보여주고, 건너뛰었으면 여기서 정할 수 있다 (#239).
          _RewardRow(
            reward: routine?.hasReward ?? false ? routine!.rewardDisplay : null,
            onTap: () => context.push(Routes.routineReward, extra: true),
          ),
          SizedBox(height: space.xs),
          // 카드 삭제로 인덱스가 목록 밖을 가리킬 수 있어 clamp로 방어한다
          _EditChip(
            onTap: () => _edit(cards[_currentIndex.clamp(0, cards.length - 1)]),
          ),
          SizedBox(height: space.xs),
        ],
      ),
    );
  }
}

/// `이 카드 수정하기` 알약 칩 (Figma 262:5124 — 393:3995, r20, 패딩 10×20).
class _EditChip extends StatelessWidget {
  const _EditChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return AppPressable(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: context.colors.editChipBg,
          borderRadius: BorderRadius.circular(space.cardRadius.r),
        ),
        child: Text(
          // 시안 `262:5124` 문구 그대로 — `고치기`로 줄여 두었었다 (#297)
          '이 카드 수정하기',
          style: context.typo.editChipLabel.copyWith(
            color: context.colors.editChipLabel,
          ),
        ),
      ),
    );
  }
}

/// 카드가 없을 때. 로딩이 실패해도 여기까지 올 수 있다.
class _EmptyCards extends StatelessWidget {
  const _EmptyCards();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.space.screenH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '만들어진 카드가 없어요',
              textAlign: TextAlign.center,
              style: context.typo.promptTitle.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
            SizedBox(height: context.space.md),
            Text(
              // 에러 코드를 함께 보여줘야 제보를 추적할 수 있다
              '다시 만들어 주세요 (E-CARD)',
              style: context.typo.promptBody.copyWith(
                color: context.colors.promptMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 카드 검토의 보상 줄 (이슈 #239).
///
/// 보호자가 정한 보상을 여기서 다시 확인하고 고칠 수 있다.
/// **건너뛴 사람에게는 정하라고 권한다** — 카드를 다 보고 나서야 "무엇을 주지"가
/// 떠오르는 경우가 있다.
class _RewardRow extends StatelessWidget {
  const _RewardRow({required this.reward, required this.onTap});

  /// 정해진 보상 (`🍪 젤리 먹기`). null이면 아직 없다.
  final String? reward;
  final VoidCallback onTap;

  static const _padV = 10.0;
  static const _padH = 16.0;
  static const _radius = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final has = reward != null;

    return AppPressable(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: _padV.h, horizontal: _padH.w),
        decoration: BoxDecoration(
          color: has ? colors.rewardBannerBg : colors.editChipBg,
          borderRadius: BorderRadius.circular(_radius.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              has ? '다 하면 $reward' : '보상 정하기',
              style: context.typo.chipLabel.copyWith(color: colors.textPrimary),
            ),
            SizedBox(width: context.space.xs.w),
            Icon(
              has ? Icons.edit_outlined : Icons.add,
              size: context.space.checkSize.w,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

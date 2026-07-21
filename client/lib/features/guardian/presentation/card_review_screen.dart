import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../shared/models/action_card.dart';
import '../../child/data/speech_service.dart';
import '../application/routine_notifier.dart';
import 'widgets/action_card_view.dart';
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('소리를 재생할 수 없어요 (E-TTS)')),
    );
  }

  Future<void> _save() async {
    // 승인해야 아동 화면에 나간다
    await ref.read(routineFlowProvider.notifier).confirm();
    if (mounted) context.go(Routes.guardian);
  }

  @override
  Widget build(BuildContext context) {
    final routine = ref.watch(routineFlowProvider).routine;
    final cards = routine?.steps ?? const [];
    final routineId = routine?.id ?? '';
    final space = context.space;

    // 만들어진 카드가 없으면 확인할 것이 없다. 홈으로 돌려보낸다.
    if (cards.isEmpty) {
      return const RoutineFlowScaffold(child: _EmptyCards());
    }

    return RoutineFlowScaffold(
      onBack: () => context.pop(),
      bottomButton: ElumButton(label: '저장하기', onPressed: _save),
      child: Column(
        children: [
          SizedBox(height: space.md),
          SvgPicture.asset(
            AppAssets.iconSparklesLarge,
            width: 30.w,
            height: 36.h,
          ),
          SizedBox(height: space.md),
          Text(
            '카드 ${cards.length}개가 생성되었어요',
            style: context.typo.reviewTitle
                .copyWith(color: context.colors.textPrimary),
          ),
          SizedBox(height: space.sm),
          Text(
            '내용을 확인하고 카드를 수정하거나 삭제해주세요',
            style: context.typo.promptBody
                .copyWith(color: context.colors.promptMuted),
          ),
          SizedBox(height: space.lg),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: cards.length,
              itemBuilder: (context, index) => Padding(
                padding: EdgeInsets.symmetric(horizontal: space.xs),
                child: ActionCardView(
                  card: cards[index],
                  index: index,
                  routineId: routineId,
                  onSpeak: () => _speak(cards[index]),
                  isSpeaking: _speakingId == cards[index].id,
                  // 편집 화면이 Figma에 없어 자리만 만든다
                  onEdit: () {},
                ),
              ),
            ),
          ),
          SizedBox(height: space.md),
        ],
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
              style: context.typo.promptTitle
                  .copyWith(color: context.colors.textPrimary),
            ),
            SizedBox(height: context.space.md),
            Text(
              // 에러 코드를 함께 보여줘야 제보를 추적할 수 있다
              '다시 만들어 주세요 (E-CARD)',
              style: context.typo.promptBody
                  .copyWith(color: context.colors.promptMuted),
            ),
          ],
        ),
      ),
    );
  }
}

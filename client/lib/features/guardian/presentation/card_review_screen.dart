import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
          SvgPicture.asset(AppAssets.iconSparklesLarge, width: 30, height: 36),
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

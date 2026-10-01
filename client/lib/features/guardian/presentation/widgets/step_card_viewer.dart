import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../../../shared/models/action_card.dart';
import '../../../child/data/speech_service.dart';
import 'action_card_view.dart';

/// 일과 시트에서 카드를 눌러 **크게 보는** 화면 (Figma `보호자_홈_오늘일과_행동단계`
/// 1274:8864, #495).
///
/// 뒤는 검정 70% 로 덮고(`Scrim` 1274:8926) 카드 한 장을 카드확인 화면의 카드와 같은
/// 모양으로 세운다. 옆 카드가 좌우로 20 걸쳐 보여 넘겨 볼 수 있고, 오른쪽 위 `닫기`
/// (1274:9232)로 시트에 돌아온다.
///
/// 읽기만 한다 — 고치거나 지우는 길은 없다(그건 카드확인의 일이다). 그래서 카드에 삭제 X 를
/// 주지 않는다.
class StepCardViewer extends ConsumerStatefulWidget {
  const StepCardViewer({
    super.key,
    required this.cards,
    required this.initialIndex,
    this.routineId = '',
  });

  final List<ActionCard> cards;

  /// 처음 보여줄 카드.
  final int initialIndex;

  /// 카드 그림을 받아오는 데 쓴다. 비면 대체 일러스트를 그린다.
  final String routineId;

  /// 카드를 크게 연다. 카드가 없으면 아무것도 열지 않는다.
  static Future<void> show(
    BuildContext context, {
    required List<ActionCard> cards,
    required int initialIndex,
    String routineId = '',
  }) {
    if (cards.isEmpty) return Future.value();
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      // 배경 막을 읽어 줄 이름 — 기본값은 영어 `Dismiss` 로 읽힌다 (#393 S7)
      barrierLabel: '카드 닫기',
      // 시안 `Scrim` — 검정 70%
      barrierColor: Colors.black.withValues(alpha: 0.7),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, _, _) => StepCardViewer(
        cards: cards,
        initialIndex: initialIndex.clamp(0, cards.length - 1),
        routineId: routineId,
      ),
      transitionBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  /// 시안 실측 — 카드 333×410 @ (x30, y231) · 옆 카드 x=373 · `닫기` 40×40 @ (x328, y183).
  /// 카드확인 화면과 같은 값이다(#401).
  static const cardWidth = 333.0;
  static const cardHeight = 410.0;
  static const cardGap = 10.0;
  static const cardTop = 231.0;
  static const closeTop = 183.0;
  static const closeSize = 40.0;

  /// 한 장 폭을 카드+사이로 잘라야 가운데 카드가 x=30 에 서고 옆 카드가 20 보인다.
  static const _viewportFraction = (cardWidth + cardGap) / 393;

  @override
  ConsumerState<StepCardViewer> createState() => _StepCardViewerState();
}

class _StepCardViewerState extends ConsumerState<StepCardViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
    viewportFraction: StepCardViewer._viewportFraction,
  );

  /// 지금 읽고 있는 카드. 둘을 한꺼번에 읽지 않는다.
  String? _speakingId;

  @override
  void dispose() {
    // 읽는 중에 닫으면 소리가 남는다
    if (_speakingId != null) ref.read(speechServiceProvider).stop();
    _controller.dispose();
    super.dispose();
  }

  /// 카드를 읽어준다. 읽는 중에 다시 누르면 멈춘다 (카드확인과 같다).
  Future<void> _speak(ActionCard card) async {
    final speech = ref.read(speechServiceProvider);

    if (_speakingId == card.id) {
      await speech.stop();
      if (mounted) setState(() => _speakingId = null);
      return;
    }

    setState(() => _speakingId = card.id);
    final ok = await speech.speak('${card.displayTitle}. ${card.description}');
    if (!mounted) return;
    setState(() => _speakingId = null);

    if (!ok) {
      showFailure(
        context,
        null,
        title: '소리를 재생하지 못했어요',
        fallback: '휴대폰 소리를 켜고 다시 눌러주세요',
        fallbackCode: 'E-TTS',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.cards;

    return Material(
      // 막(barrier)이 이미 검정이다. 이 위젯은 투명하게 두고 카드만 세운다.
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned(
            top: StepCardViewer.cardTop.h,
            left: 0,
            right: 0,
            height: StepCardViewer.cardHeight.h,
            child: PageView.builder(
              controller: _controller,
              itemCount: cards.length,
              itemBuilder: (context, index) => Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: (StepCardViewer.cardGap / 2).w,
                ),
                child: ActionCardView(
                  key: ValueKey(cards[index].id),
                  card: cards[index],
                  index: index,
                  routineId: widget.routineId,
                  onSpeak: () => _speak(cards[index]),
                  isSpeaking: _speakingId == cards[index].id,
                ),
              ),
            ),
          ),
          Positioned(
            top: StepCardViewer.closeTop.h,
            // 시안 x=328 → 오른쪽에서 25
            right: 25.w,
            child: AppPressable(
              onTap: () => Navigator.of(context).maybePop(),
              scaleDown: AppPressable.scaleIcon,
              semanticLabel: '카드 닫기',
              child: SizedBox(
                width: StepCardViewer.closeSize.w,
                height: StepCardViewer.closeSize.w,
                child: SvgPicture.asset(
                  AppAssets.iconClose,
                  // 에셋은 어두운 색이다. 시안(1274:9232)의 X 는 어두운 막 위라 흰색이다.
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

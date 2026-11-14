import 'package:flutter/material.dart';

import '../assets/app_assets.dart';
import '../theme/theme_context_ext.dart';
import '../widgets/app_celebration.dart';
import '../widgets/app_count_up.dart';
import '../widgets/app_pop_in.dart';
import '../widgets/app_reveal.dart';
import '../widgets/elum_highlight.dart';
import '../widgets/elum_info_card.dart';

/// 개발자 도구 > 디자인 기반 미리 보기 (#1407): 공통 모션 · 작은 카드 · 하이라이트 · 축하 · 3D 그림 세트
/// 화면 적용 전(개편 단계 1~5) 부품을 실제 토큰으로 한 화면에서 확인. 문구는 예시라 번역하지 않음
class DevDesignShowcase extends StatefulWidget {
  const DevDesignShowcase({super.key});

  @override
  State<DevDesignShowcase> createState() => _DevDesignShowcaseState();
}

class _DevDesignShowcaseState extends State<DevDesignShowcase> {
  /// 다시 재생: 키를 바꿔 등장 연출을 처음부터
  int _replayCount = 0;

  static const _gridArtSize = 72.0;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    return Column(
      key: ValueKey(_replayCount),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: () => setState(() => _replayCount++), child: const Text('다시 재생')),
        ),
        ...revealInOrder([
          _label(context, '작은 카드 (그림 왼쪽 · 행동 · 닫기)'),
          ElumInfoCard(
            illustrationAsset: AppAssets.featureIconNotification,
            title: '알림을 켜 두세요',
            body: '이룸이가 일과를 마치면 바로 알려 드려요',
            actionLabel: '알림 켜기',
            onAction: () {},
            onTap: () {},
            onClose: () {},
            closeLabel: '닫기',
          ),
          SizedBox(height: space.sm),
          _label(context, '작은 카드 (그림 위)'),
          ElumInfoCard(
            illustrationAsset: AppAssets.emptyStateNoRoutines,
            layout: ElumInfoCardLayout.top,
            title: '아직 일과가 없어요',
            body: '첫 일과를 만들면 이룸이 기기로 보낼 수 있어요',
            actionLabel: '일과 만들기',
            onAction: () {},
          ),
          SizedBox(height: space.sm),
          _label(context, '하이라이트 띠'),
          const ElumHighlight(iconAsset: AppAssets.featureIconStreak, text: '3일 연속으로 일과를 마쳤어요'),
          SizedBox(height: space.xs),
          const ElumHighlight(
            iconAsset: AppAssets.featureIconLinkDevice,
            text: '이룸이 기기를 아직 연결하지 않았어요',
            tone: ElumHighlightTone.peach,
          ),
        ]),
        SizedBox(height: space.md),
        _label(context, '톡 튀어나옴 · 세며 올라가는 숫자'),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final (index, asset) in AppAssets.featureIcons.take(4).indexed)
              AppPopIn(
                delay: Duration(milliseconds: 80 * index),
                child: Image.asset(asset, width: _gridArtSize, height: _gridArtSize),
              ),
            AppCountUp(from: 0, to: 120, format: (value) => '$value', style: context.typo.creditNumber),
          ],
        ),
        SizedBox(height: space.md),
        _label(context, '보상 축하'),
        AppCelebration(
          illustrationAsset: AppAssets.celebrationStreak,
          title: '3일 연속이에요!',
          reasonText: '이룸이가 사흘 내내 일과를 끝까지 마쳤어요',
          gauge: AppCelebrationGauge(before: 2, after: 3, maximum: 7, valueFormat: (value) => '$value일'),
        ),
        SizedBox(height: space.lg),
        _label(context, '3D 그림 세트 (빈 상태 6 · 축하 4 · 기능 아이콘 12)'),
        _assetGrid(context, [
          ...AppAssets.emptyStateIllustrations,
          ...AppAssets.celebrationIllustrations,
          ...AppAssets.featureIcons,
        ]),
      ],
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: EdgeInsets.only(bottom: context.space.xs),
    child: Text(text, style: context.typo.caption.copyWith(color: context.colors.textSecondary)),
  );

  Widget _assetGrid(BuildContext context, List<String> assets) => Wrap(
    spacing: context.space.xs,
    runSpacing: context.space.xs,
    children: [
      for (final asset in assets)
        Container(
          color: context.colors.background,
          child: Image.asset(asset, width: _gridArtSize, height: _gridArtSize),
        ),
    ],
  );
}

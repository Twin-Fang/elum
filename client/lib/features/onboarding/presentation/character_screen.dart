import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/selectable_group.dart';
import '../application/onboarding_notifier.dart';
import '../domain/character.dart';
import 'widgets/character_card.dart';

/// Figma `온보딩_캐릭터` — 카드 속 주인공이 될 친구를 고른다.
///
/// 여기서 고르는 건 카드 콘텐츠의 주인공이다.
/// 채팅에서 말을 거는 병아리(AgentPersona)와는 다른 존재다.
class CharacterScreen extends ConsumerWidget {
  const CharacterScreen({super.key});

  /// 카드 사이 간격. Figma 카드 x=16/201에 폭이 176이므로 201-(16+176)=9다.
  static const _cardGap = 9.0;

  /// 카드 좌우 여백. 이 화면만 x=16이다 (다른 온보딩 화면은 24).
  static const _cardMarginH = 16.0;

  /// 제목·설명은 다른 화면과 같은 x=24다. 본문 여백을 16으로 낮췄으므로
  /// 헤더에만 차액 8을 되돌려준다.
  static const _headerExtraInset = 8.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    final selected = {
      if (profile.cardCharacter != null) profile.cardCharacter!,
    };

    // 2열 배치가 필요해 Column 기본 레이아웃 대신 buildItem으로 직접 배치한다
    final group = SelectableGroup<CardCharacter>(
      items: CardCharacter.values,
      selected: selected,
      // 반드시 하나는 골라야 하므로 해제를 막는다
      allowDeselect: false,
      onChanged: (next) {
        if (next.isNotEmpty) notifier.setCharacter(next.first);
      },
      itemBuilder: (context, character, isSelected) =>
          CharacterCard(character: character, isSelected: isSelected),
    );

    return ElumScaffold(
      onBack: () => context.pop(),
      // Figma 카드가 x=16에서 시작한다 — 기본 24를 쓰면 카드가 8씩 좁아진다
      horizontalPadding: _cardMarginH,
      bottomButton: ElumButton(
        label: '다음',
        onPressed: profile.canProceedFromCharacter
            ? () => context.push(Routes.onboardingPin)
            : null,
      ),
      // 작은 기기에서 카드(202px)가 잘리지 않게 스크롤을 허용한다
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _headerExtraInset,
              ),
              child: ElumHeader(
                title: '${profile.displayName}의 하루를 함께할\n친구를 골라주세요',
                description: '선택한 친구가 카드 속 주인공이 되어 도와줘요',
              ),
            ),
            SizedBox(height: context.space.xl),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final character in CardCharacter.values) ...[
                  Expanded(child: group.buildItem(context, character)),
                  // Figma 카드 x=16/201, 폭 176 → 사이 간격 9
                  if (character != CardCharacter.values.last)
                    SizedBox(width: _cardGap),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

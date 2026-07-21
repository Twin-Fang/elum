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
      bottomButton: ElumButton(
        label: '다음',
        onPressed: profile.canProceedFromCharacter
            ? () => context.push(Routes.onboardingPin)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElumHeader(
            title: '${profile.childNickname}의 하루를 함께할\n친구를 골라주세요',
            description: '선택한 친구가 카드 속 주인공이 되어 도와줘요',
          ),
          SizedBox(height: context.space.xl),
          Row(
            children: [
              for (final character in CardCharacter.values) ...[
                Expanded(child: group.buildItem(context, character)),
                if (character != CardCharacter.values.last)
                  SizedBox(width: context.space.sm),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

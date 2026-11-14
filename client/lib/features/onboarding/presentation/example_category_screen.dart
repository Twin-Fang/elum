import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/batchim.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_secondary_button.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/selectable_group.dart';
import '../../../shared/models/routine_example_category.dart';
import '../application/onboarding_notifier.dart';
import 'widgets/example_category_chip.dart';

/// 온보딩 예시 분류 선택 (#803): 고른 분류의 예시 일과를 홈에 넣는다
///
/// 옛 도움 목표 화면 자리. 여러 개 고를 수 있고, 건너뛰면 예시 없이 진행한다.
class ExampleCategoryScreen extends ConsumerWidget {
  const ExampleCategoryScreen({super.key});

  /// 칩 사이 간격 — 옛 목표 칩과 같은 18
  static const _chipGap = 18.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final name = profile.displayName;

    return ElumScaffold(
      onBack: context.popOrHome,
      bottomButton: ElumButton(
        label: context.l10n.commonNext,
        onPressed: profile.canProceedFromExampleCategories
            ? () => context.push(Routes.onboardingCharacter)
            : null,
      ),
      // 건너뛰기 — 연결 암호 화면의 "나중에 하기"와 같은 보조 버튼
      belowButton: ElumSecondaryButton(
        label: context.l10n.onboardingExampleSkip,
        onTap: () {
          notifier.clearExampleCategories();
          context.push(Routes.onboardingCharacter);
        },
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElumHeader(
              // 단계 그림: 달력 3D (하루 일과 예시)
              illustrationAsset: AppAssets.featureIconCalendar,
              shouldRevealOnEnter: true,
              title: context.l10n.onboardingExampleTitle(name, batchimOf(name)),
              description: context.l10n.onboardingExampleDescription,
              hasBackButton: true,
            ),
            SizedBox(height: context.space.headerToContent),
            SelectableGroup<RoutineExampleCategory>(
              items: RoutineExampleCategory.values,
              selected: profile.exampleCategories,
              multiSelect: true,
              gap: _chipGap,
              onChanged: notifier.setExampleCategories,
              itemBuilder: (context, category, isSelected) =>
                  ExampleCategoryChip(
                    category: category,
                    isSelected: isSelected,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

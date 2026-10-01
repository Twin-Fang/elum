import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_header.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/selectable_group.dart';
import '../application/onboarding_notifier.dart';
import '../domain/character.dart';
import '../domain/image_style.dart';
import 'widgets/image_style_option_card.dart';

/// 온보딩의 `그림 방식` 단계 — 캐릭터 다음, 비밀암호 앞 (이슈 #458).
///
/// Figma `그림방식` 1274:9883 · 1274:10129 (#494). 정식 시안으로 바꿨다 — 제목·설명은
/// 다른 온보딩과 같은 x=24 이고 카드 셋은 344×94, 사이 16, 첫 카드 윗변 y=279 다.
///
/// 원칙 ④ — 되돌릴 수 있다고 먼저 말하고(`나중에 설정에서 바꿀 수 있어요`)
/// `건너뛰기`를 늘 연다. 건너뛰면 만화다.
///
/// 선택은 여기서 저장하지 않는다. 온보딩이 끝날 때 [OnboardingNotifier.complete]가
/// 호칭·목표·캐릭터와 함께 한꺼번에 남긴다 — 뒤로가기로 돌아와도 고른 값이 살아 있다.
///
/// **서비스 원칙 1(진단명·장애 유형 수집 금지)과 무관하다.** 이룸이가 어떤 사람인지가
/// 아니라 카드 그림을 어떤 방식으로 만들지를 묻는다.
class ImageStyleScreen extends ConsumerWidget {
  const ImageStyleScreen({super.key});

  /// 카드 사이 (시안 279 → 389 → 499, 카드 높이 94)
  static const _cardGap = 16.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final colors = context.colors;
    final space = context.space;

    final character = profile.cardCharacter ?? CardCharacter.cat;

    final group = SelectableGroup<ImageStyle>(
      items: ImageStyle.values,
      selected: {profile.imageStyle},
      // 늘 하나가 골라져 있어야 한다 — 해제를 막는다
      allowDeselect: false,
      gap: _cardGap.h,
      asRadio: true,
      onChanged: (next) {
        if (next.isNotEmpty) notifier.setImageStyle(next.first);
      },
      itemBuilder: (context, style, isSelected) => ImageStyleOptionCard(
        style: style,
        isSelected: isSelected,
        character: character,
      ),
      semanticLabelOf: ImageStyleOptionCard.semanticLabel,
    );

    return ElumScaffold(
      onBack: () => context.pop(),
      // 만화가 처음부터 골라져 있어 다음은 늘 열려 있다
      bottomButton: ElumButton(
        label: '다음',
        onPressed: () => context.push(Routes.onboardingPin),
      ),
      belowButton: Center(
        child: AppPressable(
          // 건너뛰면 만화다 — 다른 걸 골랐다가 건너뛰어도 기본으로 돌아온다
          onTap: () {
            notifier.setImageStyle(ImageStyle.cartoon);
            context.push(Routes.onboardingPin);
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: space.xs.h),
            child: Text(
              '건너뛰기',
              style: context.typo.linkLater.copyWith(
                color: colors.linkLaterLabel,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ),
      // 글자를 키우면 제목 두 줄과 카드 셋이 한 화면을 넘는다 — 스크롤로 끝까지 본다
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ElumHeader(
              title: '카드 그림은 어떤 방식으로\n만들까요?',
              description: '나중에 설정에서 바꿀 수 있어요',
              hasBackButton: true,
            ),
            SizedBox(height: space.headerToContent),
            group,
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }
}

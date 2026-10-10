import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/state/busy_state_mixin.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_spinner.dart';
import '../../../core/widgets/selectable_group.dart';
import '../../../core/widgets/show_failure.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../../../shared/models/character.dart';
import '../../onboarding/domain/image_style.dart';
import '../../onboarding/presentation/widgets/image_style_option_card.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/widgets/elum_toast.dart';

/// 보호자 설정의 `그림 방식` 선택 화면.
///
/// 카드는 온보딩 시안(`1274:9883`)과 같은 모양이다. 설정 화면 자체의 시안은 아직 없다.
/// 카드를 누르면
/// 바로 저장하고 설정으로 돌아간다 — 셋 중 하나를 고르는 화면에 `저장` 단추까지 두면
/// 결정이 둘이 된다(원칙 ① 화면 하나에 결정 하나).
///
/// **보호자 전용이다.** 이룸이 화면에는 이 화면으로 오는 길이 없다 — 이룸이가 카드
/// 그림 방식을 바꿀 이유가 없고, 보호자 화면은 PIN 을 거쳐야 열린다.
class ImageStyleSettingsScreen extends ConsumerStatefulWidget {
  const ImageStyleSettingsScreen({super.key});

  @override
  ConsumerState<ImageStyleSettingsScreen> createState() =>
      _ImageStyleSettingsScreenState();
}

class _ImageStyleSettingsScreenState
    extends ConsumerState<ImageStyleSettingsScreen>
    with BusyStateMixin<ImageStyleSettingsScreen> {
  /// 서버 저장에 실패한 방식. **로컬에는 남았지만 서버는 아직 모른다.**
  ///
  /// 실패 팝업이 "다시 시도"를 말하는데 같은 방식을 다시 눌러도 아무 일이 없으면
  /// 막다른 길이다. 이 값과 같은 방식을 누르면 다시 저장을 시도한다.
  ImageStyle? _unsynced;

  Future<void> _choose(ImageStyle picked) async {
    if (busy) return;

    final current = ref.read(onboardingProvider).imageStyle;
    // 이미 고른 방식을 다시 누르면 바뀔 것이 없다 — 요청도 알림도 없이 돌아간다.
    if (picked == current && _unsynced != picked) {
      context.popOrHome();
      return;
    }

    // 결과가 null(성공)과 구분되도록 레코드로 감싼다. 바깥이 null 이면 진행 중이라 실행하지 않은 것.
    final result = await runBusy(
      () async =>
          (await ref.read(onboardingProvider.notifier).changeImageStyle(picked),),
      key: picked,
    );
    if (result == null || !mounted) return;
    final failure = result.$1;

    if (failure == null) {
      _unsynced = null;
      // 성공 알림은 스낵바다 — 실패만 팝업으로 막는다.
      final messenger = ScaffoldMessenger.maybeOf(context);
      final changedText = context.l10n.imageStyleChangedSnack;
      context.popOrHome();
      showElumToastOn(messenger, changedText);
      return;
    }

    // 로컬에는 고른 값이 남아 있다. 화면은 그대로 두고 이유와 에러 코드만 알린다.
    _unsynced = picked;
    await showFailure(
      context,
      failure,
      title: context.l10n.imageStyleSaveFailedTitle,
      fallback: context.l10n.imageStyleSaveFailedFallback,
      fallbackCode: 'E-STYLE',
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(onboardingProvider);
    // 만화 예시에는 온보딩에서 고른 친구를 그린다 (없으면 고양이)
    final character = profile.cardCharacter ?? CardCharacter.cat;

    final group = SelectableGroup<ImageStyle>(
      items: ImageStyle.values,
      selected: {profile.imageStyle},
      // 셋 중 하나가 늘 골라져 있다. 같은 것을 다시 누른 것은 [_choose]가 처리한다.
      allowDeselect: true,
      gap: 12.h,
      asRadio: true,
      onChanged: (next) =>
          _choose(next.isEmpty ? profile.imageStyle : next.first),
      itemBuilder: (context, style, isSelected) {
        final card = ImageStyleOptionCard(
          style: style,
          isSelected: isSelected,
          character: character,
        );
        if (!isBusy(style)) return card;
        // 저장 중인 카드는 라디오 자리에 스피너를 얹는다.
        return Stack(
          children: [
            card,
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(right: 14.w),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.colors.surface,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(2.w),
                      child: ElumSpinner(size: 20.w),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      semanticLabelOf: ImageStyleOptionCard.semanticLabel,
    );

    return ElumScaffold(
      onBack: busy ? null : context.popOrHome,
      title: context.l10n.imageStyleTitle,
      // 설정 묶음 시안(1022:4467)과 같은 머리 — 뒤로가기 y=67, 좌우 16
      backTop: 67,
      horizontalPadding: 16,
      // 글자를 키우면 카드 셋이 한 화면을 넘는다 — 스크롤로 끝까지 볼 수 있게 한다
      child: SingleChildScrollView(
        child: Padding(
          // 설정 첫 줄과 같은 자리(y=147)에서 시작한다
          padding: EdgeInsets.only(top: 40.h, bottom: 24.h),
          child: group,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/state/busy_state_mixin.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/selectable_group.dart';
import '../../../core/widgets/show_failure.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../../../shared/models/character.dart';
import '../../onboarding/domain/image_style.dart';
import '../../onboarding/presentation/widgets/image_style_credit_bar.dart';
import '../../onboarding/presentation/widgets/image_style_option_card.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/widgets/elum_toast.dart';

/// 보호자 설정의 `그림 방식` 선택 화면.
///
/// 카드는 온보딩 시안(`1274:9883`)과 같은 모양이다. 설정 화면 자체의 시안은 아직 없다.
/// 카드를 누르면 선택과 크레딧 띠만 바뀌고, `확인`을 눌러야 저장하고 설정으로 돌아간다.
/// 고른 방식의 크레딧 비용을 보고 정할 수 있어야 한다. 뒤로가기는 저장하지 않는다.
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
  /// 화면에서 고른 방식. `확인` 전까지는 저장하지 않는다 (처음 값: 저장된 방식)
  late ImageStyle _pickedStyle = ref.read(onboardingProvider).imageStyle;

  /// 확인: 바뀐 것 없으면 그냥 돌아감 > 저장 > 성공 시 돌아가 알림, 실패 시 팝업
  Future<void> _confirm() async {
    final savedStyle = ref.read(onboardingProvider).imageStyle;
    if (_pickedStyle == savedStyle) {
      context.popOrHome();
      return;
    }

    // 결과가 null(성공)과 구분되도록 레코드로 감싼다. 바깥이 null 이면 진행 중이라 실행하지 않은 것.
    final result = await runBusy(
      () async => (
        await ref
            .read(onboardingProvider.notifier)
            .changeImageStyle(_pickedStyle),
      ),
    );
    if (result == null || !mounted) return;
    final failure = result.$1;

    if (failure == null) {
      // 성공 알림은 스낵바다 — 실패만 팝업으로 막는다.
      final messenger = ScaffoldMessenger.maybeOf(context);
      final changedText = context.l10n.imageStyleChangedSnack;
      context.popOrHome();
      showElumToastOn(messenger, changedText);
      return;
    }

    // 저장값은 이전으로 되돌아갔다. 고른 방식은 화면에 남겨 확인으로 다시 시도한다.
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
      selected: {_pickedStyle},
      // 늘 하나가 골라져 있어야 한다 — 해제를 막는다
      allowDeselect: false,
      gap: 12.h,
      asRadio: true,
      onChanged: (next) {
        // 저장 중에는 고른 값을 바꾸지 않는다
        if (busy || next.isEmpty) return;
        setState(() => _pickedStyle = next.first);
      },
      itemBuilder: (context, style, isSelected) => ImageStyleOptionCard(
        style: style,
        isSelected: isSelected,
        character: character,
      ),
      semanticLabelOf: ImageStyleOptionCard.semanticLabel,
    );

    return ElumScaffold(
      onBack: context.popOrHome,
      isBackEnabled: !busy,
      title: context.l10n.imageStyleTitle,
      // 설정 묶음 시안(1022:4467)과 같은 머리 — 뒤로가기 y=67, 좌우 16
      backTop: 67,
      horizontalPadding: 16,
      bottomButton: ElumButton(
        label: context.l10n.commonConfirm,
        loading: busy,
        onPressed: _confirm,
      ),
      // 글자를 키우면 카드 셋이 한 화면을 넘는다 — 스크롤로 끝까지 볼 수 있게 한다
      child: SingleChildScrollView(
        child: Padding(
          // 설정 첫 줄과 같은 자리(y=147)에서 시작한다
          padding: EdgeInsets.only(top: 40.h, bottom: 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 고른 방식의 비용을 보여 준다 (저장 전)
              ImageStyleCreditBar(style: _pickedStyle),
              SizedBox(height: 12.h),
              group,
            ],
          ),
        ),
      ),
    );
  }
}

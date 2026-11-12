import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../../../shared/models/character.dart';
import '../../../../shared/models/image_style.dart';
import '../../../onboarding/application/onboarding_notifier.dart';
import '../../../profile/application/image_style_sheet_entry.dart';
import '../../../subscription/application/plan_paywall_entry.dart';

/// 일과 만들기의 그림 방식 알약 (#1287): `카드 그림 · [예시] 이모지 그림 ›`
///
/// 누르면 그림 방식 시트(이룸이 정보와 같은 시트) > 고르면 바로 저장 (설정 그림 방식과 같은 저장 경로)
/// 방식이 바뀌면 예시·이름이 가볍게 바뀌는 모습으로 바뀜. 저장 실패면 원래 값 + 실패 팝업(에러 코드)
class RoutineImageStylePill extends ConsumerStatefulWidget {
  const RoutineImageStylePill({super.key});

  static const pillKey = Key('routineImageStylePill');

  @override
  ConsumerState<RoutineImageStylePill> createState() => _RoutineImageStylePillState();
}

class _RoutineImageStylePillState extends ConsumerState<RoutineImageStylePill> {
  /// 예시 그림 22 · 안쪽 여백 가로 14 세로 8 · 글자 사이 6
  static const _thumbnailSize = 22.0;
  static const _padH = 14.0;
  static const _padV = 8.0;
  static const _gap = 6.0;
  static const _chevronSize = 14.0;

  /// 저장 중 (연타 막기)
  bool _isSaving = false;

  /// 시트 > 고른 방식 저장 (지금 값이면 시트가 저장을 막아 null)
  Future<void> _changeImageStyle() async {
    if (_isSaving) return;
    final profile = ref.read(onboardingProvider);
    final picked = await openImageStyleSheet(
      context,
      current: profile.imageStyle,
      character: profile.cardCharacter ?? CardCharacter.cat,
    );
    if (picked == null || !mounted) return;
    setState(() => _isSaving = true);
    final failure = await ref.read(onboardingProvider.notifier).changeImageStyle(picked);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (failure == null) return;
    // Pro 가 끝나 서버가 거절(403)했으면 실패 팝업 대신 Pro 안내 (#1149)
    if (await handleProOnlyRejection(context, ref, failure)) return;
    if (!mounted) return;
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
    final colors = context.colors;
    final style = ref.watch(onboardingProvider.select((profile) => profile.imageStyle));
    return Semantics(
      button: true,
      label: context.l10n.routineImageStylePillSemantics(style.label),
      excludeSemantics: true,
      child: AppPressable(
        key: RoutineImageStylePill.pillKey,
        onTap: _isSaving ? null : _changeImageStyle,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: _padH.w, vertical: _padV.h),
          decoration: BoxDecoration(
            color: colors.glassChip,
            borderRadius: BorderRadius.circular(context.space.pillRadius.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.routineImageStylePillLabel,
                style: context.typo.caption.copyWith(color: colors.textSecondary),
              ),
              SizedBox(width: _gap.w),
              // 방식이 바뀌면 예시·이름이 살짝 커지며 나타남
              AnimatedSwitcher(
                duration: AppMotion.fast,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: Row(
                  key: ValueKey(style),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StyleThumbnail(style: style, size: _thumbnailSize.w),
                    SizedBox(width: _gap.w),
                    Text(
                      style.label,
                      style: context.typo.chipLabel.copyWith(color: colors.chipLabel),
                    ),
                  ],
                ),
              ),
              SizedBox(width: _gap.w),
              SvgPicture.asset(
                AppAssets.iconAngleSmall,
                width: _chevronSize.w,
                height: _chevronSize.w,
                // 위쪽 화살표 에셋을 오른쪽으로 눕힘 (누르면 다른 곳이 열린다는 신호)
                colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
              ).rotatedRight(),
            ],
          ),
        ),
      ),
    );
  }
}

/// 방식 > 작은 예시 그림 (그림 방식 고르기 카드의 예시와 같은 그림)
class _StyleThumbnail extends StatelessWidget {
  const _StyleThumbnail({required this.style, required this.size});

  final ImageStyle style;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Widget picture = switch (style) {
      ImageStyle.emoji => SvgPicture.asset(AppAssets.imageStyleEmoji, fit: BoxFit.contain),
      ImageStyle.symbol => SvgPicture.asset(AppAssets.imageStyleSymbol, fit: BoxFit.contain),
      ImageStyle.character => Image.asset(AppAssets.imageStyleCartoon, fit: BoxFit.cover),
      ImageStyle.realistic => Image.asset(AppAssets.imageStyleRealistic, fit: BoxFit.cover),
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 4),
      child: SizedBox.square(dimension: size, child: picture),
    );
  }
}

extension on Widget {
  /// 위쪽 화살표 > 오른쪽 화살표 (90도)
  Widget rotatedRight() => RotatedBox(quarterTurns: 1, child: this);
}

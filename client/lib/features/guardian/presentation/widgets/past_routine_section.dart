import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/config/ad_ids.dart';
import '../../../ads/presentation/ad_banner_slot.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../../../core/widgets/elum_error_view.dart';
import 'routine_detail_sheet.dart';
import '../../../../shared/models/routine.dart';
import 'grey_tile_shell.dart';
import 'routine_loading_tile.dart';
import 'routine_tile_gap.dart';
import 'empty_past_label.dart';
import 'routine_summary_tile.dart';
import '../../../../core/widgets/elum_toast.dart';
import '../../application/guardian_home_controller.dart';
import '../../application/home_routines.dart';
import '../../application/routine_providers.dart';

/// 지난 일과 사이 광고가 일과 카드와 떨어지는 만큼 더한 간격(오클릭 방지).
/// 광고가 없으면 이 간격도 없다.
const _adExtraGap = 8.0;

/// 광고가 목록 끝에 붙을 때(지난 일과 1개) 아래로 더 띄우는 간격.
///
/// 끝에 붙으면 바로 아래가 하단 고정 배너라 광고 둘이 가깝게 보인다. 오클릭을 줄이려고
/// 사이 광고(아래 8)보다 넓게 띄운다.
const _adTrailingGap = 24.0;

/// 광고를 끼울 일과 순번(이 일과 다음). 지난 일과가 1개 이상일 때만 부른다.
///
/// 3개 이상이면 두 번째 다음, 2개면 첫 번째 다음이라 광고는 언제나 일과 **사이**에 든다
/// (오클릭 방지 의도). 1개만 사이가 없어 끝에 붙는다. 0개면 넣지 않는다 —
/// 빈 상태 아래에 두면 하단 배너와 함께 내용 없는 화면에 광고 둘이 붙어 AdMob 정책 위험이 있다.
int _inlineAdAfterIndex(int count) => count >= 3 ? 1 : 0;

/// 보호자 홈 `지난 일과` (Figma 931:3896 — 지난일과_1).
///
/// 오늘 목록과 달리 **밀리지도 않고 순서도 바꾸지 않는다.** 지나간 것을
/// 고칠 일이 없고, 순서는 날짜가 정한다.
///
/// 다 끝낸 일과에만 `일과 다시하기`가 붙는다 — 그대로 한 번 더 시킬 값어치가
/// 있다는 뜻이고, 하다 만 것을 복제하면 같은 일과가 둘이 되어 헷갈린다.
class PastRoutineSection extends ConsumerStatefulWidget {
  const PastRoutineSection({super.key});

  @override
  ConsumerState<PastRoutineSection> createState() => _PastRoutineSectionState();
}

class _PastRoutineSectionState extends ConsumerState<PastRoutineSection> {
  /// 다시 만드는 중인 일과. 두 번 눌러 둘이 생기는 것을 막는다.
  String? _rerunning;

  /// 지난 일과 시트를 띄우고, `일과 다시하기`를 누르면 오늘로 복제한다.
  ///
  /// 복제는 타일의 다시하기와 **같은 길을 쓴다** — 두 자리에서 각각 만들면
  /// 한쪽만 고쳐져 어긋난다.
  Future<void> _openPastSheet(Routine routine) async {
    final action = await RoutineDetailSheet.show(
      context,
      routine,
      isPast: true,
    );
    if (action != RoutineSheetAction.rerun || !mounted) return;
    await _rerun(routine);
  }

  Future<void> _rerun(Routine routine) async {
    final l10n = context.l10n;
    if (_rerunning != null) return;
    setState(() => _rerunning = routine.id);

    final copy = await ref
        .read(guardianHomeControllerProvider)
        .duplicate(routine.id);
    if (!mounted) return;
    setState(() => _rerunning = null);

    if (!copy.isOk) {
      showFailure(
        context,
        copy.failure,
        title: l10n.todayRoutineRerunFailedTitle,
        fallback: l10n.todayRoutineRerunFailedFallback,
        fallbackCode: 'E-DUP',
      );
      return;
    }
    ref.refreshRoutines();
    showElumToast(context, l10n.todayRoutineCopied(copy.value!.displayTitle));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pastRoutinesProvider);
    final routines = async.value ?? const <Routine>[];
    // 일과가 적으면 사이 광고를 끼우지 않는다 (하단 배너와 같은 기준)
    final shouldShowAds = ref.watch(shouldShowHomeAdsProvider);
    final shouldShowCreator = ref.watch(shouldShowRoutineCreatorProvider);

    if (routines.isEmpty) {
      if (async.hasError) {
        return GreyTileShell(
          // 세 줄(문구·안내·다시 시도)이 들어간다.
          height: greyTileErrorShellHeight,
          child: ElumErrorView.failure(
            async.error,
            fallback: context.l10n.todayRoutinePastLoadFailedFallback,
            fallbackCode: 'E-PAST',
            onRetry: () => ref.invalidate(pastRoutinesProvider),
            compact: true,
          ),
        );
      }
      return async.isLoading
          ? const RoutineLoadingTile()
          : const GreyTileShell(child: EmptyPastLabel());
    }

    return Column(
      children: [
        for (final (index, routine) in routines.indexed) ...[
          if (index > 0) SizedBox(height: routineTileGap.h),
          Builder(
            builder: (context) {
              // **날짜와 다시하기를 붙이지 않는다.** 시안(931:3896)에서 둘 다
              // 빠졌다 — 지난 일과도 오늘 일과와 같은 68 짜리 줄이다.
              // 다시하기는 줄을 눌러 여는 시트 안에 있다.
              return RoutineSummaryTile(
                routine: routine,
                // 지난 일과는 서버가 셈해 둔 값이 기준이다. 기기 기록은 오늘 것만 있다.
                progress: routine.progressPercent / 100,
                creatorName: shouldShowCreator
                    ? routine.creatorDisplayName
                    : null,
                // 시안(980:4777)에는 지난 일과를 눌러 여는 시트가 있는데 화면이
                // 없었다. 로 목록 자체가 안 보이던 동안 아무도 열어 보지
                // 못해 빠진 것이 드러나지 않았다.
                onTap: () => _openPastSheet(routine),
                highlighted: _rerunning == routine.id,
              );
            },
          ),
          // 지난 일과 배너 광고 한 개. 로드에 실패하면 항목 자체가
          // 없어 빈 자리가 남지 않는다. 오늘 일과에는 끼우지 않는다.
          if (shouldShowAds && index == _inlineAdAfterIndex(routines.length))
            AdBannerSlot(
              placement: AdPlacement.bannerHomeMiddle,
              style: AdBannerStyle.inlineCard,
              padding: EdgeInsets.only(
                top: (routineTileGap + _adExtraGap).h,
                // 마지막 줄 다음이면 아래가 하단 배너다 — 더 띄운다.
                bottom:
                    (index == routines.length - 1
                            ? _adTrailingGap
                            : _adExtraGap)
                        .h,
              ),
            ),
        ],
      ],
    );
  }
}

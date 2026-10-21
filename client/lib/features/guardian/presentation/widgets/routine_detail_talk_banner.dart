import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../talk/application/talk_post_origin_provider.dart';

/// 가져온 일과 상세 맨 위 한 줄 띠: [이야기 아이콘] 이야기에서 가져왔어요 ... 원래 글 ›
/// 글을 받는 동안은 비워 두고, 글이 내려갔거나 못 받았으면 오른쪽만 "내려간 글"(누를 수 없음)
class RoutineDetailTalkBanner extends ConsumerWidget {
  const RoutineDetailTalkBanner({super.key, required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final originState = ref.watch(talkPostOriginProvider(postId));
    // 받는 중: 비워 둔다 (실패는 아래에서 "내려간 글"로 보인다)
    if (originState.isLoading && !originState.hasValue) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final colors = context.colors;
    final space = context.space;
    final isPostAvailable = originState.value?.isPostAvailable ?? false;

    final band = Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: space.sm.w,
        vertical: space.xs.h,
      ),
      decoration: BoxDecoration(
        color: colors.talkOriginBandFill,
        border: Border.all(
          color: colors.goalSelectedBorder,
          width: space.borderWidth,
        ),
        borderRadius: BorderRadius.circular(space.checkRadius.r),
      ),
      child: Row(
        children: [
          Container(
            width: space.iconSm.w,
            height: space.iconSm.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.goalSelectedBorder,
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              AppAssets.navComment,
              width: space.sm.w,
              height: space.sm.w,
              colorFilter: ColorFilter.mode(colors.surface, BlendMode.srcIn),
            ),
          ),
          SizedBox(width: space.xs.w),
          Expanded(
            child: Text(
              l10n.routineDetailTalkOriginBand,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typo.caption.copyWith(color: colors.textPrimary),
            ),
          ),
          SizedBox(width: space.xs.w),
          Text(
            isPostAvailable
                ? '${l10n.routineDetailTalkOriginOpenPost} ›'
                : l10n.routineDetailTalkOriginPostGone,
            style: context.typo.caption.copyWith(
              color: isPostAvailable
                  ? colors.talkOriginBandAction
                  : colors.textSecondary,
              fontWeight: isPostAvailable ? FontWeight.w700 : null,
            ),
          ),
        ],
      ),
    );

    if (!isPostAvailable) return band;
    return AppPressable(
      onTap: () => _openOriginalPost(context),
      semanticLabel: l10n.routineDetailTalkOriginBandOpenLabel,
      child: band,
    );
  }

  /// 시트를 닫고 글 상세로: 시트 위에 화면이 얹히지 않게 닫은 뒤 민다
  void _openOriginalPost(BuildContext context) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(Routes.guardianTalkPostOf(postId));
  }
}

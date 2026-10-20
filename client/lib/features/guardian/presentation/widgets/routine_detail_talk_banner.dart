import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/content_locale.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../talk/application/talk_post_origin_provider.dart';

/// 가져온 일과 상세 맨 위 안내: "📖 {닉네임}님이 이야기에 나눈 일과예요" > 원래 한마디 > 원래 글 보기
/// 글을 받는 동안은 비워 두고, 글이 내려갔거나 못 받았으면 닉네임·한마디·링크 없이 첫 줄만 보인다
class RoutineDetailTalkBanner extends ConsumerWidget {
  const RoutineDetailTalkBanner({
    super.key,
    required this.postId,
    required this.language,
  });

  final String postId;

  /// 한마디(보호자가 쓴 글)의 언어
  final String language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final origin = ref.watch(talkPostOriginProvider(postId)).value;
    if (origin == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final colors = context.colors;
    final space = context.space;
    final nickname = origin.authorNickname;
    final note = origin.note;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(space.sm.w),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(space.cardRadius.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nickname == null
                ? l10n.routineDetailTalkOriginBannerNoAuthor
                : l10n.routineDetailTalkOriginBanner(nickname),
            style: context.typo.tileLabel.copyWith(color: colors.textPrimary),
          ),
          if (note != null) ...[
            SizedBox(height: space.xs.h),
            ContentLocale(
              language: language,
              child: Text(
                note,
                style: context.typo.body.copyWith(color: colors.textSecondary),
              ),
            ),
          ],
          if (origin.isPostAvailable) ...[
            SizedBox(height: space.xs.h),
            AppPressable(
              onTap: () => _openOriginalPost(context),
              child: Text(
                l10n.routineDetailTalkOriginOpen,
                style: context.typo.caption.copyWith(
                  color: colors.textPrimary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 시트를 닫고 글 상세로: 시트 위에 화면이 얹히지 않게 닫은 뒤 민다
  void _openOriginalPost(BuildContext context) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(Routes.guardianTalkPostOf(postId));
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_state_body.dart';
import '../../../core/widgets/elum_toast.dart';
import '../../../core/widgets/show_failure.dart';
import '../application/talk_blocks_controller.dart';
import '../domain/talk_block_entry.dart';
import '../domain/talk_screen_codes.dart';

/// 숨긴 보호자 목록 (내 정보 > 숨긴 보호자): 닉네임 + "다시 보기"로 숨김 풀기
/// 상태: 받는 중 / 0건 / 실패(다시 하기 + 에러 코드) / 목록
class TalkBlockedGuardiansScreen extends ConsumerWidget {
  const TalkBlockedGuardiansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final blocks = ref.watch(talkBlocksControllerProvider);

    return ElumScaffold(
      onBack: context.popOrHome,
      title: l10n.talkBlockedGuardiansTitle,
      backTop: 67,
      horizontalPadding: 16,
      child: switch (blocks) {
        AsyncData(value: final entries) when entries.isEmpty => ElumStateBody(
          child: Text(
            l10n.talkBlockedGuardiansEmpty,
            textAlign: TextAlign.center,
            style: context.typo.sectionTitle.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
        ),
        AsyncData(value: final entries) => ListView.separated(
          padding: EdgeInsets.symmetric(vertical: context.space.md.h),
          itemCount: entries.length,
          separatorBuilder: (_, _) => SizedBox(height: context.space.xs.h),
          itemBuilder: (context, index) => _BlockedRow(
            key: ValueKey(entries[index].blockId),
            entry: entries[index],
            onUnblockPressed: () => _unblock(context, ref, entries[index]),
          ),
        ),
        AsyncError(:final error) => ElumStateBody(
          child: ElumErrorView.failure(
            error,
            fallback: l10n.talkBlockedGuardiansFailed,
            fallbackCode: TalkScreenCodes.block,
            onRetry: () => ref.invalidate(talkBlocksControllerProvider),
          ),
        ),
        _ => const ElumStateBody.loading(),
      },
    );
  }

  /// 숨김 풀기 > 토스트. 실패하면 목록은 그대로 두고 팝업으로 알린다
  Future<void> _unblock(
    BuildContext context,
    WidgetRef ref,
    TalkBlockEntry entry,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref
          .read(talkBlocksControllerProvider.notifier)
          .unblock(entry.blockId);
    } catch (e) {
      if (!context.mounted) return;
      await showFailure(
        context,
        e,
        title: l10n.talkUnblockFailedTitle,
        fallback: l10n.talkFailedFallback,
        fallbackCode: TalkScreenCodes.block,
      );
      return;
    }
    showElumToastOn(messenger, l10n.talkUnblockDone);
  }
}

/// 숨긴 보호자 한 줄: 닉네임 | 다시 보기
class _BlockedRow extends StatelessWidget {
  const _BlockedRow({
    super.key,
    required this.entry,
    required this.onUnblockPressed,
  });

  final TalkBlockEntry entry;
  final VoidCallback onUnblockPressed;

  static const _paddingH = 14.0;
  static const _paddingV = 8.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final space = context.space;

    return Container(
      padding: EdgeInsets.all(space.sm.w),
      decoration: BoxDecoration(
        color: colors.creditCardBg,
        borderRadius: BorderRadius.circular(space.cardRadius.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              entry.nickname ?? l10n.talkAuthorFallback,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typo.tileLabel.copyWith(color: colors.textPrimary),
            ),
          ),
          SizedBox(width: space.xs.w),
          AppPressable(
            onTap: onUnblockPressed,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: _paddingH.w,
                vertical: _paddingV.h,
              ),
              decoration: BoxDecoration(
                color: colors.buttonEnabled,
                borderRadius: BorderRadius.circular(space.buttonRadius.r),
              ),
              child: Text(
                l10n.talkUnblockAction,
                style: context.typo.chipLabel.copyWith(
                  color: colors.buttonEnabledText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

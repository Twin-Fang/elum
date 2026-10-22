import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_fade_slide_in.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_state_body.dart';
import '../../../core/widgets/elum_toast.dart';
import '../../../core/widgets/show_failure.dart';
import '../application/talk_blocks_controller.dart';
import '../domain/talk_block_entry.dart';
import '../domain/talk_screen_codes.dart';
import 'widgets/talk_empty_message.dart';

/// 숨긴 보호자 목록 (내 정보 > 숨긴 보호자): 닉네임 + "다시 보기"로 숨김 풀기
/// 상태: 받는 중 / 0건 / 실패(다시 하기 + 에러 코드) / 목록
class TalkBlockedGuardiansScreen extends ConsumerWidget {
  const TalkBlockedGuardiansScreen({super.key});

  /// 목록 위아래 · 줄 사이 (함께하는 사람 목록과 같은 8) · 차례로 떠오르는 줄 수 상한
  static const _listPadV = 16.0;
  static const _rowGap = 8.0;
  static const _maxStaggerCount = 8;

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
          child: TalkEmptyMessage(title: l10n.talkBlockedGuardiansEmpty),
        ),
        AsyncData(value: final entries) => ListView.separated(
          padding: EdgeInsets.symmetric(vertical: _listPadV.h),
          itemCount: entries.length,
          separatorBuilder: (_, _) => SizedBox(height: _rowGap.h),
          // 처음 보이는 줄만 차례로 떠오른다 (늦춤 상한)
          itemBuilder: (context, index) => AppFadeSlideIn(
            key: ValueKey(entries[index].blockId),
            offset: 8,
            delay: Duration(
              milliseconds:
                  AppMotion.staggerDelayMs *
                  (index < _maxStaggerCount ? index : _maxStaggerCount),
            ),
            child: _BlockedRow(
              entry: entries[index],
              onUnblockPressed: () => _unblock(context, ref, entries[index]),
            ),
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

/// 숨긴 보호자 한 줄 (함께하는 사람 줄 결: 웜그레이 68 · r20): 닉네임 | 다시 보기
class _BlockedRow extends StatelessWidget {
  const _BlockedRow({required this.entry, required this.onUnblockPressed});

  final TalkBlockEntry entry;
  final VoidCallback onUnblockPressed;

  /// 줄 최소 높이 · 왼쪽 18 · 오른쪽 16 · 큰 글자에서 위아래가 붙지 않는 여백
  static const _minHeight = 68.0;
  static const _padStart = 18.0;
  static const _padEnd = 16.0;
  static const _padV = 8.0;
  static const _nameToButton = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final nickname = entry.nickname ?? context.l10n.talkAuthorFallback;

    return Container(
      constraints: BoxConstraints(minHeight: _minHeight.h),
      padding: EdgeInsets.fromLTRB(_padStart.w, _padV.h, _padEnd.w, _padV.h),
      decoration: BoxDecoration(
        color: colors.peopleRowBg,
        borderRadius: BorderRadius.circular(context.space.cardRadius.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              nickname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typo.peopleRowName.copyWith(
                color: colors.peopleTextPrimary,
              ),
            ),
          ),
          SizedBox(width: _nameToButton.w),
          _UnblockButton(nickname: nickname, onTap: onUnblockPressed),
        ],
      ),
    );
  }
}

/// `다시 보기` 흰 작은 버튼 (함께하는 사람 `이름 변경` 버튼 결: 흰 판 r8 · 600/14)
class _UnblockButton extends StatelessWidget {
  const _UnblockButton({required this.nickname, required this.onTap});

  final String nickname;
  final VoidCallback onTap;

  static const _padH = 16.0;
  static const _padV = 10.0;
  static const _radius = 8.0;

  /// 손가락이 닿는 최소 높이 (보이는 버튼보다 크게)
  static const _minTouchHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = context.l10n.talkUnblockAction;
    return AppPressable(
      onTap: onTap,
      // 닉네임과 합쳐지지 않는 버튼 노드 (줄마다 어느 보호자인지 구분)
      semanticLabel: '$nickname $label',
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: _minTouchHeight.h),
        child: Center(
          widthFactor: 1,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: _padH.w,
              vertical: _padV.h,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(_radius.r),
            ),
            child: Text(
              label,
              maxLines: 1,
              style: context.typo.peopleRenameLabel.copyWith(
                color: colors.peopleTextPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

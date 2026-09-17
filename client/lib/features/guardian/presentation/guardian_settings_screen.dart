import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../auth/data/auth_repository.dart';

/// 보호자 설정 화면 (이슈 #181).
///
/// 지금은 계정 항목 둘뿐이지만 **목록 구조**로 만들어 이후 항목(암호 변경·알림 등)을
/// 줄만 추가하면 되게 한다. 화면마다 다른 레이아웃을 짜면 항목이 늘 때 흐트러진다.
///
/// 아이 화면에는 진입점을 두지 않는다 — 아이가 계정을 정리할 이유가 없다.
class GuardianSettingsScreen extends ConsumerStatefulWidget {
  const GuardianSettingsScreen({super.key});

  @override
  ConsumerState<GuardianSettingsScreen> createState() =>
      _GuardianSettingsScreenState();
}

class _GuardianSettingsScreenState
    extends ConsumerState<GuardianSettingsScreen> {
  /// 처리 중 중복 탭 방지. 로그아웃은 서버 요청이 섞여 있어 즉시 끝나지 않는다.
  bool _busy = false;

  Future<void> _logout() async {
    final ok = await _ConfirmSheet.show(
      context,
      title: '로그아웃할까요?',
      // 겁주지 않는다 — 같은 계정으로 다시 들어오면 일과는 그대로 있다.
      message: '다시 로그인하면 지금까지 만든 일과를 그대로 볼 수 있어요.',
      confirmLabel: '로그아웃',
    );
    if (ok != true) return;
    await _run(() => ref.read(authRepositoryProvider).logout());
  }

  Future<void> _deleteAccount() async {
    final ok = await _ConfirmSheet.show(
      context,
      title: '정말 탈퇴할까요?',
      // 로그아웃과 결정적으로 다른 지점이라 반드시 말해 준다.
      message: '만든 일과와 모은 별이 모두 사라져요.\n같은 계정으로 다시 로그인해도 되돌릴 수 없어요.',
      confirmLabel: '탈퇴하기',
      destructive: true,
    );
    if (ok != true) return;
    await _run(() => ref.read(authRepositoryProvider).deleteAccount());
  }

  /// 계정 정리 동작의 공통 뼈대.
  ///
  /// 저장소 쪽은 서버 요청이 실패해도 로컬을 반드시 비우므로, 여기서 결과를 따져
  /// 화면을 붙잡아 둘 이유가 없다. 남겨 두면 토큰 없는 상태로 홈에 머물게 된다.
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return ElumScaffold(
      onBack: _busy ? null : () => context.pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: space.xl),
          Text(
            '설정',
            style:
                context.typo.pinTitle.copyWith(color: context.colors.textPrimary),
          ),
          SizedBox(height: space.xl),
          _SettingsTile(
            label: '로그아웃',
            onTap: _busy ? null : _logout,
          ),
          _SettingsTile(
            label: '회원탈퇴',
            onTap: _busy ? null : _deleteAccount,
            destructive: true,
          ),
        ],
      ),
    );
  }
}

/// 설정 목록의 한 줄. 항목이 늘어도 이 위젯만 반복하면 된다.
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onTap;

  /// 되돌릴 수 없는 항목. 색으로 구분해 실수로 누르는 것을 줄인다.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final colors = context.colors;

    return AppPressable(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: space.lg),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.border)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: context.typo.tileLabel.copyWith(
                color: destructive ? colors.textSecondary : colors.textPrimary,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: space.lg.w,
              color: colors.textPlaceholder,
            ),
          ],
        ),
      ),
    );
  }
}

/// 되돌릴 수 없는 동작을 한 번 확인받는 시트.
///
/// 카드 수정 시트와 같은 바텀시트 방식을 쓴다 — 확인 창만 다른 형태로 뜨면
/// 앱 안에서 두 가지 문법을 배우게 된다.
class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.destructive,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        destructive: destructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final colors = context.colors;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        space.screenH,
        space.xl,
        space.screenH,
        // 홈 인디케이터에 버튼이 걸리지 않게 기기 여백을 더한다.
        space.xl + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(space.cardRadius.r),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: context.typo.sectionTitle.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: space.sm),
          Text(
            message,
            style: context.typo.body.copyWith(color: colors.textSecondary),
          ),
          SizedBox(height: space.xl),
          Row(
            children: [
              Expanded(
                child: _SheetButton(
                  label: '취소',
                  filled: false,
                  onTap: () => Navigator.of(context).pop(false),
                ),
              ),
              SizedBox(width: space.sm),
              Expanded(
                child: _SheetButton(
                  label: confirmLabel,
                  filled: true,
                  // 되돌릴 수 없는 쪽은 기본 버튼색을 쓰지 않는다.
                  onTap: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final colors = context.colors;

    return AppPressable(
      onTap: onTap,
      child: Container(
        height: space.buttonH.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? colors.buttonEnabled : colors.buttonDisabled,
          borderRadius: BorderRadius.circular(space.buttonRadius.r),
        ),
        child: Text(
          label,
          style: context.typo.button.copyWith(
            color: filled ? colors.buttonEnabledText : colors.buttonDisabledText,
          ),
        ),
      ),
    );
  }
}

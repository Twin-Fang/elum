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
    await _run(() async {
      await ref.read(authRepositoryProvider).logout();
      // 로그아웃은 이 기기에서 나가는 것이 본질이라 서버가 실패해도 목적은 달성된다.
      return true;
    });
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

  /// 되돌릴 수 없다고 안내한 동작이 실패했을 때.
  ///
  /// 화면을 옮기지 않는다 — 계정은 서버에 그대로 있고 토큰도 살아 있으므로
  /// 이 자리에서 다시 누르면 된다. 코드(E-DEL)를 같이 보여줘야 제보를 받았을 때
  /// 어디서 멈췄는지 알 수 있다.
  void _tellFailed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('계정을 지우지 못했어요. 잠시 후 다시 시도해주세요. (E-DEL)'),
      ),
    );
  }

  /// 계정 정리 동작의 공통 뼈대.
  ///
  /// 동작이 **실제로 됐는지**를 받아 분기한다. 됐으면 로컬이 비었으니 이 화면에
  /// 남을 수 없어 로그인으로 보내고, 안 됐으면 바뀐 것이 없으니 이 자리에 머문
  /// 채로 알린다 (이슈 #187).
  Future<void> _run(Future<bool> Function() action) async {
    setState(() => _busy = true);
    var done = false;
    try {
      done = await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (done) {
      context.go(Routes.login);
    } else {
      _tellFailed();
    }
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
          // 명세 §8-4는 위에 임시저장·알림도 두지만 아직 없다. 있는 것만 먼저 올린다.
          _SettingsTile(
            label: '이룸이 휴대폰 연결하기',
            onTap: _busy ? null : () => context.push(Routes.linkCode),
          ),
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
                // 흐리게 하면 "못 누르는 항목"으로 읽힌다. 누를 수 있다는 것과
                // 위험하다는 것을 동시에 전해야 한다 (이슈 #188).
                color: destructive ? colors.danger : colors.textPrimary,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: space.lg.w,
              color: destructive ? colors.danger : colors.textPlaceholder,
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
                  // 물러나는 쪽은 언제나 누를 수 있어 보여야 한다. 비활성 색을 쓰면
                  // 취소가 막힌 것처럼 보여 확인 쪽으로 몰린다 (이슈 #188).
                  kind: _SheetButtonKind.neutral,
                  onTap: () => Navigator.of(context).pop(false),
                ),
              ),
              SizedBox(width: space.sm),
              Expanded(
                child: _SheetButton(
                  label: confirmLabel,
                  // 되돌릴 수 없는 쪽은 기본 버튼색을 쓰지 않는다.
                  kind: destructive
                      ? _SheetButtonKind.danger
                      : _SheetButtonKind.primary,
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

/// 시트 버튼의 세 가지 역할.
///
/// 색을 호출부에서 직접 고르게 하면 화면마다 다른 조합이 생긴다. 역할만 고르면
/// 위험 표현이 앱 전체에서 같은 모습으로 나온다.
enum _SheetButtonKind {
  /// 되돌릴 수 있는 확인 (로그아웃 등).
  primary,

  /// 물러나기. 눌러도 아무 일이 없으므로 항상 열려 있어 보인다.
  neutral,

  /// 되돌릴 수 없는 확인.
  danger,
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.kind,
    required this.onTap,
  });

  final String label;
  final _SheetButtonKind kind;
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
          color: switch (kind) {
            _SheetButtonKind.primary => colors.buttonEnabled,
            _SheetButtonKind.neutral => colors.buttonNeutral,
            _SheetButtonKind.danger => colors.danger,
          },
          borderRadius: BorderRadius.circular(space.buttonRadius.r),
        ),
        child: Text(
          label,
          style: context.typo.button.copyWith(
            color: switch (kind) {
              _SheetButtonKind.primary => colors.buttonEnabledText,
              _SheetButtonKind.neutral => colors.buttonNeutralText,
              _SheetButtonKind.danger => colors.dangerText,
            },
          ),
        ),
      ),
    );
  }
}

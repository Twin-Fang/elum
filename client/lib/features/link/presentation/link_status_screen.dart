import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/show_failure.dart';
import '../data/device_link_repository.dart';
import '../domain/link_status.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/widgets/elum_state_body.dart';
import '../../../core/widgets/elum_toast.dart';
import '../../../core/router/routes.dart';

/// 이룸이 휴대폰 — 연결 상태와 끊기 (명세 §8-5 · 이슈 #363).
///
/// **시안이 없어 임시 배치다** (명세에 그림만 있고 Figma 프레임이 없다). 기존 설정 화면 뼈대
/// (`ElumScaffold` 제목·뒤로가기 한 줄)와 카드·팝업 컴포넌트로 지었다 — 디자인 요청 대상이다.
///
/// 설정의 `이룸이 휴대폰 · 연결됨 ›` 줄에서 열린다. **연결 전에는 이 화면이 없다** (그때는 연결 암호
/// 만들기로 바로 간다). 휴대폰을 잃어버렸거나 새로 바꿨거나 남의 휴대폰에 잘못 붙였을 때 보호자가
/// 끊을 수 있는 유일한 길이다.
///
/// ## 상태
///
/// | | 보이는 것 |
/// | --- | --- |
/// | 불러오는 중 | 돌아가는 표시 |
/// | 못 불러옴 | 이유 + `다시 시도` + 에러 코드 (빈 화면·무한 로딩 금지) |
/// | 연결 없음 | `연결된 휴대폰이 없어요` + 연결하기 (다른 사람이 먼저 끊은 경우) |
/// | 연결됨 | `연결됨` + `9월 18일부터` + `연결 끊기` |
///
/// 함께 돌보는 보호자가 붙인 휴대폰도 보인다 (다중 보호자 명세 4-2) — 연결된 보호자는 모두 동등하다.
/// 누가 붙였는지는 보여주지 않는다 (서버가 계정 식별자를 내리지 않는다).
class LinkStatusScreen extends ConsumerStatefulWidget {
  const LinkStatusScreen({super.key});

  @override
  ConsumerState<LinkStatusScreen> createState() => _LinkStatusScreenState();
}

class _LinkStatusScreenState extends ConsumerState<LinkStatusScreen> {
  /// 끊는 중 중복 탭 방지 — 같은 요청이 두 번 나가면 두 번째는 404 로 돌아온다.
  bool _busy = false;

  Future<void> _confirmAndRevoke(LinkedDevice device) async {
    // await 뒤에서 context 를 쓰지 않으려고 미리 잡는다
    final l10n = context.l10n;
    // 되돌릴 수 있다고 함께 말한다 — 번호를 다시 만들면 된다 (docs 원칙 ④).
    // 탈퇴처럼 무겁지 않으나 이룸이 휴대폰이 바로 일과를 못 보게 되므로 확인을 거친다.
    final ok = await showElumDialog<bool>(
      context: context,
      icon: ElumDialogIcon.alert,
      title: l10n.linkStatusRevokeConfirmTitle,
      message: l10n.linkStatusRevokeConfirmMessage,
      actions: [
        ElumDialogAction(
          label: l10n.commonCancel,
          value: false,
          tone: ElumDialogTone.neutral,
        ),
        ElumDialogAction(
          label: l10n.linkStatusRevokeConfirmAction,
          value: true,
          tone: ElumDialogTone.danger,
        ),
      ],
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    final result = await ref
        .read(deviceLinkRepositoryProvider)
        .revoke(device.linkId);
    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.isGone) {
      // 연결은 그대로다 — 화면에 머물고 이유와 에러 코드를 보여준다.
      await showFailure(
        context,
        result.failure,
        title: l10n.linkStatusRevokeFailTitle,
        fallback: l10n.linkStatusRevokeFailedFallback,
        fallbackCode: 'E-LINK-OUT',
      );
      return;
    }

    // 끊었거나 이미 끊겨 있었다 — 어느 쪽이든 보호자가 원한 상태다. 목록을 다시 받아 보여준다.
    ref.invalidate(linkStatusProvider);
    if (!mounted) return;
    showElumToast(
      context,
      result.outcome == RevokeOutcome.done
          ? l10n.linkStatusRevoked
          : l10n.linkStatusAlreadyRevoked,
    );
    // 남은 휴대폰이 없으면 설정으로 돌아간다 — 설정 줄이 `연결하기`로 되돌아가 있다.
    final remaining = await ref.read(linkStatusProvider.future);
    if (!mounted) return;
    if (remaining.isOk && !remaining.value!.hasDevice) {
      context.popOrHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(linkStatusProvider);

    return ElumScaffold(
      onBack: _busy ? null : context.popOrHome,
      // 설정 묶음 시안과 같은 머리(제목이 뒤로가기와 한 줄, 뒤로가기 y=67)
      title: context.l10n.linkStatusTitle,
      backTop: 67,
      horizontalPadding: 16,
      // 로딩·실패·빈 상태는 같은 자리(본문 가운데)에 둔다 — 바뀔 때 튀지 않게.
      child: status.when(
        loading: () => const ElumStateBody.loading(),
        // 조회 자체가 던지는 일은 없지만(저장소가 결과로 감싼다) 던져도 화면이 죽지 않게 한다.
        error: (e, _) => _failed(e),
        data: (attempt) => switch (attempt.value) {
          final status? when attempt.isOk && status.hasDevice => _loaded(
            status,
          ),
          final _? when attempt.isOk => ElumStateBody(child: _empty()),
          _ => _failed(attempt.failure),
        },
      ),
    );
  }

  Widget _failed(Object? failure) {
    return ElumStateBody(
      child: ElumErrorView.failure(
        failure,
        fallback: context.l10n.linkStatusLoadFailedFallback,
        fallbackCode: 'E-LINK-STATUS',
        onRetry: () => ref.invalidate(linkStatusProvider),
        compact: true,
      ),
    );
  }

  Widget _loaded(LinkStatus status) {
    final many = status.devices.length > 1;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 40.h),
          for (final (i, device) in status.devices.indexed) ...[
            if (i > 0) SizedBox(height: 32.h),
            _DeviceBlock(
              device: device,
              // 여러 대면 구분할 이름을 붙인다. 한 대면 시안 그대로 `연결됨`이다.
              title: many ? context.l10n.linkDeviceNumbered(i + 1) : null,
              onDisconnect: _busy ? null : () => _confirmAndRevoke(device),
            ),
          ],
          SizedBox(height: 16.h),
          // 끊으면 어떻게 되는지 — 버튼 아래 한 줄 (명세 §8-5)
          Text(
            context.l10n.linkStatusRevokeHint,
            textAlign: TextAlign.center,
            style: context.typo.promptBody.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// 연결이 없다 — 다른 보호자가 먼저 끊었거나 이룸이 휴대폰이 스스로 끊었다.
  Widget _empty() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.linkStatusEmpty,
          textAlign: TextAlign.center,
          style: context.typo.subtitle.copyWith(
            color: context.colors.textPrimary,
          ),
        ),
        SizedBox(height: 24.h),
        AppPressable(
          onTap: () => context.pushReplacement(Routes.linkCode),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 24.w),
            decoration: BoxDecoration(
              color: context.colors.linkRetryChipBg,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              context.l10n.linkStatusConnectAction,
              style: context.typo.settingsTileLabel.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 연결된 휴대폰 한 대 — 상태·언제부터·`연결 끊기`.
class _DeviceBlock extends StatelessWidget {
  const _DeviceBlock({
    required this.device,
    required this.onDisconnect,
    this.title,
  });

  final LinkedDevice device;
  final String? title;

  /// null 이면 끊는 중이라 누를 수 없다.
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final since = device.sinceLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Text(
                  title!,
                  style: typo.promptBody.copyWith(color: colors.textSecondary),
                ),
                SizedBox(height: 8.h),
              ],
              Text(
                context.l10n.linkStatusConnected,
                style: typo.subtitle.copyWith(color: colors.textPrimary),
              ),
              if (since != null) ...[
                SizedBox(height: 8.h),
                Text(
                  since,
                  style: typo.promptBody.copyWith(color: colors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        // 위험한 일은 다른 것과 떨어뜨린다 (docs 7-1). 주 버튼이 아니라 테두리만 있는 버튼이다 (docs 5-3).
        SizedBox(height: 40.h),
        AppPressable(
          onTap: onDisconnect,
          child: Container(
            height: 56.h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: onDisconnect == null
                    ? colors.settingsChevron
                    : colors.settingsDestructive,
                width: 1.5,
              ),
            ),
            child: Text(
              context.l10n.linkStatusRevokeButton,
              style: typo.settingsTileLabel.copyWith(
                color: onDisconnect == null
                    ? colors.settingsChevron
                    : colors.settingsDestructive,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/state/busy_state_mixin.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/settings_group.dart';
import '../../../core/widgets/settings_tile.dart';
import '../../../core/widgets/show_failure.dart';
import '../application/link_status_controller.dart';
import '../data/device_link_repository.dart';
import '../domain/link_status.dart';
import 'widgets/link_device_group.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/widgets/elum_state_body.dart';
import '../../../core/widgets/elum_toast.dart';
import '../../../core/router/routes.dart';

/// 이룸이 휴대폰 — 연결 상태와 끊기 (명세 §8-5).
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
/// | 연결됨 | 기기 이름 + `연결됨` + `누가 연결 · 9월 18일부터` + `연결 끊기`, 목록 아래 `다른 휴대폰 연결하기` |
///
/// 함께 돌보는 보호자가 붙인 휴대폰도 보인다 (다중 보호자 명세 4-2) — 연결된 보호자는 모두 동등하다.
/// 누가 붙였는지는 이 이룸이 안에서 불리는 이름으로만 보인다 (서버가 계정 식별자·이메일을 내리지 않는다).
class LinkStatusScreen extends ConsumerStatefulWidget {
  const LinkStatusScreen({super.key});

  @override
  ConsumerState<LinkStatusScreen> createState() => _LinkStatusScreenState();
}

class _LinkStatusScreenState extends ConsumerState<LinkStatusScreen>
    with BusyStateMixin<LinkStatusScreen> {
  @override
  void initState() {
    super.initState();
    // 설정 줄이 같은 조회를 들고 있어 캐시가 살아 있다 — 들어올 때마다 서버 값으로 새로 받는다.
    // 다른 휴대폰에서 끊긴 연결이 '연결됨'으로 남아 보이지 않게 한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(linkStatusProvider);
    });
  }

  /// 확인을 받은 뒤의 끊기 요청은 한 번만 나간다 — 같은 요청이 두 번 나가면 두 번째는 404 로 돌아온다.
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

    final result = await runBusy(
      () => ref.read(linkStatusControllerProvider).revoke(device.linkId),
      key: device.linkId,
    );
    // 이미 끊는 중이라 실행하지 않았다.
    if (result == null || !mounted) return;

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
      onBack: context.popOrHome,
      isBackEnabled: !busy,
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
          final _? when attempt.isOk => _empty(),
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

  /// 설정 묶음 결 (§4-2): 기기마다 흰 묶음 카드 > 마지막 카드 아래 회색 안내 > `다른 기기 연결하기` 한 줄
  Widget _loaded(LinkStatus status) {
    final l10n = context.l10n;
    final devices = status.devices;
    final isMany = devices.length > 1;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: _listTopGap.h),
          for (final (index, device) in devices.indexed) ...[
            LinkDeviceGroup(
              device: device,
              // 여러 대면 이름 모르는 기기에 번호를 붙여 구분
              fallbackTitle: isMany ? l10n.linkDeviceNumbered(index + 1) : null,
              // 끊으면 어떻게 되는지 — 마지막 카드 아래 한 번만 (명세 §8-5)
              footer: index == devices.length - 1
                  ? l10n.linkStatusRevokeHint
                  : null,
              onDisconnect: busy ? null : () => _confirmAndRevoke(device),
              isLoading: isBusy(device.linkId),
            ),
            SizedBox(height: _groupGap.h),
          ],
          // 연결된 기기가 있어도 태블릿 등을 더 붙일 수 있다. 돌아오면 이 화면이 그대로 남는다.
          SettingsGroup(
            children: [
              SettingsTile(
                label: l10n.linkStatusAddAction,
                onTap: busy ? null : () => context.push(Routes.linkCode),
              ),
            ],
          ),
          SizedBox(height: _groupGap.h),
        ],
      ),
    );
  }

  /// 연결이 없다 — 다른 보호자가 먼저 끊었거나 이룸이 기기가 스스로 끊었다.
  /// 보호자 빈 상태 결: 목록 첫 줄 자리에 글만 든 웜그레이 줄 > 연결하기 한 줄
  Widget _empty() {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: _listTopGap.h),
        Container(
          constraints: BoxConstraints(minHeight: _emptyTileHeight.h),
          padding: EdgeInsets.symmetric(horizontal: SettingsTile.cardPadLeft.w),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: colors.routineTileBg,
            borderRadius: BorderRadius.circular(context.space.cardRadius.r),
          ),
          child: Text(
            context.l10n.linkStatusEmpty,
            style: context.typo.routineEmptyTitle.copyWith(
              color: colors.routineTileLabel,
            ),
          ),
        ),
        SizedBox(height: _groupGap.h),
        SettingsGroup(
          children: [
            SettingsTile(
              label: context.l10n.linkStatusConnectAction,
              onTap: () => context.pushReplacement(Routes.linkCode),
            ),
          ],
        ),
      ],
    );
  }

  /// 스크롤 고정 머리 아래 첫 카드까지 (설정 화면 y=131 과 같음)
  static const _listTopGap = 24.0;

  /// 묶음 사이 (시안 1532:7501 gap 16)
  static const _groupGap = 16.0;

  /// 빈 상태 줄 높이 (홈 빈 상태 361×68)
  static const _emptyTileHeight = 68.0;
}

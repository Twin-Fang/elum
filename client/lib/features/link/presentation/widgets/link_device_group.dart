import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/batchim.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../../core/widgets/settings_tile.dart';
import '../../domain/link_status.dart';

/// 연결된 기기 한 대: 흰 묶음 카드 (기기 정보 줄 > `연결 끊기` 위험 줄) — 설정 묶음 결 (시안 1532:7501)
class LinkDeviceGroup extends StatelessWidget {
  const LinkDeviceGroup({
    super.key,
    required this.device,
    required this.onDisconnect,
    this.fallbackTitle,
    this.footer,
    this.isLoading = false,
  });

  final LinkedDevice device;

  /// 기기 이름을 모를 때 줄 이름 (여러 대면 `이룸이 기기 2`). null 이면 `이룸이 기기`
  final String? fallbackTitle;

  /// 카드 아래 회색 안내 (끊으면 무슨 일이 생기는지)
  final String? footer;

  /// null 이면 다른 요청을 기다리는 중이라 누를 수 없음
  final VoidCallback? onDisconnect;

  /// 이 기기를 끊는 요청을 기다리는 중 (위험 줄 오른쪽 스피너)
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsGroup(
      footer: footer,
      children: [
        _DeviceInfoRow(
          name: device.deviceName ?? fallbackTitle ?? l10n.linkStatusTitle,
          connectedSince: _connectedSince(context),
        ),
        // 위험 줄은 글자만 빨강 (§4-2)
        SettingsTile(
          label: l10n.linkStatusRevokeButton,
          destructive: true,
          loading: isLoading,
          onTap: onDisconnect,
        ),
      ],
    );
  }

  /// 연결한 사람 + 날짜 한 줄 (날짜 모르면 사람만, 이름 없으면 `보호자`)
  String _connectedSince(BuildContext context) {
    final l10n = context.l10n;
    final String connectedBy;
    if (device.linkedByMe) {
      connectedBy = l10n.linkStatusConnectedByMe;
    } else {
      final name = device.linkedByName ?? l10n.commonGuardianName;
      connectedBy = l10n.linkStatusConnectedBy(name, batchimOf(name));
    }
    final sinceLabel = device.sinceLabel;
    return sinceLabel == null
        ? connectedBy
        : l10n.linkStatusConnectedByAndSince(connectedBy, sinceLabel);
  }
}

/// 기기 정보 줄: 이름 + 아래 회색 `내가 연결 · 9월 18일부터`, 오른쪽 값 `연결됨` (누를 곳 아님)
class _DeviceInfoRow extends StatelessWidget {
  const _DeviceInfoRow({required this.name, required this.connectedSince});

  final String name;
  final String connectedSince;

  /// 보조 글이 있는 설정 줄과 같은 안쪽 여백 (위아래 20 · 이름 > 보조 글 8 · 값 사이 12)
  static const _padV = 20.0;
  static const _subtitleGap = 8.0;
  static const _valueGap = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    // 읽기 프로그램이 이름 · 상태 · 연결 정보를 한 덩어리로 읽게 묶음
    return MergeSemantics(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          SettingsTile.cardPadLeft.w,
          _padV.h,
          SettingsTile.cardPadRight.w,
          _padV.h,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: typo.settingsTileLabel.copyWith(
                      color: colors.settingsCardLabel,
                    ),
                  ),
                  SizedBox(height: _subtitleGap.h),
                  Text(
                    connectedSince,
                    style: typo.peopleCaption.copyWith(
                      color: colors.settingsCardValue,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: _valueGap.w),
            Text(
              context.l10n.linkStatusConnected,
              style: typo.settingsTileLabel.copyWith(
                color: colors.settingsCardValue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

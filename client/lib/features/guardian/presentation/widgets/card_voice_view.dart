import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../data/guardian_voice_api.dart';
import '../../data/guardian_voice_recorder.dart';
import 'card_voice_block.dart';
import 'card_voice_parts.dart';

/// 녹음 칸 진행 상태 5개 (녹음 있음·없음·Pro 끝남은 ready 안에서 열쇠·권한으로 가름)
enum CardVoicePhase { ready, recording, uploading, micDenied, failed }

/// 녹음 칸 그리기만 (상태 > 줄). 상태 전환은 [CardVoiceBlock] 이 맡는다
class CardVoiceView extends StatelessWidget {
  const CardVoiceView({
    super.key,
    required this.phase,
    required this.canRecord,
    required this.voiceKey,
    this.isPlaying = false,
    this.elapsedSeconds = 0,
    this.failure,
    this.canRetrySame = false,
    this.onStartRecording,
    this.onStopRecording,
    this.onTogglePlaying,
    this.onDelete,
    this.onOpenSettings,
    this.onDismissMicDenied,
    this.onFailureButton,
  });

  final CardVoicePhase phase;

  /// 지금 Pro(GUARDIAN_VOICE) 인가 — 아니면 녹음 버튼 없이 듣기·지우기만
  final bool canRecord;

  /// 카드의 녹음 열쇠. null 이면 녹음 없음
  final String? voiceKey;
  final bool isPlaying;
  final int elapsedSeconds;
  final VoiceFailure? failure;

  /// 실패 버튼이 같은 녹음 다시 올리기인가 (아니면 닫기)
  final bool canRetrySame;
  final VoidCallback? onStartRecording;
  final VoidCallback? onStopRecording;
  final VoidCallback? onTogglePlaying;
  final VoidCallback? onDelete;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onDismissMicDenied;
  final VoidCallback? onFailureButton;

  @override
  Widget build(BuildContext context) {
    return CardVoiceFrame(minHeight: CardVoiceBlock.minHeight.h, child: _row(context));
  }

  Widget _row(BuildContext context) {
    final l10n = context.l10n;
    switch (phase) {
      case CardVoicePhase.recording:
        return CardVoiceRow(
          title: l10n.guardianVoiceRecording(elapsedSeconds),
          subtitle: l10n.guardianVoiceRecordingLimit(GuardianVoiceRules.maxDuration.inSeconds),
          leading: const CardVoiceIcon(asset: AppAssets.iconMicrophone),
          actions: [CardVoiceChip(label: l10n.guardianVoiceStop, iconAsset: AppAssets.iconStop, onTap: onStopRecording)],
        );
      case CardVoicePhase.uploading:
        return CardVoiceRow(title: l10n.guardianVoiceSaving, leading: const CardVoiceSpinner());
      case CardVoicePhase.micDenied:
        return CardVoiceRow(
          title: l10n.guardianVoiceMicDeniedTitle,
          subtitle: l10n.guardianVoiceMicDeniedBody,
          actions: [
            CardVoiceChip(label: l10n.guardianVoiceOpenSettings, onTap: onOpenSettings),
            CardVoiceChip(label: l10n.commonConfirm, onTap: onDismissMicDenied),
          ],
        );
      case CardVoicePhase.failed:
        final shown = failure ?? VoiceFailure.recordFailed;
        return CardVoiceRow(
          title: l10n.guardianVoiceFailedTitle,
          // 제보를 받았을 때 어디서 터졌는지 찾는 식별자
          subtitle: '${shown.message} (${shown.code})',
          actions: [
            CardVoiceChip(
              label: canRetrySame ? l10n.guardianVoiceRetry : l10n.commonConfirm,
              iconAsset: canRetrySame ? AppAssets.iconRefresh : null,
              onTap: onFailureButton,
            ),
          ],
        );
      case CardVoicePhase.ready:
        return _readyRow(context);
    }
  }

  /// 녹음 전 · 녹음 있음 · Pro 끝남 (녹음 있음/없음)
  Widget _readyRow(BuildContext context) {
    final l10n = context.l10n;
    final playChip = CardVoiceChip(
      label: isPlaying ? l10n.guardianVoiceStop : l10n.guardianVoicePlay,
      iconAsset: isPlaying ? AppAssets.iconStop : AppAssets.iconPlay,
      onTap: onTogglePlaying,
    );
    final deleteChip = CardVoiceChip(label: l10n.guardianVoiceDelete, iconAsset: AppAssets.iconTrash, onTap: onDelete);
    if (voiceKey == null && !canRecord) {
      // Pro 가 끝난 뒤 녹음을 지웠다: 이제 할 일이 없다 (시트를 다시 열면 칸이 빠짐)
      return CardVoiceRow(title: l10n.guardianVoicePlanEnded);
    }
    if (voiceKey == null) {
      return CardVoiceRow(
        title: l10n.guardianVoiceRecordAction,
        subtitle: l10n.guardianVoiceRecordHint,
        actions: [
          CardVoiceChip(label: l10n.guardianVoiceRecordChip, iconAsset: AppAssets.iconMicrophone, onTap: onStartRecording),
        ],
      );
    }
    if (!canRecord) {
      // Pro 가 끝남: 녹음은 남아 있고 듣기·지우기만 (다시 녹음 없음)
      return CardVoiceRow(
        title: l10n.guardianVoicePlanEnded,
        subtitle: l10n.guardianVoicePlanEndedHint,
        actions: [playChip, deleteChip],
      );
    }
    return CardVoiceRow(
      title: l10n.guardianVoiceSaved,
      actions: [
        playChip,
        // 칩 세 개가 한 줄에 들어가게 뒤 둘은 글자만
        CardVoiceChip(label: l10n.guardianVoiceRerecord, onTap: onStartRecording),
        CardVoiceChip(label: l10n.guardianVoiceDelete, onTap: onDelete),
      ],
    );
  }
}

import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/widgets/elum_dialog.dart';
import '../../../member/application/plan_access.dart';
import '../../../subscription/application/plan_paywall_entry.dart';
import '../../application/guardian_voice_controller.dart';
import '../../application/routine_notifier.dart';
import '../../data/guardian_voice_api.dart';
import '../../data/guardian_voice_recorder.dart';
import 'card_voice_view.dart';

/// 카드 수정 시트 안의 보호자 목소리 칸 (Pro): 녹음 > 멈춤 > 올리기 > 듣기 · 다시 녹음 · 지우기
///
/// 상태 전환만 맡고 그리기는 [CardVoiceView]. 마이크가 막혀도 카드는 기본 목소리로 계속 읽힘
/// 서버 id 가 있는 카드에서만 (사진 칸과 같은 조건)
class CardVoiceBlock extends ConsumerStatefulWidget {
  const CardVoiceBlock({super.key, required this.routineId, required this.stepId});

  final String routineId;
  final String stepId;

  /// 칸 최소 높이 (임시 시안 — 시트 입력칸 68 보다 조금 크게). 글이 길면 더 자람
  static const minHeight = 76.0;

  /// 칸을 둘지: Pro 이거나 녹음이 남아 있을 때 (결제 전에는 Free 에게 녹음 칸을 보이지 않음)
  static bool isShownFor({required bool canUseGuardianVoice, required String? guardianVoicePath}) =>
      canUseGuardianVoice || guardianVoicePath != null;

  @override
  ConsumerState<CardVoiceBlock> createState() => _CardVoiceBlockState();
}

class _CardVoiceBlockState extends ConsumerState<CardVoiceBlock> {
  var _phase = CardVoicePhase.ready;
  var _isPlaying = false;
  var _elapsedSeconds = 0;
  VoiceFailure? _failure;

  /// 같은 녹음으로 다시 올릴 때 (일시 오류만)
  Uint8List? _retryBytes;
  GuardianVoiceRecorder? _recorder;
  Timer? _ticker;
  final _player = AudioPlayer();
  StreamSubscription<void>? _playerDone;

  @override
  void initState() {
    super.initState();
    _playerDone = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _playerDone?.cancel();
    unawaited(_player.dispose());
    final recorder = _recorder;
    // 녹음 중에 시트를 닫으면 녹음을 버린다 (임시 파일 포함)
    if (recorder != null) unawaited(recorder.cancel().whenComplete(recorder.dispose));
    super.dispose();
  }

  String? _voiceKey() {
    for (final step in ref.watch(routineFlowProvider).routine?.steps ?? const []) {
      if (step.id == widget.stepId) return step.guardianVoicePath;
    }
    return null;
  }

  GuardianVoiceController get _controller => ref.read(guardianVoiceControllerProvider);

  /// 녹음 시작: 듣기 멈춤 > 마이크 권한 > 녹음 > 1초마다 시간 (15초면 저절로 멈춤)
  Future<void> _startRecording() async {
    if (_phase == CardVoicePhase.recording || _phase == CardVoicePhase.uploading) return;
    await _stopPlaying();
    final recorder = _recorder ??= _controller.createRecorder();
    if (!await recorder.requestPermission()) {
      if (mounted) setState(() => _phase = CardVoicePhase.micDenied);
      return;
    }
    if (!await recorder.start()) {
      _fail(VoiceFailure.recordFailed);
      return;
    }
    if (!mounted) return;
    setState(() {
      _phase = CardVoicePhase.recording;
      _elapsedSeconds = 0;
      _failure = null;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
      if (_elapsedSeconds >= GuardianVoiceRules.maxDuration.inSeconds) unawaited(_stopRecording());
    });
  }

  /// 녹음 멈춤 > 올리기. 너무 짧거나 실패면 알림
  Future<void> _stopRecording() async {
    final recorder = _recorder;
    if (_phase != CardVoicePhase.recording || recorder == null) return;
    _ticker?.cancel();
    setState(() => _phase = CardVoicePhase.uploading);
    switch (await recorder.stop()) {
      case VoiceRecorded(:final bytes):
        await _upload(bytes);
      case VoiceTooShort():
        _fail(VoiceFailure.tooShort);
      case VoiceRecordFailed():
        _fail(VoiceFailure.recordFailed);
    }
  }

  Future<void> _upload(Uint8List bytes) async {
    // await 뒤 시트가 닫혀도 새 열쇠는 일과에 반영 (미리 잡아 둠)
    final notifier = ref.read(routineFlowProvider.notifier);
    if (mounted) setState(() => _phase = CardVoicePhase.uploading);
    final uploadResult = await _controller.upload(routineId: widget.routineId, stepId: widget.stepId, bytes: bytes);
    final card = uploadResult.card;
    if (card != null) {
      notifier.applyStepVoice(widget.stepId, card.guardianVoicePath);
      if (mounted) setState(() => _phase = CardVoicePhase.ready);
      return;
    }
    final failure = uploadResult.failure ?? VoiceFailure.recordFailed;
    if (failure.isProOnlyRejection) {
      // Pro 가 끝났음: 칸 실패 대신 Pro 안내 (판정이 새로 오면 칸이 '기본 목소리로 읽어요'로 바뀜)
      if (!mounted) return;
      setState(() => _phase = CardVoicePhase.ready);
      await showProOnlyNoticeAfterRejection(context, ref);
      return;
    }
    _fail(failure, retryBytes: failure.canRetrySame ? bytes : null);
  }

  /// 듣기 ↔ 멈추기
  Future<void> _togglePlaying() async {
    if (_isPlaying) {
      await _stopPlaying();
      return;
    }
    final file = await _controller.downloadForPreview(routineId: widget.routineId, stepId: widget.stepId);
    if (!mounted) return;
    if (file == null) {
      _fail(VoiceFailure.playFailed);
      return;
    }
    try {
      await _player.play(DeviceFileSource(file.path));
      if (mounted) setState(() => _isPlaying = true);
    } catch (e) {
      AppLogger.error('guardian-voice', '미리 듣기 재생 실패: $e');
      _fail(VoiceFailure.playFailed);
    }
  }

  Future<void> _stopPlaying() async {
    if (!_isPlaying) return;
    try {
      await _player.stop();
    } catch (e) {
      AppLogger.error('guardian-voice', '미리 듣기 정지 실패: $e');
    }
    if (mounted) setState(() => _isPlaying = false);
  }

  /// 지우기: 확인 팝업 > 지우기 > 열쇠 비움
  Future<void> _delete() async {
    final notifier = ref.read(routineFlowProvider.notifier);
    final confirmed = await showElumDialog<bool>(
      context: context,
      title: context.l10n.guardianVoiceDeleteConfirmTitle,
      message: context.l10n.guardianVoiceDeleteConfirmMessage,
      actions: [
        ElumDialogAction(label: context.l10n.commonCancel, value: false, tone: ElumDialogTone.neutral),
        ElumDialogAction(label: context.l10n.guardianVoiceDelete, value: true, tone: ElumDialogTone.danger),
      ],
    );
    if (confirmed != true || !mounted) return;
    await _stopPlaying();
    setState(() => _phase = CardVoicePhase.uploading);
    final deleteResult = await _controller.delete(routineId: widget.routineId, stepId: widget.stepId);
    if (deleteResult.card != null) {
      notifier.applyStepVoice(widget.stepId, null);
      if (mounted) setState(() => _phase = CardVoicePhase.ready);
      return;
    }
    _fail(deleteResult.failure ?? VoiceFailure.recordFailed);
  }

  void _fail(VoiceFailure failure, {Uint8List? retryBytes}) {
    if (!mounted) return;
    setState(() {
      _phase = CardVoicePhase.failed;
      _failure = failure;
      _retryBytes = retryBytes;
    });
  }

  void _onFailureButton() {
    final bytes = _retryBytes;
    if (bytes != null) {
      unawaited(_upload(bytes));
      return;
    }
    setState(() {
      _phase = CardVoicePhase.ready;
      _failure = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CardVoiceView(
      phase: _phase,
      canRecord: ref.watch(planAccessProvider).canUseGuardianVoice,
      voiceKey: _voiceKey(),
      isPlaying: _isPlaying,
      elapsedSeconds: _elapsedSeconds,
      failure: _failure,
      canRetrySame: _retryBytes != null,
      onStartRecording: _startRecording,
      onStopRecording: _stopRecording,
      onTogglePlaying: _togglePlaying,
      onDelete: _delete,
      onOpenSettings: () => _recorder?.openSettings(),
      onDismissMicDenied: () => setState(() => _phase = CardVoicePhase.ready),
      onFailureButton: _onFailureButton,
    );
  }
}

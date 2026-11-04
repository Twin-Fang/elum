import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/guardian_voice_api.dart';
import '../data/guardian_voice_recorder.dart';

final guardianVoiceControllerProvider =
    Provider<GuardianVoiceController>((ref) => GuardianVoiceController(ref));

/// 녹음 칸이 쓰는 호출 모음: 녹음기 만들기, 올리기, 지우기, 미리 듣기 받기
class GuardianVoiceController {
  GuardianVoiceController(this._ref);

  final Ref _ref;

  GuardianVoiceRecorder createRecorder() => _ref.read(guardianVoiceRecorderFactoryProvider)();

  Future<VoiceChangeResult> upload({
    required String routineId,
    required String stepId,
    required Uint8List bytes,
  }) => _ref.read(guardianVoiceApiProvider).upload(routineId: routineId, stepId: stepId, bytes: bytes);

  Future<VoiceChangeResult> delete({required String routineId, required String stepId}) =>
      _ref.read(guardianVoiceApiProvider).delete(routineId: routineId, stepId: stepId);

  Future<File?> downloadForPreview({required String routineId, required String stepId}) =>
      _ref.read(guardianVoiceApiProvider).downloadForPreview(routineId: routineId, stepId: stepId);
}

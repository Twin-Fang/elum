import 'dart:io';
import 'dart:typed_data';

import 'package:app_settings/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/logger/app_logger.dart';

/// 녹음 규칙 (서버 GuardianVoiceAudio 와 같은 잣대: m4a · 15초 · 1MB)
abstract final class GuardianVoiceRules {
  /// 녹음 최대 길이 — 이 시간이 되면 저절로 멈춘다
  static const maxDuration = Duration(seconds: 15);

  /// 올릴 수 있는 최대 크기 (1MB, 64kbps · 15초 ≈ 120KB)
  static const maxBytes = 1024 * 1024;

  /// 이보다 짧으면 실수로 누른 것으로 보고 올리지 않는다 (0.5초)
  static const minDuration = Duration(milliseconds: 500);

  /// 음성 녹음 설정: AAC m4a · 한 채널 · 64kbps (말소리에 충분, 파일이 작다)
  static const config = RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: 64000,
    sampleRate: 44100,
    numChannels: 1,
  );
}

/// 녹음 결과: 녹음됨(바이트) · 너무 짧음 · 실패
sealed class VoiceRecording {
  const VoiceRecording();
}

class VoiceRecorded extends VoiceRecording {
  const VoiceRecorded(this.bytes);

  final Uint8List bytes;
}

class VoiceTooShort extends VoiceRecording {
  const VoiceTooShort();
}

class VoiceRecordFailed extends VoiceRecording {
  const VoiceRecordFailed();
}

/// 마이크 녹음: 권한 확인 > 임시 파일에 녹음 > 멈추면 바이트 > 임시 파일 삭제
///
/// 녹음 원본은 기기에 남기지 않는다 (올린 뒤 바로 지움). **절대 throw 하지 않음.**
class GuardianVoiceRecorder {
  GuardianVoiceRecorder({AudioRecorder? recorder}) : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  String? _path;
  DateTime? _startedAt;

  /// 마이크 권한. 처음이면 OS 가 묻는다. 거부·실패면 false
  Future<bool> requestPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      AppLogger.error('guardian-voice', '마이크 권한 확인 실패: $e');
      return false;
    }
  }

  /// 녹음 시작. 실패면 false
  Future<bool> start() async {
    try {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}${Platform.pathSeparator}guardian-voice-${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _recorder.start(GuardianVoiceRules.config, path: path);
      _path = path;
      _startedAt = DateTime.now();
      return true;
    } catch (e) {
      AppLogger.error('guardian-voice', '녹음 시작 실패: $e');
      return false;
    }
  }

  /// 멈춤 > 바이트 (임시 파일은 읽은 뒤 삭제)
  Future<VoiceRecording> stop() async {
    final startedAt = _startedAt;
    String? path;
    try {
      path = await _recorder.stop() ?? _path;
      if (path == null) return const VoiceRecordFailed();
      final elapsed = startedAt == null ? Duration.zero : DateTime.now().difference(startedAt);
      if (elapsed < GuardianVoiceRules.minDuration) return const VoiceTooShort();
      final bytes = await File(path).readAsBytes();
      return bytes.isEmpty ? const VoiceRecordFailed() : VoiceRecorded(bytes);
    } catch (e) {
      AppLogger.error('guardian-voice', '녹음 멈춤 실패: $e');
      return const VoiceRecordFailed();
    } finally {
      // 녹음 원본은 기기에 남기지 않음 (성공·실패 공통)
      await _deleteQuietly(path ?? _path);
      _path = null;
      _startedAt = null;
    }
  }

  /// 녹음 취소 (화면을 닫을 때). 임시 파일도 지운다
  Future<void> cancel() async {
    try {
      if (await _recorder.isRecording()) await _recorder.cancel();
    } catch (e) {
      AppLogger.error('guardian-voice', '녹음 취소 실패: $e');
    } finally {
      await _deleteQuietly(_path);
      _path = null;
      _startedAt = null;
    }
  }

  /// 기기 설정의 이 앱 화면 열기 (마이크를 다시 켜는 길)
  Future<void> openSettings() async {
    try {
      await AppSettings.openAppSettings();
    } catch (e) {
      AppLogger.error('guardian-voice', '설정 열기 실패: $e');
    }
  }

  void dispose() {
    _recorder.dispose();
  }

  static Future<void> _deleteQuietly(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      AppLogger.error('guardian-voice', '임시 녹음 삭제 실패: $e');
    }
  }
}

/// 녹음 칸마다 새로 만든다 (칸이 닫히면 dispose)
final guardianVoiceRecorderFactoryProvider = Provider<GuardianVoiceRecorder Function()>(
  (ref) => GuardianVoiceRecorder.new,
);

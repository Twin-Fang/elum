import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/dio_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/l10n/current_l10n.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/network/app_failure.dart';
import '../../../shared/models/action_card.dart';
import 'guardian_voice_recorder.dart';

/// 녹음 칸 실패 한 건: 식별자(에러 코드) · 문구 · 같은 녹음으로 다시 보낼 수 있는가
class VoiceFailure {
  const VoiceFailure({
    required this.code,
    required String Function() messageOf,
    this.canRetrySame = false,
    this.cause,
  }) : _messageOf = messageOf;

  final String code;
  final bool canRetrySame;

  /// 서버·네트워크 실패 원본, 앱 쪽 실패면 null. Pro 거절(GUARDIAN_VOICE_NOT_ALLOWED) 판정은 부르는 쪽이 `isProOnlyRejection` 으로
  final AppFailure? cause;
  final String Function() _messageOf;

  /// 사용자에게 보일 문구 — 읽을 때 앱 언어로 푼다
  String get message => _messageOf();

  static String _tooShort() => appL10n.guardianVoiceTooShort;
  static String _recordFailed() => appL10n.guardianVoiceRecordFailed;
  static String _tooLarge() => appL10n.guardianVoiceTooLarge;
  static String _playFailed() => appL10n.guardianVoicePlayFailed;

  static const tooShort = VoiceFailure(code: 'E-VOICE-SHORT', messageOf: _tooShort);
  static const recordFailed = VoiceFailure(code: 'E-VOICE-RECORD', messageOf: _recordFailed);
  static const tooLarge = VoiceFailure(code: 'E-VOICE-SIZE', messageOf: _tooLarge);
  static const playFailed = VoiceFailure(code: 'E-VOICE-PLAY', messageOf: _playFailed);

  /// 서버·네트워크 실패 > 녹음 칸의 말. 서버 문구가 이긴다(이미 해요체)
  ///
  /// 4xx(형식·길이·Pro 아님·권한)는 같은 녹음을 다시 보내도 같으므로 다시 하기 대신 새로 녹음
  factory VoiceFailure.from(AppFailure failure, {required String fallbackCode, String Function()? fallback}) {
    final status = failure.server?.statusCode;
    final isClientError = status != null && status >= 400 && status < 500;
    return VoiceFailure(
      code: failure.badgeOr(fallbackCode),
      messageOf: () => failure.serverMessage ?? failure.hint ?? (fallback ?? () => appL10n.commonRetryLater)(),
      canRetrySame: !isClientError,
      cause: failure,
    );
  }
}

/// 올리기·지우기 결과: 카드 아니면 실패. 저장소는 던지지 않는다
class VoiceChangeResult {
  const VoiceChangeResult.ok(ActionCard this.card) : failure = null;
  const VoiceChangeResult.failed(VoiceFailure this.failure) : card = null;

  final ActionCard? card;
  final VoiceFailure? failure;
}

/// 보호자 목소리 API: 올리기(PUT multipart voice) · 지우기(DELETE) · 미리 듣기용 받기(GET)
class GuardianVoiceApi {
  GuardianVoiceApi(this._dio);

  final Dio _dio;

  static String _pathOf(String routineId, String stepId) => '/api/routines/$routineId/steps/$stepId/voice';

  /// 올리기: 앱 쪽 크기 확인 > 올리기 > 새 열쇠 확인
  Future<VoiceChangeResult> upload({
    required String routineId,
    required String stepId,
    required Uint8List bytes,
  }) async {
    if (bytes.length > GuardianVoiceRules.maxBytes) {
      return const VoiceChangeResult.failed(VoiceFailure.tooLarge);
    }
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        _pathOf(routineId, stepId),
        data: FormData.fromMap({
          'voice': MultipartFile.fromBytes(
            bytes,
            filename: 'voice.m4a',
            contentType: DioMediaType('audio', 'mp4'),
          ),
        }),
        // 보내는 쪽 제한 — 기본은 없어서 망이 끊긴 채 올리면 끝없이 돈다
        options: Options(sendTimeout: AppConfig.receiveTimeout),
      );
      final body = response.data;
      final card = body == null ? null : ActionCard.fromJson(body);
      // 새 열쇠가 없으면 저장됐다고 말할 수 없다 — 성공으로 착각하지 않는다
      if (card == null || card.guardianVoicePath == null) {
        return VoiceChangeResult.failed(
          VoiceFailure.from(const AppFailure(fault: NetworkFault.app), fallbackCode: 'E-VOICE-UPLOAD'),
        );
      }
      return VoiceChangeResult.ok(card);
    } catch (e) {
      AppLogger.error('guardian-voice', '녹음 올리기 실패: $e');
      return VoiceChangeResult.failed(VoiceFailure.from(AppFailure.of(e), fallbackCode: 'E-VOICE-UPLOAD'));
    }
  }

  /// 지우기. 녹음이 없어도 성공
  Future<VoiceChangeResult> delete({required String routineId, required String stepId}) async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(_pathOf(routineId, stepId));
      final body = response.data;
      if (body == null) {
        return VoiceChangeResult.failed(VoiceFailure.from(
          const AppFailure(fault: NetworkFault.app),
          fallbackCode: 'E-VOICE-DELETE',
          fallback: () => appL10n.guardianVoiceDeleteFailed,
        ));
      }
      return VoiceChangeResult.ok(ActionCard.fromJson(body));
    } catch (e) {
      AppLogger.error('guardian-voice', '녹음 지우기 실패: $e');
      return VoiceChangeResult.failed(VoiceFailure.from(
        AppFailure.of(e),
        fallbackCode: 'E-VOICE-DELETE',
        fallback: () => appL10n.guardianVoiceDeleteFailed,
      ));
    }
  }

  /// 미리 듣기용 받기 > 임시 파일. 없거나 실패면 null (보호자 기기는 Pro 가 끝나도 받는다)
  Future<File?> downloadForPreview({required String routineId, required String stepId}) async {
    try {
      final response = await _dio.get<List<int>>(
        _pathOf(routineId, stepId),
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return null;
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}${Platform.pathSeparator}guardian-voice-preview.m4a');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (e) {
      AppLogger.error('guardian-voice', '미리 듣기 받기 실패: $e');
      return null;
    }
  }
}

final guardianVoiceApiProvider = Provider<GuardianVoiceApi>((ref) => GuardianVoiceApi(ref.watch(dioProvider)));

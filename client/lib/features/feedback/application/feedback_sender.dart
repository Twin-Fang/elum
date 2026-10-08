import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_status/app_status_repository.dart';
import '../../../core/logger/app_log_buffer.dart';
import '../../../core/logger/app_log_header.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/storage/local_storage.dart';
import '../data/feedback_repository.dart';

/// 의견 글에 앱 버전·OS·(선택) 앱 상태 기록을 붙여 보낸다.
class FeedbackSender {
  FeedbackSender(this._repo, {LocalStorage Function()? storage})
    : _storage = storage;

  final FeedbackRepository _repo;
  final LocalStorage Function()? _storage;

  /// 글 길이 상한. 서버와 같다.
  static const maxMessageLength = 2000;

  /// [includeLog] 가 꺼져 있거나 쌓인 로그가 없으면 기록 없이 글만 보낸다.
  Future<Attempt<String>> send({
    required String message,
    required bool includeLog,
  }) async {
    // 쌓인 기록이 없으면 머리말만 보내지 않고 글만 보낸다. 상한(256KB)은 asText 가 지킨다.
    final log = includeLog && !AppLogBuffer.isEmpty
        ? AppLogBuffer.asText(header: await buildAppLogHeader(storage: _storage))
        : '';
    return _repo.send(
      message: message.trim(),
      appLog: log.isEmpty ? null : log,
      appVersion: await AppStatusRepository.currentVersion(),
      os: '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    );
  }
}

final feedbackSenderProvider = Provider<FeedbackSender>(
  (ref) => FeedbackSender(
    ref.watch(feedbackRepositoryProvider),
    storage: () => ref.read(localStorageProvider),
  ),
);

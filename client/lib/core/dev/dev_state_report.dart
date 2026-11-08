import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'dev_log_buffer.dart';
import 'dev_log_file.dart';
import 'dev_state_dump.dart';

/// 복사한 보고서 + 화면 안내에 쓸 숫자 (글자 수, 담은 로그 줄 수)
@immutable
class DevClipboardReport {
  const DevClipboardReport({required this.text, required this.logLineCount});

  final String text;
  final int logLineCount;
}

/// 채팅(Claude) 붙여넣기용 보고서: 마크다운 1개, 토큰 가림, 최근 로그만
///
/// 로그 파일 전체(최대 2MB)는 채팅에 못 붙임 > 최근 [logLineCount]줄, 최대 [logMaxCharacters]자.
abstract final class DevStateReport {
  /// 보고서에 담는 최근 로그 줄 수
  static const logLineCount = 300;

  /// 로그 부분 최대 글자 수 (응답 본문이 긴 줄이 많아도 채팅에 붙는 크기)
  static const logMaxCharacters = 40000;

  /// 칸 목록 + 최근 로그 > 마크다운 보고서
  static Future<DevClipboardReport> build(List<DevStateSection> sections) async {
    final logLines = await _readRecentLogLines();
    final buffer = StringBuffer()
      ..writeln('## elum 상태 보고 · ${formatLocalTime(DateTime.now())}')
      ..writeln('> 테스트 빌드 개발자 도구에서 복사함. 토큰은 가림 (전문은 `전체 파일 내보내기`).')
      ..writeln();
    for (final section in sections) {
      buffer.writeln('### ${section.title}');
      if (section.entries.isEmpty) buffer.writeln('- (없음)');
      for (final entry in section.entries.entries) {
        buffer.writeln('- ${entry.key}: ${entry.value}');
      }
      buffer.writeln();
    }
    buffer
      ..writeln(
        '### 최근 로그 (마지막 ${logLines.length}줄 · 파일 전체 '
        '${DevStateDump.formatBytes(DevLogFile.sizeBytes.value)})',
      )
      ..writeln('```text')
      ..writeln(logLines.join('\n'))
      ..writeln('```');
    return DevClipboardReport(text: buffer.toString(), logLineCount: logLines.length);
  }

  /// 토큰 > 앞 6자…뒤 4자 (길이)
  static String maskToken(String token) {
    if (token.length <= 12) return '(가림, ${token.length}자)';
    return '${token.substring(0, 6)}…${token.substring(token.length - 4)} (${token.length}자)';
  }

  /// JWT > 한 줄 (회원 sub · 역할 · 발급 · 만료와 남은 시간). JWT 가 아니면 사유
  static String describeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return '(JWT 아님)';
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      if (payload is! Map) return '(내용 없음)';
      final issuedAt = _secondsToTime(payload['iat']);
      final expiresAt = _secondsToTime(payload['exp']);
      return [
        '회원 ${payload['sub'] ?? '-'}',
        '역할 ${payload['role'] ?? '-'}',
        if (issuedAt != null) '발급 ${formatLocalTime(issuedAt)}',
        if (expiresAt != null) '만료 ${formatLocalTime(expiresAt)} (${_remainingLabel(expiresAt)})',
      ].join(' · ');
    } catch (error) {
      return '(읽지 못함: $error)';
    }
  }

  /// 시각 > yyyy-MM-dd HH:mm:ss (+09:00)
  static String formatLocalTime(DateTime time) {
    final local = time.toLocal();
    String pad(int value) => value.toString().padLeft(2, '0');
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final offsetLabel = '$sign${pad(offset.inHours.abs())}:${pad(offset.inMinutes.abs() % 60)}';
    return '${local.year}-${pad(local.month)}-${pad(local.day)} '
        '${pad(local.hour)}:${pad(local.minute)}:${pad(local.second)} ($offsetLabel)';
  }

  /// 최근 로그 줄: 파일 끝 [logLineCount]줄 (파일이 없으면 메모리 버퍼) > 글자 수 상한
  static Future<List<String>> _readRecentLogLines() async {
    var lines = DevLogFile.path == null ? DevLogBuffer.asText().split('\n') : (await DevLogFile.readAll()).split('\n');
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines = lines.sublist(0, lines.length - 1);
    }
    if (lines.length > logLineCount) lines = lines.sublist(lines.length - logLineCount);
    // 글자 수 상한: 오래된 줄부터 버림
    var characterCount = lines.fold<int>(0, (sum, line) => sum + line.length + 1);
    var start = 0;
    while (characterCount > logMaxCharacters && start < lines.length) {
      characterCount -= lines[start].length + 1;
      start++;
    }
    return lines.sublist(start);
  }

  static DateTime? _secondsToTime(Object? seconds) =>
      seconds is num ? DateTime.fromMillisecondsSinceEpoch((seconds * 1000).toInt()) : null;

  /// 만료까지 남은 시간 (예: 23시간 남음, 만료됨)
  static String _remainingLabel(DateTime expiresAt) {
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return '만료됨';
    if (remaining.inHours >= 1) return '${remaining.inHours}시간 남음';
    return '${remaining.inMinutes}분 남음';
  }
}

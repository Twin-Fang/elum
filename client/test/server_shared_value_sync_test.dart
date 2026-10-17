@Tags(['sync'])
library;

import 'dart:io';

import 'package:elum/core/logger/app_log_buffer.dart';
import 'package:elum/features/link/domain/link_code.dart';
import 'package:flutter_test/flutter_test.dart';

/// 서버와 손으로 맞춰 둔 값 3개: 연결 암호 글자 집합, 의견 기록 구역 표지, 로고 SVG 사본.
/// 서버 파일이 없는 체크아웃에서는 건너뜀 (server_error_sync_test 와 같은 방식)
void main() {
  const serverRoot = '../server/src/main';

  /// 서버 파일 읽기. 없으면 건너뜀 표시 후 null
  String? readServerFile(String path) {
    final file = File('$serverRoot/$path');
    if (!file.existsSync()) {
      markTestSkipped('서버 파일이 없다 — 이 체크아웃에서는 건너뛴다');
      return null;
    }
    return file.readAsStringSync();
  }

  /// `NAME = "값";` 형태의 자바 문자열 상수 추출
  String? javaStringConstant(String source, String name) =>
      RegExp('\\b$name\\s*=\\s*"([^"]*)";').firstMatch(source)?.group(1);

  // 깨지면: 맞는 연결 암호가 앱에서 막히거나, 앱이 통과시킨 암호를 서버가 404로 거절
  test('연결 암호 글자 집합이 서버 LinkCode.ALPHABET 과 같다', () {
    final source = readServerFile(
      'java/com/chuseok22/elumserver/link/core/LinkCode.java',
    );
    if (source == null) return;

    final serverAlphabet = javaStringConstant(source, 'ALPHABET');
    expect(serverAlphabet, isNotNull, reason: '추출에 실패하면 이 테스트는 아무것도 못 본다');
    expect(LinkCode.alphabet, serverAlphabet);
  });

  // 깨지면: 관리자 화면이 의견 첨부 기록에서 오류·기록 구역을 못 나눠 통째로 보임
  test('의견 기록 구역 표지가 서버 Feedback 과 같다', () {
    final source = readServerFile(
      'java/com/chuseok22/elumserver/feedback/infrastructure/entity/Feedback.java',
    );
    if (source == null) return;

    expect(javaStringConstant(source, 'ERROR_SECTION'), AppLogBuffer.errorSectionTitle);
    expect(javaStringConstant(source, 'LOG_SECTION'), AppLogBuffer.logSectionTitle);
  });

  // 깨지면: 앱과 관리자 화면의 로고가 서로 다른 그림으로 보임
  test('관리자 화면 로고 SVG 가 앱 로고와 같다', () {
    final serverLogo = readServerFile(
      'resources/static/admin/vendor/logo_elum.svg',
    );
    if (serverLogo == null) return;

    expect(
      serverLogo,
      File('assets/images/logo_elum.svg').readAsStringSync(),
      reason: '원본은 client/assets/images/logo_elum.svg — 서버 사본을 원본으로 덮어쓴다',
    );
  });
}

import 'package:dio/dio.dart';
import 'package:elum/core/network/server_error.dart';
import 'package:elum/core/network/server_error_code.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _err(dynamic data, {int status = 400}) => DioException(
  requestOptions: RequestOptions(path: '/x'),
  response: Response(
    requestOptions: RequestOptions(path: '/x'),
    statusCode: status,
    data: data,
  ),
);

void main() {
  group('서버 에러 코드는 서버 enum과 이름이 맞는다 (이슈 #347)', () {
    test('아는 코드는 그대로 매핑된다', () {
      expect(
        ServerErrorCode.from('OAUTH_EMAIL_CONFLICT'),
        ServerErrorCode.oauthEmailConflict,
      );
      expect(
        ServerErrorCode.from('MEMBER_SUSPENDED'),
        ServerErrorCode.memberSuspended,
      );
      expect(
        ServerErrorCode.from('MAINTENANCE_MODE'),
        ServerErrorCode.maintenanceMode,
      );
    });

    test('모르는 코드·빈 값은 unknown이다 — 던지지 않는다', () {
      expect(ServerErrorCode.from('NOPE_NOT_A_CODE'), ServerErrorCode.unknown);
      expect(ServerErrorCode.from(''), ServerErrorCode.unknown);
      expect(ServerErrorCode.from(null), ServerErrorCode.unknown);
    });
  });

  group('응답에서 에러를 꺼낸다 (이슈 #347)', () {
    test('서버 문구가 있으면 그것을 쓴다', () {
      final e = _err({
        'errorCode': 'OAUTH_PROVIDER_UNSUPPORTED',
        'errorMessage': '지원하지 않는 로그인 방식입니다.',
      }).serverError;

      expect(e.messageOr('잠시 후 다시 해주세요'), '지원하지 않는 로그인 방식입니다.');
    });

    // 서버가 새 코드를 먼저 배포하는 일은 반드시 생긴다. 코드를 몰라도
    // 문구는 맞으므로 그대로 보여줄 수 있어야 한다.
    group('본문이 어떤 모양이어도 죽지 않는다', () {
      test('응답 자체가 없다 (연결 실패)', () {
        final e = DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ).serverError;
        expect(e.code, ServerErrorCode.unknown);
        expect(e.badge, 'E-HTTP-0');
      });
    });
  });
}

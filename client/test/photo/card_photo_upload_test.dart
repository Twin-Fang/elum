import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:elum/features/guardian/data/card_image_repository.dart';
import 'package:elum/features/guardian/data/card_photo.dart';
import 'package:flutter_test/flutter_test.dart';

/// 카드 그림을 사진으로 바꾸는 업로드 계약 (#456 · 서버 #455).
///
/// `PUT /api/routines/{routineId}/steps/{stepId}/image` · multipart · 필드 `image`
/// · JPEG/PNG · 5MB 이하. 응답은 카드 한 장이다.
void main() {
  late _Adapter adapter;
  late CardImageRepository repo;

  /// JPEG 시작 바이트(FF D8 FF)만 갖춘 가짜 사진.
  final jpeg = PickedPhoto(bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]));

  setUp(() {
    adapter = _Adapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = adapter;
    repo = CardImageRepository(dio: dio);
  });

  test('PUT · image 필드 · JPEG 로 올린다', () async {
    adapter.ok({'id': 's1', 'imagePath': 'k/new.jpg'});

    final r = await repo.uploadPhoto(routineId: 'r1', stepId: 's1', photo: jpeg);

    expect(adapter.method, 'PUT');
    expect(adapter.path, '/api/routines/r1/steps/s1/image');
    final file = adapter.form!.files.single;
    expect(file.key, 'image');
    expect(file.value.contentType?.mimeType, 'image/jpeg');
    expect(r.card?.imagePath, 'k/new.jpg');
    expect(r.failure, isNull);
  });

  test('올리는 데 시간 제한을 둔다 — 끊긴 망에서 무한히 돌지 않는다', () async {
    adapter.ok({'id': 's1', 'imagePath': 'k/new.jpg'});

    await repo.uploadPhoto(routineId: 'r1', stepId: 's1', photo: jpeg);

    expect(adapter.sendTimeout, isNotNull);
    expect(adapter.sendTimeout, greaterThan(Duration.zero));
  });

  test('PNG 는 PNG 로 표시해 올린다', () async {
    adapter.ok({'id': 's1', 'imagePath': 'k/new.png'});
    final png = PickedPhoto(
      bytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
    );

    await repo.uploadPhoto(routineId: 'r1', stepId: 's1', photo: png);

    expect(adapter.form!.files.single.value.contentType?.mimeType, 'image/png');
  });

  test('5MB 를 넘으면 보내지 않는다 — E-PHOTO-SIZE', () async {
    final big = PickedPhoto(
      bytes: Uint8List(CardPhotoRules.maxBytes + 1)
        ..[0] = 0xFF
        ..[1] = 0xD8
        ..[2] = 0xFF,
    );

    final r = await repo.uploadPhoto(routineId: 'r1', stepId: 's1', photo: big);

    expect(adapter.calls, 0, reason: '서버가 거절할 걸 알면서 보내지 않는다');
    expect(r.failure?.code, 'E-PHOTO-SIZE');
    expect(r.failure?.kind, PhotoFailureKind.pickAnother);
  });

  test('JPEG·PNG 가 아니면 보내지 않는다 — E-PHOTO-TYPE', () async {
    // WebP: RIFF....WEBP
    final webp = PickedPhoto(
      bytes: Uint8List.fromList(
        [...ascii.encode('RIFF'), 0, 0, 0, 0, ...ascii.encode('WEBP')],
      ),
    );

    final r = await repo.uploadPhoto(routineId: 'r1', stepId: 's1', photo: webp);

    expect(adapter.calls, 0);
    expect(r.failure?.code, 'E-PHOTO-TYPE');
    expect(r.failure?.kind, PhotoFailureKind.pickAnother);
  });

  test('빈 사진은 보내지 않는다', () async {
    final r = await repo.uploadPhoto(
      routineId: 'r1',
      stepId: 's1',
      photo: PickedPhoto(bytes: Uint8List(0)),
    );

    expect(adapter.calls, 0);
    expect(r.failure?.code, 'E-PHOTO-READ');
  });

  test('400 — 서버 문구를 그대로 쓰고 다른 사진을 고르게 한다', () async {
    adapter.fail(400, code: 'ROUTINE_STEP_IMAGE_TOO_LARGE', message: '사진은 5MB 까지 올릴 수 있어요.');

    final r = await repo.uploadPhoto(routineId: 'r1', stepId: 's1', photo: jpeg);

    expect(r.failure?.message, '사진은 5MB 까지 올릴 수 있어요.');
    // 앱이 아직 모르는 서버 코드는 자리 코드 + 상태로 남긴다
    expect(r.failure?.code, 'ROUTINE_STEP_IMAGE_TOO_LARGE');
    expect(r.failure?.kind, PhotoFailureKind.pickAnother);
  });

  test('403 — 다시 해도 같다, 알리고 닫는다', () async {
    adapter.fail(403, code: 'ROUTINE_NOT_CREATOR', message: '내 일과가 아니에요.');

    final r = await repo.uploadPhoto(routineId: 'r1', stepId: 's1', photo: jpeg);

    expect(r.failure?.code, 'ROUTINE_NOT_CREATOR');
    expect(r.failure?.kind, PhotoFailureKind.dismissOnly);
  });

  test('404 — 지워진 카드다', () async {
    adapter.fail(404, code: 'ROUTINE_STEP_NOT_FOUND', message: '카드를 찾을 수 없어요.');

    final r = await repo.uploadPhoto(routineId: 'r1', stepId: 's1', photo: jpeg);

    expect(r.failure?.code, 'ROUTINE_STEP_NOT_FOUND');
    expect(r.failure?.kind, PhotoFailureKind.dismissOnly);
  });

  test('500 — 같은 사진으로 다시 할 수 있다', () async {
    adapter.fail(500, code: 'ROUTINE_STEP_IMAGE_SAVE_FAILED');

    final r = await repo.uploadPhoto(routineId: 'r1', stepId: 's1', photo: jpeg);

    expect(r.failure?.code, 'ROUTINE_STEP_IMAGE_SAVE_FAILED');
    expect(r.failure?.kind, PhotoFailureKind.retrySame);
  });

  test('네트워크가 끊기면 인터넷 안내와 함께 다시 하게 한다', () async {
    adapter.offline();

    final r = await repo.uploadPhoto(routineId: 'r1', stepId: 's1', photo: jpeg);

    expect(r.failure?.code, 'E-NET-OFFLINE');
    expect(r.failure?.message, contains('인터넷'));
    expect(r.failure?.kind, PhotoFailureKind.retrySame);
  });

  test('타임아웃도 다시 하게 한다', () async {
    adapter.timeout();

    final r = await repo.uploadPhoto(routineId: 'r1', stepId: 's1', photo: jpeg);

    expect(r.failure?.code, 'E-NET-TIMEOUT');
    expect(r.failure?.kind, PhotoFailureKind.retrySame);
  });

  test('200 인데 본문이 비었으면 실패로 본다 — 성공으로 착각하지 않는다', () async {
    adapter.emptyOk();

    final r = await repo.uploadPhoto(routineId: 'r1', stepId: 's1', photo: jpeg);

    expect(r.card, isNull);
    expect(r.failure?.code, 'E-PHOTO');
  });

  test('imagePath 가 비어 오면 실패로 본다 — 그림이 안 바뀐 것이다', () async {
    adapter.ok({'id': 's1'});

    final r = await repo.uploadPhoto(routineId: 'r1', stepId: 's1', photo: jpeg);

    expect(r.card, isNull);
    expect(r.failure?.code, 'E-PHOTO');
  });
}

class _Adapter implements HttpClientAdapter {
  int calls = 0;
  String? method;
  String? path;
  FormData? form;
  Duration? sendTimeout;

  int _status = 200;
  Object? _body;
  Object? _throw;

  void ok(Map<String, Object?> body) {
    _status = 200;
    _body = body;
  }

  void emptyOk() {
    _status = 200;
    _body = null;
  }

  void fail(int status, {String? code, String? message}) {
    _status = status;
    _body = {'errorCode': ?code, 'errorMessage': ?message};
  }

  void offline() => _throw = 'offline';
  void timeout() => _throw = 'timeout';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    method = options.method;
    path = options.path;
    sendTimeout = options.sendTimeout;
    final data = options.data;
    if (data is FormData) form = data;

    if (_throw == 'offline') throw DioException(requestOptions: options);
    if (_throw == 'timeout') {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    }
    if (_status >= 400) {
      throw DioException(
        requestOptions: options,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: _status,
          data: _body,
        ),
        type: DioExceptionType.badResponse,
      );
    }
    return ResponseBody.fromString(
      _body == null ? '' : jsonEncode(_body),
      _status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

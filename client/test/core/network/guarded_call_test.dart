import 'package:dio/dio.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/network/guarded_call.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// 저장소 공통 호출 래퍼 — 로그 3종(호출·완료·실패)과 실패 계약을 고정한다.
void main() {
  late List<String> logs;
  late DebugPrintCallback original;

  setUp(() {
    logs = [];
    original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
  });

  tearDown(() => debugPrint = original);

  group('guarded', () {

    test('예외는 AppFailure 실패로 바꾸고 실패 로그를 남긴다', () async {
      final r = await guarded<int>(
        'FooRepository',
        'load',
        () async => throw DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      expect(r.isOk, isFalse);
      expect(r.value, isNull);
      expect(r.failure, isA<AppFailure>());
      expect(r.failure!.fault, NetworkFault.timeout);
      expect(logs.any((l) => l.contains('실패') && l.contains('load')), isTrue);
    });

    test('본문이 던진 AppFailure 는 그대로 실패 값이 된다', () async {
      const thrown = AppFailure(fault: NetworkFault.app);
      final r = await guarded<int>('FooRepository', 'load', () async => throw thrown);

      expect(r.failure, same(thrown));
    });
  });

  group('logged', () {

    test('실패하면 같은 예외를 다시 던지고 실패 로그를 남긴다', () async {
      final error = StateError('boom');

      await expectLater(
        logged<int>('FooRepository', 'load', () async => throw error),
        throwsA(same(error)),
      );
      expect(logs.any((l) => l.contains('실패') && l.contains('boom')), isTrue);
    });
  });
}

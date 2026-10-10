import 'dart:async';

import 'package:elum/core/state/single_flight.dart';
import 'package:flutter_test/flutter_test.dart';

/// 진행 중인 작업을 함께 받는 장치.
///
/// 버튼 잠금이 뚫려 같은 저장이 두 번 불려도 서버로는 한 번만 가야 한다.
void main() {
  test('진행 중에 다시 부르면 새로 실행하지 않고 같은 결과를 받는다', () async {
    final flight = SingleFlight<int>();
    final gate = Completer<int>();
    var calls = 0;

    final a = flight.run(() {
      calls++;
      return gate.future;
    });
    final b = flight.run(() async {
      calls++;
      return -1;
    });

    expect(flight.running, isTrue);
    gate.complete(7);
    expect(await a, 7);
    expect(await b, 7);
    expect(calls, 1);
    expect(flight.running, isFalse);
  });

  test('끝난 뒤에는 새로 실행한다', () async {
    final flight = SingleFlight<int>();
    var calls = 0;

    await flight.run(() async => ++calls);
    await flight.run(() async => ++calls);

    expect(calls, 2);
  });

  test('실패해도 비워서 다시 누르면 새로 실행한다', () async {
    final flight = SingleFlight<int>();

    await expectLater(
      flight.run(() async => throw StateError('실패')),
      throwsStateError,
    );
    expect(flight.running, isFalse);
    expect(await flight.run(() async => 1), 1);
  });

  test('작업이 곧바로 던져도 Future 에러로 받는다', () async {
    final flight = SingleFlight<int>();

    await expectLater(
      flight.run(() => throw StateError('동기 실패')),
      throwsStateError,
    );
    expect(flight.running, isFalse);
  });
}

import 'dart:async';

import 'package:elum/core/state/busy_state_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 화면의 진행 중 잠금.
///
/// 응답을 기다리는 동안 다시 눌러도 한 번만 실행되고, 끝나면(실패해도) 다시 누를 수 있어야 한다.
void main() {
  late GlobalKey<_ProbeState> key;

  Future<void> pumpProbe(WidgetTester tester) async {
    key = GlobalKey<_ProbeState>();
    await tester.pumpWidget(MaterialApp(home: _Probe(key: key)));
  }

  testWidgets('진행 중에 다시 부르면 실행하지 않고 null 을 받는다', (tester) async {
    await pumpProbe(tester);
    final state = key.currentState!;
    final gate = Completer<int>();
    var calls = 0;

    final first = state.runBusy(() {
      calls++;
      return gate.future;
    });
    await tester.pump();
    expect(state.busy, isTrue);

    final second = await state.runBusy(() async {
      calls++;
      return 2;
    });
    expect(second, isNull);

    gate.complete(1);
    expect(await first, 1);
    await tester.pump();
    expect(state.busy, isFalse);
    expect(calls, 1);
  });

  testWidgets('실패해도 잠금을 풀고 에러는 그대로 던진다', (tester) async {
    await pumpProbe(tester);
    final state = key.currentState!;

    await expectLater(
      state.runBusy<int>(() async => throw StateError('실패')),
      throwsStateError,
    );
    await tester.pump();
    expect(state.busy, isFalse);
    expect(await state.runBusy(() async => 3), 3);
  });

  testWidgets('진행 중 화면이 닫혀도 예외가 나지 않는다', (tester) async {
    await pumpProbe(tester);
    final state = key.currentState!;
    final gate = Completer<int>();

    final pending = state.runBusy(() => gate.future);
    await tester.pumpWidget(const SizedBox());
    gate.complete(1);

    expect(await pending, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('항목 잠금은 key 가 다르면 서로 막지 않고, 화면 잠금은 모두 막는다',
      (tester) async {
    await pumpProbe(tester);
    final state = key.currentState!;
    final a = Completer<void>();

    final runA = state.runBusy(() => a.future, key: 'a');
    await tester.pump();
    expect(state.isBusy('a'), isTrue);

    var bRan = false;
    await state.runBusy(() async => bRan = true, key: 'b');
    expect(bRan, isTrue);

    var screenRan = false;
    await state.runBusy(() async => screenRan = true);
    expect(screenRan, isFalse, reason: '항목이 진행 중이면 화면 전체 작업은 기다린다');

    a.complete();
    await runA;
    await tester.pump();
    expect(state.isBusy('a'), isFalse);
  });
}

class _Probe extends StatefulWidget {
  const _Probe({super.key});

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with BusyStateMixin<_Probe> {
  @override
  Widget build(BuildContext context) => const SizedBox();
}

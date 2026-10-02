import 'package:elum/features/child/application/routine_auto_refresh.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/shared/models/routine.dart';
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 이룸이 홈 일과 주기 갱신 (이슈 #517).
void main() {
  var fetchCount = 0;
  var shouldFail = false;
  Completer<void>? hold;

  Widget host() => ProviderScope(
    overrides: [
      todayRoutinesProvider.overrideWith((ref) async {
        fetchCount++;
        if (hold != null) await hold!.future;
        if (shouldFail) throw Exception('network');
        return <Routine>[];
      }),
    ],
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Consumer(
        builder: (context, ref, _) {
          // provider 를 실제로 구독해야 invalidate 가 다시 받는다.
          ref.watch(todayRoutinesProvider);
          return const RoutineAutoRefresh(
            interval: Duration(seconds: 30),
            child: SizedBox(),
          );
        },
      ),
    ),
  );

  setUp(() {
    fetchCount = 0;
    shouldFail = false;
    hold = null;
  });

  testWidgets('30초마다 오늘 일과를 다시 받는다', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    expect(fetchCount, 1);

    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(fetchCount, 2);

    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(fetchCount, 3);
  });

  testWidgets('백그라운드에서는 멈추고, 돌아오면 즉시 한 번 받는다', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    expect(fetchCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 90));
    expect(fetchCount, 1, reason: '백그라운드 중에는 받지 않는다');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(fetchCount, 2, reason: '돌아오면 곧바로 받는다');

    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(fetchCount, 3, reason: '주기가 다시 돈다');
  });

  testWidgets('받기가 실패해도 앱이 죽지 않고 다음 주기에 다시 시도한다', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    shouldFail = true;
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(fetchCount, greaterThanOrEqualTo(2));
    expect(tester.takeException(), isNull);

    // Riverpod 이 실패를 스스로 재시도할 수 있어 정확한 횟수 대신 늘어나는지만 본다.
    final afterFail = fetchCount;
    shouldFail = false;
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(fetchCount, greaterThan(afterFail));
  });

  testWidgets('화면이 사라지면 타이머가 멈춘다', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 120));
    expect(fetchCount, 1);
  });

  testWidgets('응답이 느려 아직 받는 중이면 요청을 쌓지 않는다', (tester) async {
    hold = Completer<void>();
    await tester.pumpWidget(host());
    await tester.pump();
    expect(fetchCount, 1);

    await tester.pump(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 30));
    expect(fetchCount, 1, reason: '첫 요청이 끝나기 전에는 다시 보내지 않는다');

    hold!.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(fetchCount, 2);
  });

  // 보호자 화면에서 받아 둔 목록을 들고 이룸이 화면으로 넘어오는 상황 (이슈 #541).
  testWidgets('이미 받아 둔 목록이 있으면 들어오자마자 다시 받는다', (tester) async {
    final showRefresher = ValueNotifier(false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todayRoutinesProvider.overrideWith((ref) async {
            fetchCount++;
            return <Routine>[];
          }),
        ],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Consumer(
            builder: (context, ref, _) {
              ref.watch(todayRoutinesProvider);
              return ValueListenableBuilder<bool>(
                valueListenable: showRefresher,
                builder: (_, show, _) => show
                    ? const RoutineAutoRefresh(child: SizedBox())
                    : const SizedBox(),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(fetchCount, 1, reason: '앞 화면이 한 번 받아 두었다');

    showRefresher.value = true;
    await tester.pump();
    await tester.pump();
    expect(fetchCount, 2, reason: '30초를 기다리지 않고 바로 받는다');
  });
}

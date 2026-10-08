import 'package:elum/features/child/application/routine_auto_refresh.dart';
import 'package:elum/features/member/data/member_repository.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/shared/models/routine.dart';
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elum/features/member/application/member_providers.dart';

/// 이룸이 홈 일과 주기 갱신 (이슈 #517).
void main() {
  var fetchCount = 0;
  var shouldFail = false;
  Completer<void>? hold;

  // 회원 정보(누적 별) 응답. null 이면 오프라인처럼 실패한 것이다.
  var memberFetchCount = 0;
  Member? memberResponse;
  Completer<void>? memberHold;

  Future<Member?> fetchMember() async {
    memberFetchCount++;
    if (memberHold != null) await memberHold!.future;
    return memberResponse;
  }

  /// 화면이 쓰는 별 개수. 실제 화면처럼 memberProvider 의 값을 읽는다.
  final shownStars = <int>[];

  Widget host() => ProviderScope(
    overrides: [
      memberFetcherProvider.overrideWithValue(fetchMember),
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
          shownStars.add(ref.watch(memberProvider).value?.totalStars ?? -1);
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
    memberFetchCount = 0;
    memberResponse = const Member(totalStars: 3);
    memberHold = null;
    shownStars.clear();
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
          memberFetcherProvider.overrideWithValue(fetchMember),
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

  group('누적 별(회원 정보)', () {
    testWidgets('다른 휴대폰에서 올린 별을 30초 주기로 받아 반영한다', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      expect(shownStars.last, 3);

      memberResponse = const Member(totalStars: 9);
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      await tester.pump();
      expect(shownStars.last, 9);
    });

    testWidgets('받기가 실패하면(오프라인) 마지막 별을 0 으로 되돌리지 않는다', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      expect(shownStars.last, 3);

      memberResponse = null;
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(memberFetchCount, greaterThanOrEqualTo(3), reason: '실패해도 다음 주기에 다시 시도한다');
      expect(shownStars.last, 3);
      expect(shownStars, isNot(contains(0)));
    });

    testWidgets('값이 같으면 구독자를 다시 그리지 않는다', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      final before = shownStars.length;

      // 새 객체지만 내용은 같다
      memberResponse = const Member(totalStars: 3);
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      await tester.pump();
      expect(memberFetchCount, greaterThanOrEqualTo(2));
      // 일과 갱신으로 다시 그려지는 것은 있어도 회원 정보가 바뀐 재빌드는 없다 — 별 값 변화 없음
      expect(shownStars.skip(before).every((s) => s == 3), isTrue);
    });

    testWidgets('응답이 느려 아직 받는 중이면 회원 정보 요청을 쌓지 않는다', (tester) async {
      memberHold = Completer<void>();
      await tester.pumpWidget(host());
      await tester.pump();
      final first = memberFetchCount;

      await tester.pump(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 30));
      expect(memberFetchCount, first, reason: '앞 요청이 끝나기 전에는 다시 보내지 않는다');

      memberHold!.complete();
      await tester.pump();
    });
  });
}

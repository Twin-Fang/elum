import 'package:dio/dio.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/network/server_error.dart';
import 'package:elum/core/network/server_error_code.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/features/link/data/device_link_repository.dart';
import 'package:elum/features/link/domain/link_status.dart';
import 'package:elum/features/link/presentation/link_code_screen.dart';
import 'package:elum/features/link/presentation/link_enter_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/device_viewport.dart';
import '../helpers/pump_with_locale.dart';
import '../helpers/test_storage.dart';
import 'package:elum/core/storage/in_memory_storage.dart';

/// 옮긴 link 문구가 옛 한국어와 같다 — 기대값은 손으로 쓴 한국어(옛 코드가 만들던 값)다.
void main() {
  useFigmaViewport();

  group('코드 입력 화면 — 글자가 ARB 에서 온다', () {
    late _EnterFake repo;
    setUp(() => repo = _EnterFake());

    Future<void> pumpEnter(WidgetTester tester) => pumpWithLocale(
      tester,
      const LinkEnterScreen(),
      wrap: (app) => ProviderScope(
        overrides: [deviceLinkRepositoryProvider.overrideWithValue(repo)],
        child: app,
      ),
    );

    Future<void> submit(WidgetTester tester, String code) async {
      await tester.enterText(find.byType(TextField), code);
      await tester.pumpAndSettle();
      await tester.tap(find.text('시작하기'));
      await tester.pumpAndSettle();
    }

    testWidgets('실패 종류별 문구 — 서버 문구가 없으면 기본 문구와 에러 코드', (tester) async {
      final cases = <RedeemOutcome, String>{
        RedeemOutcome.notFound: '암호가 맞지 않아요 (E-LINK-404)',
        RedeemOutcome.expired: '암호가 만료됐어요. 새 암호를 받아주세요 (E-LINK-410)',
        RedeemOutcome.tooManyAttempts: '잠시 후 다시 해주세요 (E-LINK-429)',
        RedeemOutcome.offline: '연결하지 못했어요. 인터넷을 확인해주세요 (E-NET)',
        RedeemOutcome.failed: '연결하지 못했어요. 다시 해주세요 (E-LINK)',
      };
      for (final entry in cases.entries) {
        repo.outcome = entry.key;
        // 화면마다 새로 연다 — 인터넷 끊김은 입력을, 시도 한도는 잠금을 남긴다
        await tester.pumpWidget(const SizedBox());
        await pumpEnter(tester);
        await tester.pumpAndSettle();
        await submit(tester, 'A7K3M9');
        expect(find.text(entry.value), findsOneWidget, reason: '${entry.key}');
      }
    });

    testWidgets('서버가 준 문구가 기본 문구를 이긴다', (tester) async {
      repo.outcome = RedeemOutcome.failed;
      repo.failure = const AppFailure(
        fault: NetworkFault.none,
        server: ServerError(code: ServerErrorCode.unknown, message: '서버가 준 말'),
      );
      await pumpEnter(tester);
      await tester.pumpAndSettle();
      await submit(tester, 'A7K3M9');

      expect(find.textContaining('서버가 준 말'), findsOneWidget);
      expect(find.textContaining('연결하지 못했어요'), findsNothing);
    });
  });

  group('연결 암호 화면 — 글자가 ARB 에서 온다', () {
    Future<void> pumpCode(
      WidgetTester tester, {
      String nickname = '',
      bool fromOnboarding = true,
      _CodeFake? repo,
    }) => pumpWithLocale(
      tester,
      LinkCodeScreen(fromOnboarding: fromOnboarding),
      wrap: (app) => ProviderScope(
        overrides: [
          deviceLinkRepositoryProvider.overrideWithValue(repo ?? _CodeFake()),
          testStorageOverride(nickname: nickname),
        ],
        child: app,
      ),
    );

    // 이름 값마다 새 화면으로 띄운다 (받침 없음·있음)

    testWidgets('발급이 실패하면 설명 자리에 기본 문구와 에러 코드', (tester) async {
      await pumpCode(tester, repo: _CodeFake()..fail = true);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('암호를 만들지 못했어요. 다시 해주세요 (E-LINK-NEW)'), findsOneWidget);
    });
  });
}

class _EnterFake extends DeviceLinkRepository {
  _EnterFake()
    : super(
        dio: Dio(),
        tokens: InMemoryTokenStore(),
        storage: InMemoryStorage(),
      );

  RedeemOutcome outcome = RedeemOutcome.linked;
  AppFailure? failure;
  bool lost = false;

  @override
  bool get linkWasLost => lost;

  @override
  Future<RedeemResult> redeem(String code) async =>
      RedeemResult(outcome, failure: failure);
}

class _CodeFake extends DeviceLinkRepository {
  _CodeFake()
    : super(
        dio: Dio(),
        tokens: InMemoryTokenStore(),
        storage: InMemoryStorage(),
      );

  bool fail = false;

  @override
  Future<Attempt<IssuedLinkCode>> issue() async => fail
      ? const Attempt.failed(AppFailure(fault: NetworkFault.none))
      : Attempt.ok(
          IssuedLinkCode.fromNow(code: '5NJ280', expiresInSeconds: 600),
        );

  @override
  Future<Attempt<LinkStatus>> statusResult() async =>
      const Attempt.ok(LinkStatus(devices: []));
}

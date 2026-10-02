import 'dart:async';

import 'package:elum/core/ads/rewarded_ad_loader.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/network/server_error.dart';
import 'package:elum/core/network/server_error_code.dart';
import 'package:elum/features/credit/application/ad_reward_flow.dart';
import 'package:elum/features/credit/domain/ad_reward.dart';
import 'package:elum/features/credit/domain/credit_summary.dart';
import 'package:elum/features/credit/presentation/credit_blocked_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/credit_fixtures.dart';
import '../helpers/device_viewport.dart';
import '../helpers/fake_ad_reward.dart';
import '../helpers/pump_with_locale.dart';

/// 지급 확인을 [gate] 가 열릴 때까지 붙잡는 저장소 — 대기 팝업을 보려고 쓴다.
class _GatedRepo extends FakeAdRewardRepo {
  _GatedRepo(this.gate, {required super.statuses});
  final Completer<void> gate;

  @override
  Future<AdRewardSessionStatus> getStatus(String nonce) async {
    await gate.future;
    return super.getStatus(nonce);
  }
}

AdRewardFlow _flow(
  FakeAdRewardRepo repo,
  FakeRewardedLoader loader, {
  Duration poll = const Duration(milliseconds: 1),
}) => AdRewardFlow(
  repository: repo,
  loader: loader,
  adsEnabled: true,
  pollInterval: poll,
  maxPolls: 2,
);

AppFailure _server(ServerErrorCode code, {String? message}) => AppFailure(
  fault: NetworkFault.none,
  server: ServerError(code: code, message: message, statusCode: 403),
);

Future<String> _sentence(AdRewardFlow flow) async =>
    (await flow.run()).failure!.sentence;

AdRewardSessionStatus _status(String reason) =>
    AdRewardSessionStatus(phase: AdRewardPhase.rejected, reason: reason);

void main() {
  useFigmaViewport();
  group('실패 안내 문구(서버 문구가 없을 때의 대체)', () {
    test('광고 표시 결과별', () async {
      expect(
        await _sentence(
          _flow(
            FakeAdRewardRepo(),
            FakeRewardedLoader(end: RewardedAdEnd.loadFailed),
          ),
        ),
        '지금은 광고를 불러올 수 없어요.\n잠시 후 다시 해주세요',
      );
      expect(
        await _sentence(
          _flow(
            FakeAdRewardRepo(),
            FakeRewardedLoader(end: RewardedAdEnd.dismissed),
          ),
        ),
        '광고를 끝까지 봐야 크레딧을 받을 수 있어요.\n처음부터 다시 해주세요',
      );
    });

    test('지급을 못 받은 이유별', () async {
      Future<String> reason(String r) => _sentence(
        _flow(FakeAdRewardRepo(statuses: [_status(r)]), FakeRewardedLoader()),
      );
      expect(
        await reason('DAILY_LIMIT'),
        '오늘은 광고로 받을 수 있는 크레딧을 모두 받았어요.\n내일 다시 해주세요',
      );
      expect(await reason('FROZEN'), '지금은 광고로 크레딧을 받을 수 없어요.\n계정 상태를 확인해주세요');
      expect(await reason('DISABLED'), '지금은 광고로 크레딧을 받을 수 없어요.');
      expect(await reason('EXPIRED'), '크레딧을 받지 못했어요.\n잠시 후 다시 해주세요');
    });

    test('확인이 늦어지면 설정에서 확인하게 한다', () async {
      final flow = _flow(
        FakeAdRewardRepo(
          statuses: const [AdRewardSessionStatus(phase: AdRewardPhase.pending)],
        ),
        FakeRewardedLoader(),
      );
      expect(await _sentence(flow), '크레딧 확인이 늦어지고 있어요.\n잠시 후 설정에서 확인해주세요');
    });

    test('세션을 못 만든 이유별 — 서버 문구가 있으면 그것이 이긴다', () async {
      Future<String> session(AppFailure f) => _sentence(
        _flow(FakeAdRewardRepo(sessionError: f), FakeRewardedLoader()),
      );
      expect(
        await session(_server(ServerErrorCode.adRewardDailyLimit)),
        '오늘은 광고로 받을 수 있는 크레딧을 모두 받았어요.\n내일 다시 해주세요',
      );
      expect(
        await session(_server(ServerErrorCode.adRewardAccountFrozen)),
        '지금은 광고로 크레딧을 받을 수 없어요.\n계정 상태를 확인해주세요',
      );
      expect(
        await session(_server(ServerErrorCode.adRewardDisabled)),
        '지금은 광고로 크레딧을 받을 수 없어요.',
      );
      expect(
        await session(_server(ServerErrorCode.adRewardSessionNotFound)),
        '지금은 광고로 크레딧을 받을 수 없어요.\n잠시 후 다시 해주세요',
      );
      expect(
        await session(
          _server(ServerErrorCode.adRewardDailyLimit, message: '서버가 준 문구'),
        ),
        '서버가 준 문구',
      );
    });
  });

  group('홈 막기 팝업', () {
    CreditSummary blocked({
      bool generating = false,
      String reset = '2026-09-28T00:00:00',
    }) => CreditSummary.fromJson(
      creditJson(
        available: generating ? 5 : 0,
        canStartRoutine: true,
        inProgress: generating
            ? [
                {'jobId': 'j1', 'kind': 'ROUTINE_CREATE'},
              ]
            : const [],
      )..['nextResetAt'] = reset,
    );

    Future<void> open(
      WidgetTester tester,
      CreditSummary summary,
      FakeAdRewardRepo repo, {
      FakeRewardedLoader? loader,
    }) async {
      final flow = _flow(repo, loader ?? FakeRewardedLoader());
      await pumpWithLocale(
        tester,
        Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => showCreditBlockedDialog(context, ref, summary),
              child: const Text('열기'),
            ),
          ),
        ),
        wrap: (app) => ProviderScope(
          overrides: [adRewardFlowProvider.overrideWithValue(flow)],
          child: app,
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
    }

    FakeAdRewardRepo off() => FakeAdRewardRepo(
      offer: const AdRewardOffer(
        enabled: false,
        creditsPerView: 2,
        remainingToday: 0,
      ),
    );

    testWidgets('소진 — 광고가 꺼져 있으면 확인 하나, 시각은 값마다 다르다', (tester) async {
      await open(tester, blocked(), off());
      expect(
        find.text('이번 주 크레딧을 모두 사용했어요.\n9월 28일(월) 0시부터 다시 만들 수 있어요'),
        findsOneWidget,
      );
      expect(find.text('확인'), findsOneWidget);
      expect(find.text('닫기'), findsNothing);
    });

    testWidgets('소진 — 분이 있는 시각', (tester) async {
      await open(tester, blocked(reset: '2026-09-29T03:30:00'), off());
      expect(
        find.text('이번 주 크레딧을 모두 사용했어요.\n9월 29일(화) 3시 30분부터 다시 만들 수 있어요'),
        findsOneWidget,
      );
    });

    testWidgets('진행 중이면 만들고 있다는 문장', (tester) async {
      await open(tester, blocked(generating: true), off());
      expect(
        find.text('이미 일과를 만들고 있어요.\n다 만든 뒤에 새 일과를 만들 수 있어요'),
        findsOneWidget,
      );
    });

    for (final (n, text) in [(1, '1개'), (10, '10개')]) {
      testWidgets('광고 제안 — 크레딧 $n개', (tester) async {
        final repo = FakeAdRewardRepo(
          offer: AdRewardOffer(
            enabled: true,
            creditsPerView: n,
            remainingToday: 5,
          ),
        );
        await open(tester, blocked(), repo);
        expect(find.text('광고를 끝까지 보면 크레딧 $text를 받아요'), findsOneWidget);
        expect(find.text('닫기'), findsOneWidget);
        expect(find.text('광고 보고 더 만들기'), findsOneWidget);
      });
    }

    testWidgets('대기 팝업 두 단계와 지급 알림(받은 수가 1·12)', (tester) async {
      for (final (n, title) in [(1, '크레딧 1개를 받았어요'), (12, '크레딧 12개를 받았어요')]) {
        final gate = Completer<void>();
        final repo = _GatedRepo(
          gate,
          statuses: [
            AdRewardSessionStatus(
              phase: AdRewardPhase.granted,
              grantedCredits: n,
            ),
          ],
        );
        await open(tester, blocked(), repo);
        await tester.tap(find.text('광고 보고 더 만들기'));
        await tester.pump();
        await tester.pump();
        expect(find.text('크레딧을 확인하고 있어요'), findsOneWidget);
        gate.complete();
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
        await tester.tap(find.text('확인'));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('받은 수를 모르면 수 없는 제목', (tester) async {
      final repo = FakeAdRewardRepo(
        statuses: const [
          AdRewardSessionStatus(
            phase: AdRewardPhase.granted,
            grantedCredits: 0,
          ),
        ],
      );
      await open(tester, blocked(), repo);
      await tester.tap(find.text('광고 보고 더 만들기'));
      await tester.pumpAndSettle();
      expect(find.text('크레딧을 받았어요'), findsOneWidget);
    });

    testWidgets('광고를 준비하는 동안의 대기 문구', (tester) async {
      final loaderGate = Completer<RewardedAdEnd>();
      final loader = _SlowLoader(loaderGate);
      await open(tester, blocked(), FakeAdRewardRepo(), loader: loader);
      await tester.tap(find.text('광고 보고 더 만들기'));
      await tester.pump();
      await tester.pump();
      expect(find.text('광고를 준비하고 있어요'), findsOneWidget);
      loaderGate.complete(RewardedAdEnd.loadFailed);
      await tester.pumpAndSettle();
      // 실패 팝업: 문장과 확인 버튼
      expect(find.text('지금은 광고를 불러올 수 없어요.\n잠시 후 다시 해주세요'), findsOneWidget);
      expect(find.text('E-AD-LOAD'), findsOneWidget);
      expect(find.text('확인'), findsOneWidget);
    });

    testWidgets('비-ko 로케일은 번역 전이라 한국어 문구로 떨어진다', (tester) async {
      final flow = _flow(off(), FakeRewardedLoader());
      await pumpWithLocale(
        tester,
        Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => showCreditBlockedDialog(context, ref, blocked()),
              child: const Text('open'),
            ),
          ),
        ),
        locale: const Locale('en'),
        wrap: (app) => ProviderScope(
          overrides: [adRewardFlowProvider.overrideWithValue(flow)],
          child: app,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.textContaining('이번 주 크레딧을 모두 사용했어요.'), findsOneWidget);
    });
  });
}

/// 광고 표시가 끝나기를 [gate] 로 붙잡는 로더.
class _SlowLoader extends FakeRewardedLoader {
  _SlowLoader(this.gate);
  final Completer<RewardedAdEnd> gate;

  @override
  Future<RewardedAdEnd> showFor(String nonce) => gate.future;
}

import 'package:dio/dio.dart';
import 'package:elum/features/ads/data/rewarded_ad_loader.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/network/server_error.dart';
import 'package:elum/core/network/server_error_code.dart';
import 'package:elum/features/credit/application/ad_reward_flow.dart';
import 'package:elum/features/credit/data/ad_reward_repository.dart';
import 'package:elum/features/credit/domain/ad_reward.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_ad_reward.dart';
import '../helpers/fake_dio.dart';

const _pending = AdRewardSessionStatus(phase: AdRewardPhase.pending);
const _granted = AdRewardSessionStatus(
  phase: AdRewardPhase.granted,
  grantedCredits: 2,
);

AdRewardFlow _flow(
  FakeAdRewardRepo repo,
  FakeRewardedLoader loader, {
  bool adsEnabled = true,
}) => AdRewardFlow(
  repository: repo,
  loader: loader,
  adsEnabled: adsEnabled,
  pollInterval: const Duration(milliseconds: 1),
  maxPolls: 3,
);

AppFailure _serverFailure(ServerErrorCode code, {String? message}) =>
    AppFailure(
      fault: NetworkFault.none,
      server: ServerError(code: code, message: message, statusCode: 403),
    );

void main() {
  group('제안 — 버튼을 보일지', () {
    test('서버가 켜 둔 때만 보인다', () async {
      final offer = await _flow(
        FakeAdRewardRepo(),
        FakeRewardedLoader(),
      ).offer();
      expect(offer?.creditsPerView, 2);
    });

    // 지금 운영은 AD_REWARD_ENABLED=false 다. 배포해도 화면이 바뀌면 안 된다.
    test('서버가 꺼 두었으면 보이지 않는다', () async {
      final repo = FakeAdRewardRepo(
        offer: const AdRewardOffer(
          enabled: false,
          // 다른 값이 남아 있어도 꺼짐이 이긴다.
          creditsPerView: 2,
          remainingToday: 5,
        ),
      );
      expect(await _flow(repo, FakeRewardedLoader()).offer(), isNull);
    });

    test('오늘 횟수를 다 썼으면 보이지 않는다', () async {
      final repo = FakeAdRewardRepo(
        offer: const AdRewardOffer(
          enabled: true,
          creditsPerView: 2,
          remainingToday: 0,
        ),
      );
      expect(await _flow(repo, FakeRewardedLoader()).offer(), isNull);
    });

    test('제안 조회가 실패하면 보이지 않는다', () async {
      final repo = FakeAdRewardRepo(
        offerError: _serverFailure(ServerErrorCode.adRewardDisabled),
      );
      expect(await _flow(repo, FakeRewardedLoader()).offer(), isNull);
    });

    test('광고를 띄울 수 없는 환경이면 서버에 묻지도 않는다', () async {
      final repo = FakeAdRewardRepo();
      expect(
        await _flow(repo, FakeRewardedLoader(), adsEnabled: false).offer(),
        isNull,
      );
      // 릴리스인데 .env 광고 단위가 비어 있다
      expect(
        await _flow(repo, FakeRewardedLoader(configured: false)).offer(),
        isNull,
      );
      expect(repo.offerCalls, 0);
    });
  });

  group('시청 → 지급 확인', () {
    test('서버가 지급을 확인하면 그 크레딧을 알린다', () async {
      final repo = FakeAdRewardRepo(statuses: [_pending, _granted]);
      final loader = FakeRewardedLoader();

      final result = await _flow(repo, loader).run();

      expect(result.granted, isTrue);
      expect(result.grantedCredits, 2);
      // 서버가 발급한 nonce 를 광고에 실어 보낸다 — SSV 가 이 값으로 회원을 찾는다.
      expect(loader.shownNonces, ['N1']);
    });

    // 클라이언트 보고만으로는 지급하지 않는다 — 서버 확인이 안 오면 지급이 아니다.
    test('서버 확인이 오지 않으면 지급으로 치지 않는다', () async {
      final repo = FakeAdRewardRepo(statuses: [_pending]);

      final result = await _flow(repo, FakeRewardedLoader()).run();

      expect(result.granted, isFalse);
      expect(result.grantedCredits, 0);
      expect(result.failure?.code, 'E-AD-WAIT');
      expect(repo.statusCalls, 3);
    });

    test('다 보지 않고 닫으면 상태를 묻지 않고 안내한다', () async {
      final repo = FakeAdRewardRepo(statuses: [_granted]);
      final result = await _flow(
        repo,
        FakeRewardedLoader(end: RewardedAdEnd.dismissed),
      ).run();

      expect(result.granted, isFalse);
      expect(result.failure?.code, 'E-AD-SKIP');
      expect(repo.statusCalls, 0);
    });

    test('광고를 불러오지 못하면 안내한다', () async {
      final repo = FakeAdRewardRepo(statuses: [_granted]);
      final result = await _flow(
        repo,
        FakeRewardedLoader(end: RewardedAdEnd.loadFailed),
      ).run();

      expect(result.granted, isFalse);
      expect(result.failure?.code, 'E-AD-LOAD');
      expect(repo.statusCalls, 0);
    });

    test('광고 SDK 가 예외를 던져도 앱은 안내로 끝난다', () async {
      final result = await _flow(
        FakeAdRewardRepo(statuses: [_granted]),
        FakeRewardedLoader(error: StateError('sdk')),
      ).run();

      expect(result.failure?.code, 'E-AD-LOAD');
    });

    test('확인 중 일시적 오류가 나도 계속 기다린다', () async {
      final repo = FakeAdRewardRepo(
        statuses: [
          const AppFailure(fault: NetworkFault.offline),
          _granted,
        ],
      );
      final result = await _flow(repo, FakeRewardedLoader()).run();
      expect(result.granted, isTrue);
    });
  });

  group('세션을 못 만드는 경우 — 광고를 띄우지 않는다', () {
    for (final (code, wire) in [
      (ServerErrorCode.adRewardDailyLimit, 'AD_REWARD_DAILY_LIMIT'),
      (ServerErrorCode.adRewardAccountFrozen, 'AD_REWARD_ACCOUNT_FROZEN'),
      (ServerErrorCode.adRewardDisabled, 'AD_REWARD_DISABLED'),
      (ServerErrorCode.adRewardUnavailable, 'AD_REWARD_UNAVAILABLE'),
    ]) {
      test('$wire 는 코드와 함께 알린다', () async {
        final loader = FakeRewardedLoader();
        final result = await _flow(
          FakeAdRewardRepo(sessionError: _serverFailure(code)),
          loader,
        ).run();

        expect(result.granted, isFalse);
        expect(result.failure?.code, wire);
        expect(result.failure?.sentence, isNotEmpty);
        expect(loader.shownNonces, isEmpty);
      });
    }

    test('인터넷이 없으면 인터넷 안내와 네트워크 코드를 준다', () async {
      final result = await _flow(
        FakeAdRewardRepo(
          sessionError: const AppFailure(fault: NetworkFault.offline),
        ),
        FakeRewardedLoader(),
      ).run();

      expect(result.failure?.code, 'E-NET-OFFLINE');
      expect(result.failure?.sentence, contains('인터넷'));
    });
  });

  group('서버가 지급하지 않기로 한 경우', () {
    for (final (reason, wire) in [
      ('DAILY_LIMIT', 'AD_REWARD_DAILY_LIMIT'),
      ('FROZEN', 'AD_REWARD_ACCOUNT_FROZEN'),
      ('DISABLED', 'AD_REWARD_DISABLED'),
      ('EXPIRED', 'AD_REWARD_EXPIRED'),
    ]) {
      test('$reason → $wire', () async {
        final repo = FakeAdRewardRepo(
          statuses: [
            AdRewardSessionStatus(
              phase: AdRewardPhase.rejected,
              reason: reason,
            ),
          ],
        );
        final result = await _flow(repo, FakeRewardedLoader()).run();

        expect(result.granted, isFalse);
        expect(result.failure?.code, wire);
      });
    }

    test('시간이 지난 세션도 안내로 끝난다', () async {
      final repo = FakeAdRewardRepo(
        statuses: [const AdRewardSessionStatus(phase: AdRewardPhase.expired)],
      );
      final result = await _flow(repo, FakeRewardedLoader()).run();
      expect(result.failure?.code, 'AD_REWARD_EXPIRED');
    });
  });

  group('서버 계약', () {
    test('응답을 읽는다', () {
      final offer = AdRewardOffer.fromJson({
        'enabled': true,
        'creditsPerView': 2,
        'remainingToday': 5,
      });
      expect(offer.canOffer, isTrue);

      final status = AdRewardSessionStatus.fromJson({
        'status': 'REJECTED',
        'grantedCredits': 0,
        'reason': 'DAILY_LIMIT',
      });
      expect(status.phase, AdRewardPhase.rejected);
      expect(status.reason, 'DAILY_LIMIT');
    });

    test('모양이 다르면 0 으로 채우지 않고 던진다', () {
      expect(
        () => AdRewardOffer.fromJson({'creditsPerView': 2}),
        throwsFormatException,
      );
      expect(
        () => AdRewardSessionStatus.fromJson({'status': '???'}),
        throwsFormatException,
      );
      expect(
        () => AdRewardSession.fromJson({'nonce': ''}),
        throwsFormatException,
      );
    });

    test('경로가 서버 컨트롤러와 같다', () async {
      final adapter = FakeAdapter({
        'GET /api/credits/ad-rewards/offer': {
          'enabled': true,
          'creditsPerView': 2,
          'remainingToday': 5,
        },
        'POST /api/credits/ad-rewards/sessions': {
          'nonce': 'abc',
          'expiresAt': '2026-09-30T15:30:00',
          'creditsPerView': 2,
          'remainingToday': 5,
        },
        'GET /api/credits/ad-rewards/sessions/abc': {
          'status': 'GRANTED',
          'grantedCredits': 2,
        },
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
        ..httpClientAdapter = adapter;
      final repo = AdRewardRepository(dio);

      expect((await repo.getOffer()).enabled, isTrue);
      expect((await repo.createSession()).nonce, 'abc');
      expect((await repo.getStatus('abc')).phase, AdRewardPhase.granted);
      // "봤다"고 알리는 API 는 없다 — 이 셋뿐이다.
      expect(adapter.calls, hasLength(3));
    });
  });
}

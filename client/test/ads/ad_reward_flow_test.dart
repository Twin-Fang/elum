import 'package:elum/core/network/app_failure.dart';
import 'package:elum/features/credit/application/ad_reward_flow.dart';
import 'package:elum/features/credit/domain/ad_reward.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_ad_reward.dart';

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

void main() {

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

    test('광고 SDK 가 예외를 던져도 앱은 안내로 끝난다', () async {
      final result = await _flow(
        FakeAdRewardRepo(statuses: [_granted]),
        FakeRewardedLoader(error: StateError('sdk')),
      ).run();

      expect(result.failure?.code, 'E-AD-LOAD');
    });

  });

  group('세션을 못 만드는 경우 — 광고를 띄우지 않는다', () {

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


  group('서버 계약', () {

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

  });
}

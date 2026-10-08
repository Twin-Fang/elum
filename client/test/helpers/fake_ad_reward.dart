import 'package:dio/dio.dart';
import 'package:elum/features/ads/data/rewarded_ad_loader.dart';
import 'package:elum/features/credit/data/ad_reward_repository.dart';
import 'package:elum/features/credit/domain/ad_reward.dart';

/// 서버가 정한 대로만 답하는 가짜 저장소.
class FakeAdRewardRepo extends AdRewardRepository {
  FakeAdRewardRepo({
    this.offer = const AdRewardOffer(
      enabled: true,
      creditsPerView: 2,
      remainingToday: 5,
    ),
    this.offerError,
    this.sessionError,
    this.statuses = const [],
  }) : super(Dio());

  AdRewardOffer offer;
  Object? offerError;
  Object? sessionError;

  /// 호출 순서대로 돌려줄 상태. 다 쓰면 마지막 것을 계속 준다.
  List<Object> statuses;

  var offerCalls = 0;
  var sessionCalls = 0;
  var statusCalls = 0;

  @override
  Future<AdRewardOffer> getOffer() async {
    offerCalls++;
    if (offerError != null) throw offerError!;
    return offer;
  }

  @override
  Future<AdRewardSession> createSession() async {
    sessionCalls++;
    if (sessionError != null) throw sessionError!;
    return const AdRewardSession(
      nonce: 'N1',
      creditsPerView: 2,
      remainingToday: 5,
    );
  }

  @override
  Future<AdRewardSessionStatus> getStatus(String nonce) async {
    final i = statusCalls < statuses.length ? statusCalls : statuses.length - 1;
    statusCalls++;
    final next = statuses[i];
    if (next is AdRewardSessionStatus) return next;
    throw next;
  }
}

class FakeRewardedLoader implements RewardedAdLoader {
  FakeRewardedLoader({
    this.configured = true,
    this.end = RewardedAdEnd.earned,
    this.error,
  });

  bool configured;
  RewardedAdEnd end;
  Object? error;
  final shownNonces = <String>[];

  @override
  bool get isConfigured => configured;

  @override
  Future<RewardedAdEnd> showFor(String nonce) async {
    shownNonces.add(nonce);
    if (error != null) throw error!;
    return end;
  }
}

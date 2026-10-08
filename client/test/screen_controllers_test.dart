import 'package:dio/dio.dart';
import 'package:elum/features/auth/application/consent_controller.dart';
import 'package:elum/features/auth/application/login_controller.dart';
import 'package:elum/features/auth/application/role_select_controller.dart';
import 'package:elum/features/auth/data/consent_repository.dart';
import 'package:elum/features/child/application/mode_switch_controller.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/guardian/application/draft_routines_controller.dart';
import 'package:elum/features/guardian/application/guardian_home_controller.dart';
import 'package:elum/features/guardian/application/pin_change_controller.dart';
import 'package:elum/features/guardian/application/reward_setup_controller.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/features/link/domain/link_status.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:elum/features/link/application/link_code_controller.dart';
import 'package:elum/features/link/application/link_enter_controller.dart';
import 'package:elum/features/link/data/device_link_repository.dart';
import 'package:elum/features/onboarding/application/name_controller.dart';
import 'package:elum/features/onboarding/application/splash_controller.dart';
import 'package:elum/features/profile/application/guardians_controller.dart';
import 'package:elum/features/profile/application/invite_code_controller.dart';
import 'package:elum/features/profile/application/invite_enter_controller.dart';
import 'package:elum/features/profile/data/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/profile_fixtures.dart';
import 'helpers/test_storage.dart';

/// 화면 컨트롤러가 저장소·저장소 provider 호출을 그대로 넘기는지 확인한다.
void main() {
  ProviderContainer make({
    String? pin,
    bool elumiDevice = false,
    bool onboardingCompleted = false,
    List extra = const [],
  }) {
    final c = ProviderContainer(
      overrides: [testStorageOverride(pin: pin, elumiDevice: elumiDevice, onboardingCompleted: onboardingCompleted), ...extra],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('LoginController: 마지막 제공자와 PIN 유무를 저장소에서 읽는다', () async {
    final noPin = make();
    expect(noPin.read(loginControllerProvider).lastLoginProviderName(), isNull);
    expect(await noPin.read(loginControllerProvider).hasPin(), isFalse);

    final withPin = make(pin: '1234');
    expect(await withPin.read(loginControllerProvider).hasPin(), isTrue);
  });

  test('RoleSelectController: 고른 역할을 저장소에 쓴다', () async {
    final c = make();
    await c.read(roleSelectControllerProvider).selectRole('guardian');
    expect(c.read(localStorageProvider).selectedRole, 'guardian');
  });

  test('ModeSwitchController: PIN 유무·이룸이 휴대폰·PIN 검증을 저장소에 위임한다', () async {
    final c = make(pin: '1234', elumiDevice: true);
    final ctrl = c.read(modeSwitchControllerProvider);
    expect(await ctrl.hasPin(), isTrue);
    expect(ctrl.isElumiDevice, isTrue);
    expect(await ctrl.verifyPin('1234'), isTrue);
    expect(await ctrl.verifyPin('0000'), isFalse);
  });

  test('ConsentController: 켠 항목과 버전을 동의 저장소로 보낸다', () async {
    Map<String, dynamic>? sent;
    final dio = Dio()
      ..interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
        sent = Map<String, dynamic>.from(o.data as Map);
        h.resolve(Response(requestOptions: o, statusCode: 200, data: <String, dynamic>{}));
      }));
    final c = make(extra: [consentRepositoryProvider.overrideWithValue(ConsentRepository(dio: dio))]);

    final failure = await c.read(consentControllerProvider).agree(agreedKeys: {}, version: 'v9');

    expect(failure, isNull);
    expect(sent?['consentVersion'], 'v9');
  });

  test('PinChangeController: PIN 유무·검증·저장을 저장소에 위임한다', () async {
    final c = make(pin: '1234');
    final ctrl = c.read(pinChangeControllerProvider);
    expect(await ctrl.hasPin(), isTrue);
    expect(await ctrl.verifyPin('1234'), isTrue);
    expect(await ctrl.verifyPin('0000'), isFalse);
    await ctrl.setPin('5678');
    expect(await ctrl.verifyPin('5678'), isTrue);
  });

  test('SplashController: 온보딩 완료·이룸이 휴대폰 여부를 저장소에서 읽는다', () {
    final c = make(onboardingCompleted: true, elumiDevice: true);
    final ctrl = c.read(splashControllerProvider);
    expect(ctrl.isOnboardingCompleted, isTrue);
    expect(ctrl.isElumiDevice, isTrue);
  });

  test('NameController: 고른 역할을 지운다', () async {
    final c = make();
    await c.read(roleSelectControllerProvider).selectRole('guardian');
    await c.read(nameControllerProvider).clearSelectedRole();
    expect(c.read(localStorageProvider).selectedRole, isNull);
  });

  test('프로필 컨트롤러 셋: 초대 발급·합류·나가기·내 정보 수정을 저장소로 넘긴다', () async {
    final repo = FakeProfileRepository();
    final c = make(extra: [profileRepositoryProvider.overrideWithValue(repo)]);

    await c.read(inviteCodeControllerProvider).issueInvite('p-1');
    await c.read(inviteEnterControllerProvider).redeemInvite('ABC');
    await c.read(guardiansControllerProvider).leave('p-1');
    await c.read(guardiansControllerProvider).updateMyGuardian('p-1', displayName: '엄마');

    expect(repo.calls, containsAll(['issue:p-1', 'redeem', 'update:p-1']));
    expect(repo.sentCodes, ['ABC']);
    expect(repo.lastUpdate?['displayName'], '엄마');
  });

  test('LinkEnterController·LinkCodeController: 연결 저장소로 넘기고 기준 조회를 함께 시작한다', () async {
    final link = _FakeLink();
    final c = make(extra: [deviceLinkRepositoryProvider.overrideWithValue(link)]);

    expect(c.read(linkEnterControllerProvider).linkWasLost, isFalse);
    await c.read(linkEnterControllerProvider).redeem('CODE');
    expect(link.calls, ['redeem:CODE']);

    link.calls.clear();
    await c.read(linkCodeControllerProvider).issue(withBaseline: true);
    expect(link.calls, ['status', 'issue']);

    link.calls.clear();
    final (_, before) = await c.read(linkCodeControllerProvider).issue(withBaseline: false);
    expect(before, isNull);
    expect(link.calls, ['issue']);
  });

  test('일과 컨트롤러 셋: 정렬·삭제·복제·최근 보상을 일과 저장소로 넘긴다', () async {
    final repo = _RecordingRoutineRepo();
    final c = make(extra: [routineRepositoryProvider.overrideWithValue(repo)]);

    final home = c.read(guardianHomeControllerProvider);
    await home.reorder(['a', 'b']);
    await home.reorderSteps('r', ['s1']);
    await home.delete('r');
    await home.duplicate('r');
    await c.read(draftRoutinesControllerProvider).delete('d');
    await c.read(rewardSetupControllerProvider).recentRewards();

    expect(repo.calls, ['reorder', 'reorderSteps', 'delete', 'duplicate', 'delete', 'getRecentRewards']);
  });
}

class _FakeLink extends DeviceLinkRepository {
  _FakeLink()
      : super(dio: Dio(), tokens: InMemoryTokenStore(), storage: InMemoryStorage());

  final calls = <String>[];

  @override
  Future<RedeemResult> redeem(String code) async {
    calls.add('redeem:$code');
    return const RedeemResult(RedeemOutcome.linked);
  }

  @override
  Future<Attempt<IssuedLinkCode>> issue() async {
    calls.add('issue');
    return Attempt.ok(IssuedLinkCode.fromNow(code: 'A7K3M9', expiresInSeconds: 600));
  }

  @override
  Future<Attempt<LinkStatus>> statusResult() async {
    calls.add('status');
    return const Attempt.ok(LinkStatus(devices: []));
  }
}

/// 부른 메서드 이름만 기록하는 가짜.
class _RecordingRoutineRepo implements RoutineRepository {
  final calls = <String>[];

  @override
  Future<AppFailure?> reorder(List<String> routineIds) async {
    calls.add('reorder');
    return null;
  }

  @override
  Future<AppFailure?> reorderSteps(String routineId, List<String> stepIds) async {
    calls.add('reorderSteps');
    return null;
  }

  @override
  Future<AppFailure?> delete(String routineId) async {
    calls.add('delete');
    return null;
  }

  @override
  Future<Attempt<Routine>> duplicate(String routineId) async {
    calls.add('duplicate');
    return const Attempt.failed(AppFailure(fault: NetworkFault.app));
  }

  @override
  Future<List<RecentReward>> getRecentRewards() async {
    calls.add('getRecentRewards');
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

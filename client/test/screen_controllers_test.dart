import 'package:dio/dio.dart';
import 'package:elum/features/auth/application/consent_controller.dart';
import 'package:elum/features/auth/application/login_controller.dart';
import 'package:elum/features/auth/application/role_select_controller.dart';
import 'package:elum/features/auth/data/consent_repository.dart';
import 'package:elum/features/child/application/mode_switch_controller.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_storage.dart';

/// 화면 컨트롤러가 저장소·저장소 provider 호출을 그대로 넘기는지 확인한다.
void main() {
  ProviderContainer make({String? pin, bool elumiDevice = false, List extra = const []}) {
    final c = ProviderContainer(
      overrides: [testStorageOverride(pin: pin, elumiDevice: elumiDevice), ...extra],
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
}

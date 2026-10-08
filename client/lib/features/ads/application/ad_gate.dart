import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../member/data/member_repository.dart';
import '../../member/application/member_providers.dart';

/// 광고를 띄울 수 있는 환경인가.
///
/// 모바일이고, 계정 요금제가 광고를 없애지 않을 때만 켜진다(서버 `ADS_REMOVED` ·
/// Free 는 `FREE_ADS_REMOVED`, Pro 는 `PRO_ADS_REMOVED`). 호스트(macOS) 위젯 테스트는
/// 모바일이 아니라 자동으로 꺼져 SDK 와 회원 조회를 건드리지 않는다.
final adsEnabledProvider = Provider<bool>((ref) {
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return false;
  return adsAllowedFor(ref.watch(memberProvider));
});

/// 회원 조회 결과로 광고 허용 여부를 정한다.
///
/// **모르면 띄우지 않는다.** 조회 중이거나 실패(null)했을 때 광고를 먼저 요청하면 광고를
/// 없애 준 Pro 계정이 첫 화면에서 잠깐 광고를 본다. 광고 요청은 요금제를 확인한 뒤에만 한다.
bool adsAllowedFor(AsyncValue<Member?> member) => member.maybeWhen(
  data: (m) => m != null && !m.adsRemoved,
  orElse: () => false,
);

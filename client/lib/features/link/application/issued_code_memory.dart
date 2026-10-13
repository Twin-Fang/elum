import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/link_status.dart';

/// 이 앱 세션에서 발급받은 코드를 **메모리에만** 기억한다 (초대 코드·연결 암호 공통).
///
/// 서버는 코드를 해시로만 저장해 원문을 돌려줄 수 없다. 화면을 나갔다 들어올 때마다 새로 발급하면
/// 앞 코드가 폐기돼, 코드를 전하는 동안 화면을 계속 띄워 둬야 한다. 그래서 받은 원문과 만료를 여기 두었다가
/// 다시 들어오면 서버에 아직 살아 있는지만 묻고 그대로 보여 준다.
///
/// 디스크에는 쓰지 않는다 — 10분짜리 자격증명이라 앱이 죽으면 새로 받는 쪽이 싸고 안전하다.
class IssuedCodeMemory {
  final Map<String, IssuedLinkCode> _byKey = {};

  static String inviteKey(String profileId) => 'invite:$profileId';
  static String linkKey(String? profileId) => 'link:${profileId ?? ''}';

  void remember(String key, IssuedLinkCode code) => _byKey[key] = code;

  void forget(String key) => _byKey.remove(key);

  /// 기억한 코드 중 만료 전인 것. 만료됐으면 버리고 null.
  IssuedLinkCode? recall(String key) {
    final code = _byKey[key];
    if (code == null) return null;
    if (code.isExpired) {
      _byKey.remove(key);
      return null;
    }
    return code;
  }

  /// 기억한 코드가 서버에서도 아직 살아 있으면 돌려준다.
  ///
  /// [serverPendingExpiry] 는 서버가 아는 내 미사용 코드의 만료 시각을 묻는다(없으면 null, 확인에 실패하면 던진다).
  /// 만료 시각이 초 단위로 같을 때만 같은 코드로 본다. 확인에 실패하거나 어긋나면 null 이고,
  /// 부른 쪽이 새로 발급한다 — 못 믿는 코드를 보여 주는 것보다 새 코드가 낫다.
  Future<IssuedLinkCode?> recallLive(
    String key,
    Future<DateTime?> Function() serverPendingExpiry,
  ) async {
    final remembered = recall(key);
    final expected = remembered?.serverExpiresAt;
    if (remembered == null || expected == null) return null;
    try {
      final actual = await serverPendingExpiry();
      if (actual != null && _sameSecond(expected, actual)) return recall(key);
    } catch (_) {
      // 확인 실패는 새로 발급으로 이어진다.
    }
    forget(key);
    return null;
  }

  static bool _sameSecond(DateTime a, DateTime b) =>
      a.millisecondsSinceEpoch ~/ 1000 == b.millisecondsSinceEpoch ~/ 1000;
}

final issuedCodeMemoryProvider = Provider<IssuedCodeMemory>((ref) => IssuedCodeMemory());

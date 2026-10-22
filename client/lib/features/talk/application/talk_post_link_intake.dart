import '../../../core/router/routes.dart';
import '../domain/talk_post_link.dart';

/// 열린 이야기 글 링크를 알맞은 때에 글 상세로 이어 주는 판단: 받을지 > 맡겨 두기 > 열 자리에서 열기
///
/// | 상황 | 동작 |
/// | --- | --- |
/// | 이룸이 기기 | 맡기지 않고 안내만 (이룸이 화면에는 이야기가 없다) |
/// | 로그인 전·온보딩 중 | 맡겨 둔다 > 보호자 홈에 닿으면 연다 |
/// | 보호자 홈 · 이야기 칸 · 이야기 상세 | 바로 연다 |
/// | 그 밖의 화면(일과 만들기·설정 등) | 하던 일을 끊지 않는다. 위 자리에 돌아오면 연다 |
///
/// 맡긴 링크는 [_pendingValidity] 가 지나면 버린다 — 한참 뒤 엉뚱한 때에 글이 열리지 않게.
class TalkPostLinkIntake {
  TalkPostLinkIntake({
    required this.isElumiDevice,
    required this.hasSession,
    required this.topLocation,
    required this.open,
    this.onElumiDeviceRejected,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final bool Function() isElumiDevice;
  final bool Function() hasSession;

  /// 지금 맨 위에 보이는 화면의 경로 (위에 쌓은 화면까지 센다). 모르면 null
  final String? Function() topLocation;

  /// 글 상세를 연다 (보던 화면 위에 얹는다)
  final void Function(String postId) open;

  /// 이룸이 기기에서 열린 링크를 받지 않았을 때 — 이유를 알린다
  final void Function()? onElumiDeviceRejected;

  final DateTime Function() _now;

  /// 맡긴 링크 유효 시간 (10분, 초대 링크와 같은 길이)
  static const _pendingValidity = Duration(minutes: 10);

  /// 글 상세를 얹어도 되는 자리: 보호자 홈, 이야기 칸, 다른 이야기 글 상세
  static bool isReadyLocation(String? location) =>
      location == Routes.guardian ||
      location == Routes.guardianTalk ||
      (location != null &&
          location.startsWith('${Routes.guardianTalk}/posts/'));

  String? _pendingPostId;
  DateTime? _receivedAt;

  /// 링크가 열렸다
  void accept(TalkPostLink link) {
    if (isElumiDevice()) {
      onElumiDeviceRejected?.call();
      return;
    }
    _pendingPostId = link.postId;
    _receivedAt = _now();
    tryOpen();
  }

  /// 맡긴 링크가 있고 열어도 되는 자리면 글 상세를 연다. 열었으면 true
  bool tryOpen() {
    final postId = _pendingPostId;
    final receivedAt = _receivedAt;
    if (postId == null || receivedAt == null) return false;
    // 기다리는 사이 이룸이 기기가 됐거나(연결) 오래됐으면 버림
    if (isElumiDevice() || _now().difference(receivedAt) > _pendingValidity) {
      _clear();
      return false;
    }
    if (!hasSession()) return false;
    if (!isReadyLocation(topLocation())) return false;
    // 먼저 비워서 화면 이동 알림이 같은 글을 두 번 열지 않게 함
    _clear();
    open(postId);
    return true;
  }

  void _clear() {
    _pendingPostId = null;
    _receivedAt = null;
  }
}

import 'package:flutter/widgets.dart';

/// 누르면 서버로 가는 동작의 진행 중 잠금.
///
/// 응답을 기다리는 동안 버튼이 그대로면 보호자는 반응이 없는 줄 알고 다시 누른다.
/// 그러면 같은 요청이 두 번 가서, 이미 끝난 일을 서버가 거절해 실패 팝업이 뜬다.
/// 화면마다 플래그를 따로 두면 빠지는 곳이 생기므로 이 장치 하나로 잠근다.
///
/// - key 없이 부르면 화면 전체를 잠근다. 진행 중엔 무엇도 새로 시작하지 않는다.
/// - key 를 주면 그 항목만 잠근다(목록에서 지우는 중인 타일). 다른 항목은 계속 누를 수 있다.
/// - 끝나면(성공·실패 모두) 푼다. 에러는 삼키지 않고 그대로 던져 화면의 실패 처리가 받는다.
///
/// 화면은 [busy]·[isBusy] 로 버튼에 진행 중 표시를 건다 (`ElumButton(loading:)`).
mixin BusyStateMixin<T extends StatefulWidget> on State<T> {
  static const Object _screen = Object();
  final Set<Object> _busyKeys = {};

  /// 화면이든 항목이든 무엇이 진행 중이다.
  bool get busy => _busyKeys.isNotEmpty;

  bool isBusy(Object key) => _busyKeys.contains(key);

  /// 진행 중이라 실행하지 않았으면 null 을 돌려준다.
  Future<R?> runBusy<R>(Future<R> Function() task, {Object? key}) async {
    final k = key ?? _screen;
    final blocked =
        _busyKeys.contains(_screen) ||
        _busyKeys.contains(k) ||
        (k == _screen && busy);
    if (blocked || !mounted) return null;

    setState(() => _busyKeys.add(k));
    try {
      return await task();
    } finally {
      // 성공 뒤 화면을 떠났으면 그리지 않고 표시만 지운다.
      if (mounted) {
        setState(() => _busyKeys.remove(k));
      } else {
        _busyKeys.remove(k);
      }
    }
  }
}

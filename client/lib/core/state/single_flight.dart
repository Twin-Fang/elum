/// 같은 작업이 진행 중이면 새로 시작하지 않고 진행 중인 결과를 함께 받는다.
///
/// 화면의 버튼 잠금([BusyStateMixin])이 뚫려도(연타, 같은 notifier 를 부르는 다른 화면)
/// 서버로는 한 번만 간다. 끝나면(성공·실패 모두) 비워서 다음 호출은 새로 실행한다.
///
/// 성공한 뒤에도 다시 실행하면 안 되는 작업(AI 생성처럼 비용이 드는 것)은 이 장치가 아니라
/// 호출하는 쪽이 결과를 따로 붙잡는다.
class SingleFlight<T> {
  Future<T>? _running;

  bool get running => _running != null;

  Future<T> run(Future<T> Function() task) {
    final running = _running;
    if (running != null) return running;

    // 작업이 곧바로 던져도 Future 에러로 받아 호출하는 쪽의 실패 처리 한 곳으로 모은다.
    final future = Future<T>.sync(task);
    _running = future;
    // 비우기만 한다. 에러는 호출한 쪽이 받으므로 이 사슬의 에러는 버린다.
    future.whenComplete(() {
      if (identical(_running, future)) _running = null;
    }).ignore();
    return future;
  }
}

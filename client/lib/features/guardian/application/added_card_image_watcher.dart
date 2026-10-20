import 'dart:async';

/// 직접 추가한 카드의 그림 기다리기: 주기 확인 > 그림 오면 반영 > 시간 넘으면 포기 (#868)
/// 서버가 그림을 커밋 뒤 따로 그려(수 초~수십 초) 카드 추가 응답에는 그림이 없음
class AddedCardImageWatcher {
  AddedCardImageWatcher({
    required this.fetchImagePath,
    required this.onImageReady,
    required this.onGaveUp,
  });

  // 확인 간격 — 서버 부담과 기다리는 체감 사이
  static const checkInterval = Duration(seconds: 3);
  // 이 시간 안에 안 오면 그림 실패로 봄 (서버는 실패 시 그림 기호로 남김)
  static const maximumWait = Duration(seconds: 90);

  final Future<String?> Function(String stepId) fetchImagePath;
  final void Function(String stepId, String imagePath) onImageReady;
  final void Function(String stepId) onGaveUp;

  final _waitingStepIds = <String>{};
  var _isDisposed = false;

  /// 그림을 기다리는 카드인가 (카드에 "그림을 만들고 있어요" 표시)
  bool isWaiting(String stepId) => _waitingStepIds.contains(stepId);

  void watch(String stepId) {
    if (_isDisposed || !_waitingStepIds.add(stepId)) return;
    unawaited(_waitForImage(stepId));
  }

  /// 화면을 떠나면 확인 중단 (그림은 서버에 남아 다음에 열 때 보임)
  void dispose() {
    _isDisposed = true;
    _waitingStepIds.clear();
  }

  // 한 번에 하나씩 확인 (응답이 늦어도 요청이 겹치지 않게)
  Future<void> _waitForImage(String stepId) async {
    final deadline = DateTime.now().add(maximumWait);
    while (true) {
      await Future<void>.delayed(checkInterval);
      if (_isDisposed || !_waitingStepIds.contains(stepId)) return;

      final imagePath = await fetchImagePath(stepId);
      if (_isDisposed) return;
      if (imagePath != null) {
        _waitingStepIds.remove(stepId);
        onImageReady(stepId, imagePath);
        return;
      }
      if (DateTime.now().isAfter(deadline)) {
        _waitingStepIds.remove(stepId);
        onGaveUp(stepId);
        return;
      }
    }
  }
}

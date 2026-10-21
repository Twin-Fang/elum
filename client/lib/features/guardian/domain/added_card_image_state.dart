/// 직접 추가한 카드의 그림 상태 (#868)
/// 서버 응답 `imageSkippedReason` > 화면이 할 일(그림 기다리기, 안내 토스트, 아무것도 안 함)
enum AddedCardImageState {
  /// 서버가 커밋 뒤 그림을 그리는 중 > 카드에 "그림을 만들고 있어요"
  generating,

  /// 그림 방식이 기본 그림 > 그림 기호만 (안내 없음)
  basicPictogramStyle,

  /// 크레딧 부족 > 그림 기호로 대신하고 안내
  creditInsufficient,

  /// 크레딧 계정 정지 등 그 밖의 까닭 > 그림 기호로 대신하고 안내
  unavailable,

  /// 설명이 비어 서버가 그림을 건너뜀 > 그림 기호만 (안내 없음)
  notRequested;

  // 서버 RoutineStepEditService.IMAGE_SKIPPED_PHOTO_ONLY 와 같은 값
  static const _skippedPhotoOnly = 'IMAGE_STYLE_PHOTO_ONLY';
  // 서버 ErrorCode.AI_CREDIT_INSUFFICIENT
  static const _skippedCreditInsufficient = 'AI_CREDIT_INSUFFICIENT';

  /// 서버 응답 > 그림 상태 (설명이 비면 서버가 까닭 없이 건너뜀)
  static AddedCardImageState fromAddResponse({
    required String? imageSkippedReason,
    required String description,
  }) {
    if (imageSkippedReason == null) {
      return description.trim().isEmpty ? notRequested : generating;
    }
    return switch (imageSkippedReason) {
      _skippedPhotoOnly => basicPictogramStyle,
      _skippedCreditInsufficient => creditInsufficient,
      _ => unavailable,
    };
  }
}

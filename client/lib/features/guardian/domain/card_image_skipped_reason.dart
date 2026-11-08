/// 서버 응답 `imageSkippedReason` 값 원본: 카드 추가·일과 만들기 공통 (#1178)
/// 응답 값 > 문자열만 받기 > 화면 판정 (모르는 값은 각 판정이 정함)
abstract final class CardImageSkippedReason {
  // 서버 RoutineStepEditService.IMAGE_SKIPPED_PHOTO_ONLY (그림 방식이 그림 기호·이모지)
  static const photoOnly = 'IMAGE_STYLE_PHOTO_ONLY';
  // 서버 ErrorCode.AI_CREDIT_INSUFFICIENT
  static const creditInsufficient = 'AI_CREDIT_INSUFFICIENT';
  // 서버 RoutineStepEditService.IMAGE_SKIPPED_PLAN (요금제에 AI 맞춤 그림 없음 > 픽토그램, 안내 없음)
  static const planWithoutAiPicture = 'AI_IMAGE_NOT_ALLOWED';
  // 서버 RoutineCreateService.IMAGE_SKIPPED_FAILED (일과 만들기: AI 그림 일부를 못 그려 픽토그램, #1172)
  static const aiImageFailed = 'AI_IMAGE_FAILED';

  /// 응답 본문 값 > 까닭 문자열 (필드 없음·null·문자열 아님 > null)
  static String? readFromResponse(Object? responseValue) =>
      responseValue is String ? responseValue : null;

  /// 일과 만들기 응답 > AI 그림을 못 그린 카드가 있는가 (그 밖의 값·null 은 안내 없음)
  static bool hasCreatedRoutineMissingAiImage(String? imageSkippedReason) =>
      imageSkippedReason == aiImageFailed;
}

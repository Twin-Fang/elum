import 'package:flutter/foundation.dart';

/// 서버 권한 묶음 한 벌 (`MemberResponse.entitlements`): Pro 판정 + Pro 기능별 사용 가능 여부
///
/// 새 Pro 기능 = 이 파일 5곳(생성자·필드·[pro]·[PlanEntitlements.fromJson]·`_values`) + `PlanAccess` 전달 getter 1곳.
/// 모르는 값·빠진 필드는 전부 false (Free 쪽으로 기움). 출처: server/.../license/application/service/EntitlementSnapshot.java
@immutable
class PlanEntitlements {
  const PlanEntitlements({
    this.isPro = false,
    this.isAdsRemoved = false,
    this.canExportCardsWithoutWatermark = false,
    this.canUseAllCardDesignThemes = false,
    this.canUseAllCardExportLayouts = false,
    this.canViewWeeklyReport = false,
    this.canScheduleRoutines = false,
    this.canUseGuardianVoice = false,
    this.canUseRoutineMemory = false,
    this.canSplitCards = false,
    this.canRegenerateImagesFree = false,
    this.canCreateRoutineTextFree = false,
    this.canUseAiPictures = false,
  });

  /// 모르거나 Free 일 때 (워터마크 넣음 · 기본 테마만 · Pro 기능 전부 꺼짐)
  static const free = PlanEntitlements();

  /// 개발자 도구 `Pro 처럼`
  static const pro = PlanEntitlements(
    isPro: true,
    isAdsRemoved: true,
    canExportCardsWithoutWatermark: true,
    canUseAllCardDesignThemes: true,
    canUseAllCardExportLayouts: true,
    canViewWeeklyReport: true,
    canScheduleRoutines: true,
    canUseGuardianVoice: true,
    canUseRoutineMemory: true,
    canSplitCards: true,
    canRegenerateImagesFree: true,
    canCreateRoutineTextFree: true,
    canUseAiPictures: true,
  );

  /// 서버가 본 요금제가 Pro 인가 (`plan == 'PRO'`)
  final bool isPro;

  /// 요금제가 광고를 없애는가 (`adsRemoved` · 요금제별 `*_ADS_REMOVED`). 광고 게이트가 회원 값으로 직접 봄 (개발자 도구 흉내와 무관)
  final bool isAdsRemoved;

  /// 카드 내보내기에서 로고·워터마크를 뺄 수 있는가 (`cardExportWithoutWatermark`)
  final bool canExportCardsWithoutWatermark;

  /// 카드 내보내기에서 기본 말고 다른 디자인 테마를 고를 수 있는가 (`cardExportAllThemes`)
  final bool canUseAllCardDesignThemes;

  /// 카드 내보내기에서 카드 한 장씩 말고 일과 한 장 · 오려 쓰는 카드와 용지 방향 · 장수 · 카드 크기를 고를 수 있는가 (`cardExportAllLayouts`)
  final bool canUseAllCardExportLayouts;

  /// 주간 리포트를 볼 수 있는가 (`weeklyReport`)
  final bool canViewWeeklyReport;

  /// 일과에 요일·시각을 정할 수 있는가 (`routineSchedule`: 반복 일과 · 주간 계획 · 이룸이 기기 알림, #782 · #1080)
  final bool canScheduleRoutines;

  /// 카드마다 보호자 목소리를 녹음할 수 있는가 (`guardianVoice`). 꺼져도 이미 한 녹음은 남고 이룸이는 기본 음성으로 듣는다
  final bool canUseGuardianVoice;

  /// 이룸이별 AI 메모(내가 고친 일과처럼 만들기)를 쓸 수 있는가 (`routineMemory`)
  final bool canUseRoutineMemory;

  /// 카드 한 장을 AI 가 2~3장으로 나눈 안을 받을 수 있는가 (`cardSplit`, 크레딧은 쓰지 않음)
  final bool canSplitCards;

  /// 카드 그림 다시 그리기가 크레딧 없이 되는가 (`imageRegenerateFree`, 하루 한도를 넘으면 서버가 원래 단가로 받음)
  final bool canRegenerateImagesFree;

  /// AI 일과 만들기의 글 몫이 크레딧 없이 되는가 (`routineCreateFree`, 카드 그림은 장수만큼 듦, 하루 횟수는 서버가 봄)
  final bool canCreateRoutineTextFree;

  /// AI 맞춤 그림을 쓸 수 있는가 (`aiImageGeneration`): 새 카드 그림·다시 그리기·그림 그리기
  /// 꺼져도 이미 만든 AI 그림은 그대로 보인다 (그림 조회는 요금제와 무관)
  final bool canUseAiPictures;

  /// `entitlements` 객체 > 권한 묶음. 필드가 비거나 모양이 달라도 예외 없이 false
  factory PlanEntitlements.fromJson(Object? entitlementsJson) {
    if (entitlementsJson is! Map<dynamic, dynamic>) return free;
    bool isEntitled(String key) => entitlementsJson[key] == true;
    return PlanEntitlements(
      isPro: entitlementsJson['plan'] == 'PRO',
      isAdsRemoved: isEntitled('adsRemoved'),
      canExportCardsWithoutWatermark: isEntitled('cardExportWithoutWatermark'),
      canUseAllCardDesignThemes: isEntitled('cardExportAllThemes'),
      canUseAllCardExportLayouts: isEntitled('cardExportAllLayouts'),
      canViewWeeklyReport: isEntitled('weeklyReport'),
      canScheduleRoutines: isEntitled('routineSchedule'),
      canUseGuardianVoice: isEntitled('guardianVoice'),
      canUseRoutineMemory: isEntitled('routineMemory'),
      canSplitCards: isEntitled('cardSplit'),
      canRegenerateImagesFree: isEntitled('imageRegenerateFree'),
      canCreateRoutineTextFree: isEntitled('routineCreateFree'),
      canUseAiPictures: isEntitled('aiImageGeneration'),
    );
  }

  /// 비교·해시 원본 (필드를 더하면 여기에도 한 줄)
  List<bool> get _values => [
    isPro,
    isAdsRemoved,
    canExportCardsWithoutWatermark,
    canUseAllCardDesignThemes,
    canUseAllCardExportLayouts,
    canViewWeeklyReport,
    canScheduleRoutines,
    canUseGuardianVoice,
    canUseRoutineMemory,
    canSplitCards,
    canRegenerateImagesFree,
    canCreateRoutineTextFree,
    canUseAiPictures,
  ];

  @override
  bool operator ==(Object other) =>
      other is PlanEntitlements && listEquals(_values, other._values);

  @override
  int get hashCode => Object.hashAll(_values);
}

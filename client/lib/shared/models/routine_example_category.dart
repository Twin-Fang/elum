import '../../core/l10n/current_l10n.dart';

/// 온보딩 예시 일과 분류 4개 (#803). 고른 분류마다 서버가 예시 일과 2개를 넣는다.
///
/// [apiValue] 는 서버 `RoutineExampleCategory` enum name 과 같아야 한다 — 어긋나면 온보딩 저장에서 그 분류만 빠진다 (서버 CrossStackContractTest 가 대조).
enum RoutineExampleCategory {
  morningEvening('MORNING_EVENING', 'brush_teeth_,_to'),
  schoolStudy('SCHOOL_STUDY', 'school_bag'),
  houseSelf('HOUSE_SELF', 'tidy_up_,_to'),
  outside('OUTSIDE', 'get_on_bus_,_to');

  const RoutineExampleCategory(this.apiValue, this.pictogramId);

  /// 서버 전송용 값
  final String apiValue;

  /// 선택 카드 아이콘 (assets/pictograms 의 id)
  final String pictogramId;

  /// 분류 이름. 호출 시점의 언어로 읽는다.
  String get label => switch (this) {
    RoutineExampleCategory.morningEvening =>
      appL10n.exampleCategoryMorningEvening,
    RoutineExampleCategory.schoolStudy => appL10n.exampleCategorySchoolStudy,
    RoutineExampleCategory.houseSelf => appL10n.exampleCategoryHouseSelf,
    RoutineExampleCategory.outside => appL10n.exampleCategoryOutside,
  };

  /// 분류 아래 한 줄 예
  String get hint => switch (this) {
    RoutineExampleCategory.morningEvening =>
      appL10n.exampleCategoryMorningEveningHint,
    RoutineExampleCategory.schoolStudy =>
      appL10n.exampleCategorySchoolStudyHint,
    RoutineExampleCategory.houseSelf => appL10n.exampleCategoryHouseSelfHint,
    RoutineExampleCategory.outside => appL10n.exampleCategoryOutsideHint,
  };

  /// 저장소·서버 문자열 > 분류. 모르는 값·null 이면 null
  static RoutineExampleCategory? fromApiValue(String? value) {
    for (final category in values) {
      if (category.apiValue == value) return category;
    }
    return null;
  }
}

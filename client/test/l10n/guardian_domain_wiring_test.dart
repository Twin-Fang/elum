import 'package:elum/core/l10n/current_l10n.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/network/server_error.dart';
import 'package:elum/core/network/server_error_code.dart';
import 'package:elum/features/guardian/data/card_photo.dart';
import 'package:elum/features/guardian/domain/routine_stage.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/l10n/app_localizations_ko.dart';
import 'package:flutter_test/flutter_test.dart';

/// 각 문구가 서로 다른 ARB 키에서 읽히는지 가리는 가짜 번역 — 키마다 표식을 단다.
class _Marked extends AppLocalizationsKo {
  @override
  String get cardPhotoTooLarge => 'M-TOOLARGE';
  @override
  String get cardPhotoWrongType => 'M-WRONGTYPE';
  @override
  String get cardPhotoUnreadable => 'M-UNREADABLE';
  @override
  String get cardPhotoPickFailed => 'M-PICK';
  @override
  String get commonRetryLater => 'M-RETRYLATER';
  @override
  String get routineLoadingPrepareTitle => 'M-PREPARE-TITLE';
  @override
  String get routineLoadingGenerateTitle => 'M-GENERATE-TITLE';
  @override
  String get routineStageReviewSituation => 'M-S1';
  @override
  String get routineStageTidyEssentials => 'M-S2';
  @override
  String get routineStageThinkQuestions => 'M-S3';
  @override
  String get routineStageReadRoutine => 'M-S4';
  @override
  String get routineStageFindItems => 'M-S5';
  @override
  String get routineStageOrderSteps => 'M-S6';
  @override
  String get suggestionRainyText => 'M-RAINY-T';
  @override
  String get suggestionRainyPrompt => 'M-RAINY-P';
  @override
  String get suggestionHospitalText => 'M-HOSP-T';
  @override
  String get suggestionHospitalPrompt => 'M-HOSP-P';
  @override
  String get suggestionTripText => 'M-TRIP-T';
  @override
  String get suggestionTripPrompt => 'M-TRIP-P';
  @override
  String get suggestionNewPlaceText => 'M-NEW-T';
  @override
  String get suggestionNewPlacePrompt => 'M-NEW-P';
  @override
  String get suggestionAfterSchoolText => 'M-AFTER-T';
  @override
  String get suggestionAfterSchoolPrompt => 'M-AFTER-P';
}

void main() {
  // 전역 문구 통로를 바꾸는 테스트라 끝에 ko 로 되돌린다.
  tearDown(setAppL10nForTest);

  test('사진 실패 문구는 각자 자기 키를 읽는다', () {
    setAppL10nForTest(_Marked());
    expect(PhotoFailure.size.message, 'M-TOOLARGE');
    expect(PhotoFailure.type.message, 'M-WRONGTYPE');
    expect(PhotoFailure.unreadable.message, 'M-UNREADABLE');
    expect(PhotoFailure.pick.message, 'M-PICK');
  });

  test('사진 실패 문구는 읽을 때 풀린다 — 만든 뒤 언어가 바뀌어도 따라간다', () {
    const failure = PhotoFailure.size;
    expect(failure.message, '사진이 너무 커요. 다른 사진을 골라 주세요');
    setAppL10nForTest(_Marked());
    expect(failure.message, 'M-TOOLARGE');
  });

  test('PhotoFailure.from — 서버 문구 > hint > 기본 문구 순서', () {
    setAppL10nForTest(_Marked());
    expect(
      PhotoFailure.from(const AppFailure(fault: NetworkFault.none)).message,
      'M-RETRYLATER',
    );
    expect(
      PhotoFailure.from(
        const AppFailure(
          fault: NetworkFault.none,
          server: ServerError(
            code: ServerErrorCode.invalidInputValue,
            message: '서버 문구',
            statusCode: 400,
          ),
        ),
      ).message,
      '서버 문구',
    );
  });

  test('로딩 제목과 체크리스트는 각자 자기 키를 읽는다', () {
    setAppL10nForTest(_Marked());
    expect(RoutineLoadingKind.prepare.title, 'M-PREPARE-TITLE');
    expect(RoutineLoadingKind.generate.title, 'M-GENERATE-TITLE');
    expect(RoutineLoadingKind.prepare.stages.map((s) => s.label).toList(), [
      'M-S1',
      'M-S2',
      'M-S3',
    ]);
    expect(RoutineLoadingKind.generate.stages.map((s) => s.label).toList(), [
      'M-S4',
      'M-S5',
      'M-S6',
    ]);
  });

  test('추천 대체 목록은 부를 때마다 앱 언어로 만든다', () {
    expect(RoutineSuggestion.fallback.first.text, '비 오는 날 등교');
    setAppL10nForTest(_Marked());
    final f = RoutineSuggestion.fallback;
    expect(f.map((s) => s.text).toList(), [
      'M-RAINY-T',
      'M-HOSP-T',
      'M-TRIP-T',
      'M-NEW-T',
      'M-AFTER-T',
    ]);
    expect(f.map((s) => s.prompt).toList(), [
      'M-RAINY-P',
      'M-HOSP-P',
      'M-TRIP-P',
      'M-NEW-P',
      'M-AFTER-P',
    ]);
  });
}

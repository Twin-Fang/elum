import 'package:elum/core/network/app_failure.dart';
import 'package:elum/features/guardian/data/card_photo.dart';
import 'package:elum/features/guardian/domain/routine_stage.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';

/// const 데이터의 한글을 열쇠로 바꿨어도 읽는 쪽 결과가 옛 문구와 같다.
void main() {
  test('사진 실패 문구 — const 인스턴스가 읽을 때 푼다', () {
    expect(PhotoFailure.size.message, '사진이 너무 커요. 다른 사진을 골라 주세요');
    expect(PhotoFailure.type.message, 'JPG나 PNG 사진만 올릴 수 있어요');
    expect(PhotoFailure.unreadable.message, '사진을 읽지 못했어요. 다른 사진을 골라 주세요');
    expect(PhotoFailure.pick.message, '사진을 가져오지 못했어요. 다시 해주세요');
    expect(PhotoFailure.size.code, 'E-PHOTO-SIZE');
  });

  test('로딩 화면 제목과 체크리스트', () {
    expect(RoutineLoadingKind.prepare.title, '루미가 내용을\n정리하고 있어요');
    expect(RoutineLoadingKind.generate.title, '루미가 행동카드를\n만들고 있어요');
    expect(RoutineLoadingKind.prepare.stages.map((s) => s.label).toList(), [
      '적어 주신 상황을 살펴보고 있어요',
      '꼭 필요한 내용만 정리해요',
      '추가 질문을 생각하고 있어요',
    ]);
    expect(RoutineLoadingKind.generate.stages.map((s) => s.label).toList(), [
      '오늘의 일과를 읽고 있어요',
      '중요한 준비물을 찾고 있어요',
      '순서를 정리하고 있어요',
    ]);
    expect(RoutineLoadingKind.prepare.stages.map((s) => s.percent).toList(), [
      15,
      40,
      65,
    ]);
  });

  test('서버가 죽었을 때의 추천 대체 목록 다섯', () {
    final fallback = RoutineSuggestion.fallback;
    expect(fallback.map((s) => s.text).toList(), [
      '비 오는 날 등교',
      '병원 방문 준비',
      '체험학습 준비',
      '새로운 장소 방문',
      '여름방학 방과후 수업 준비',
    ]);
    expect(fallback.first.icon, '☔️');
    expect(fallback.first.prompt, '비 오는 날 우산 챙겨서 학교 가는 준비를 하고 싶어요');
    expect(fallback[1].prompt, '이룸이와 함께 병원에 가야 하는데 무서워하지 않게 준비하고 싶어요');
  });

  test('추천 대체 목록의 입력창 문장 다섯 모두', () {
    expect(RoutineSuggestion.fallback.map((s) => s.prompt).toList(), [
      '비 오는 날 우산 챙겨서 학교 가는 준비를 하고 싶어요',
      '이룸이와 함께 병원에 가야 하는데 무서워하지 않게 준비하고 싶어요',
      '체험학습 가는 날 아침에 챙길 것들을 순서대로 알려주고 싶어요',
      '처음 가보는 장소에 가기 전에 이룸이가 마음의 준비를 하게 돕고 싶어요',
      '방학 중 방과후 수업에 갈 준비를 순서대로 알려주고 싶어요',
    ]);
  });

  test('서버 문구도 hint 도 없으면 기본 문구', () {
    final failure = PhotoFailure.from(
      const AppFailure(fault: NetworkFault.none),
    );
    expect(failure.message, '잠시 후 다시 해주세요');
    expect(failure.code, 'E-PHOTO');
  });
}

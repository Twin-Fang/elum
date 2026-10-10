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

  test('로딩 단계 진행률 순서', () {
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

  test('서버 문구도 hint 도 없으면 기본 문구', () {
    final failure = PhotoFailure.from(
      const AppFailure(fault: NetworkFault.none),
    );
    expect(failure.message, '잠시 후 다시 해주세요');
    expect(failure.code, 'E-PHOTO');
  });
}

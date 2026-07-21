package com.chuseok22.elumserver.routine.infrastructure.constant;

import com.chuseok22.elumserver.routine.application.dto.response.RoutineSuggestionResponse;
import java.util.List;

// 홈 화면 "추천 일과" 카드에 무작위로 노출할 하드코딩 데이터.
// DB에 저장하지 않는 정적 데이터라 엔티티/리포지토리를 두지 않는다.
public final class RoutineSuggestionCatalog {

  public static final List<RoutineSuggestionResponse> ALL = List.of(
    new RoutineSuggestionResponse("☂️", "비 오는 날 등교 준비"),
    new RoutineSuggestionResponse("🎒", "아침 등교 준비"),
    new RoutineSuggestionResponse("🚌", "스쿨버스 타기 준비"),
    new RoutineSuggestionResponse("🏫", "학교 처음 가는 날"),
    new RoutineSuggestionResponse("🔔", "하교 후 집에 오기"),
    new RoutineSuggestionResponse("🚗", "차 타고 이동하기"),
    new RoutineSuggestionResponse("🚶", "혼자 걷기 연습"),
    new RoutineSuggestionResponse("🚏", "버스정류장 기다리기"),
    new RoutineSuggestionResponse("🧥", "외출 전 옷 챙겨입기"),
    new RoutineSuggestionResponse("🛍️", "마트 다녀오기"),
    new RoutineSuggestionResponse("🏥", "병원 방문 준비"),
    new RoutineSuggestionResponse("💉", "예방접종 하러 가기"),
    new RoutineSuggestionResponse("🦷", "치과 진료 준비"),
    new RoutineSuggestionResponse("🩺", "건강검진 받기"),
    new RoutineSuggestionResponse("💊", "약 챙겨 먹기"),
    new RoutineSuggestionResponse("🪥", "양치질 하기"),
    new RoutineSuggestionResponse("🛁", "목욕하기"),
    new RoutineSuggestionResponse("🧴", "손 씻기 연습"),
    new RoutineSuggestionResponse("✂️", "머리 자르러 가기"),
    new RoutineSuggestionResponse("👕", "혼자 옷 갈아입기"),
    new RoutineSuggestionResponse("🍱", "체험학습 준비"),
    new RoutineSuggestionResponse("🍽️", "저녁 식사 준비"),
    new RoutineSuggestionResponse("🥄", "혼자 밥 먹기 연습"),
    new RoutineSuggestionResponse("🍎", "간식 시간 갖기"),
    new RoutineSuggestionResponse("🥤", "물 마시는 습관 들이기"),
    new RoutineSuggestionResponse("🌙", "잠자리 준비하기"),
    new RoutineSuggestionResponse("🛏️", "혼자 잠들기 연습"),
    new RoutineSuggestionResponse("⏰", "아침에 일어나기"),
    new RoutineSuggestionResponse("🧸", "자기 전 정리 정돈"),
    new RoutineSuggestionResponse("😴", "낮잠 준비하기"),
    new RoutineSuggestionResponse("🧭", "새로운 장소 방문"),
    new RoutineSuggestionResponse("🏛️", "박물관 다녀오기"),
    new RoutineSuggestionResponse("🎪", "낯선 행사 참여하기"),
    new RoutineSuggestionResponse("🏖️", "처음 가는 여행지 적응"),
    new RoutineSuggestionResponse("🧑‍🏫", "새로운 선생님 만나기"),
    new RoutineSuggestionResponse("🧩", "친구와 놀이하기"),
    new RoutineSuggestionResponse("⚽", "놀이터에서 놀기"),
    new RoutineSuggestionResponse("🎨", "미술 활동 준비"),
    new RoutineSuggestionResponse("📚", "책 읽는 시간 갖기"),
    new RoutineSuggestionResponse("🎵", "음악 수업 준비"),
    new RoutineSuggestionResponse("🎂", "생일 파티 준비"),
    new RoutineSuggestionResponse("🎄", "명절 가족 모임 준비"),
    new RoutineSuggestionResponse("🎁", "선물 주고받기 연습"),
    new RoutineSuggestionResponse("🎇", "불꽃놀이 구경하기"),
    new RoutineSuggestionResponse("🥳", "친구 생일파티 참여"),
    new RoutineSuggestionResponse("😢", "속상할 때 마음 다스리기"),
    new RoutineSuggestionResponse("🙅", "싫다고 말하는 연습"),
    new RoutineSuggestionResponse("🤝", "친구와 화해하기"),
    new RoutineSuggestionResponse("🔄", "새로운 활동으로 전환하기"),
    new RoutineSuggestionResponse("🧘", "진정하는 시간 갖기")
  );

  private RoutineSuggestionCatalog() {
  }
}

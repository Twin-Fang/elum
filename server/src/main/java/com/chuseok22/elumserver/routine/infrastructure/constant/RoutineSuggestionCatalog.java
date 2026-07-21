package com.chuseok22.elumserver.routine.infrastructure.constant;

import com.chuseok22.elumserver.routine.application.dto.response.RoutineSuggestionResponse;
import java.util.List;

// 홈 화면 "추천 일과" 카드에 무작위로 노출할 하드코딩 데이터.
// DB에 저장하지 않는 정적 데이터라 엔티티/리포지토리를 두지 않는다.
public final class RoutineSuggestionCatalog {

  public static final List<RoutineSuggestionResponse> ALL = List.of(
    new RoutineSuggestionResponse("☂️", "비 오는 날 등교 준비", "지금 밖에 비가 오고 있는데 아이가 학교에 갈 준비를 해야 돼"),
    new RoutineSuggestionResponse("🎒", "아침 등교 준비", "아침에 아이가 학교 갈 준비를 하는 걸 도와주고 싶어"),
    new RoutineSuggestionResponse("🚌", "스쿨버스 타기 준비", "아이가 처음으로 스쿨버스를 타고 등교해야 돼"),
    new RoutineSuggestionResponse("🏫", "학교 처음 가는 날", "아이가 오늘 처음으로 학교에 가는 날이야"),
    new RoutineSuggestionResponse("🔔", "하교 후 집에 오기", "학교 끝나고 아이 혼자 집에 오는 연습을 시키고 싶어"),
    new RoutineSuggestionResponse("🚗", "차 타고 이동하기", "차 타고 멀리 이동해야 하는데 아이가 낯설어할 것 같아"),
    new RoutineSuggestionResponse("🚶", "혼자 걷기 연습", "아이가 혼자 걸어서 이동하는 연습을 하고 있어"),
    new RoutineSuggestionResponse("🚏", "버스정류장 기다리기", "버스정류장에서 버스를 기다리는 법을 알려주고 싶어"),
    new RoutineSuggestionResponse("🧥", "외출 전 옷 챙겨입기", "외출하기 전에 아이가 스스로 옷을 챙겨 입어야 돼"),
    new RoutineSuggestionResponse("🛍️", "마트 다녀오기", "아이랑 같이 마트에 다녀올 거야"),
    new RoutineSuggestionResponse("🏥", "병원 방문 준비", "내일 아이가 병원에 가야 하는데 준비를 도와주고 싶어"),
    new RoutineSuggestionResponse("💉", "예방접종 하러 가기", "다음 주에 아이가 예방접종을 맞으러 가야 돼"),
    new RoutineSuggestionResponse("🦷", "치과 진료 준비", "아이가 처음으로 치과 진료를 받으러 가야 해"),
    new RoutineSuggestionResponse("🩺", "건강검진 받기", "아이가 건강검진을 받으러 병원에 가야 돼"),
    new RoutineSuggestionResponse("💊", "약 챙겨 먹기", "아이가 매일 약을 잊지 않고 챙겨 먹었으면 좋겠어"),
    new RoutineSuggestionResponse("🪥", "양치질 하기", "아이가 스스로 양치질하는 습관을 들이고 싶어"),
    new RoutineSuggestionResponse("🛁", "목욕하기", "아이가 혼자서 목욕하는 걸 연습시키고 싶어"),
    new RoutineSuggestionResponse("🧴", "손 씻기 연습", "밥 먹기 전에 손 씻는 습관을 만들어주고 싶어"),
    new RoutineSuggestionResponse("✂️", "머리 자르러 가기", "아이가 처음으로 미용실에서 머리를 잘라야 돼"),
    new RoutineSuggestionResponse("👕", "혼자 옷 갈아입기", "아이가 혼자 옷을 갈아입는 연습을 하고 있어"),
    new RoutineSuggestionResponse("🍱", "체험학습 준비", "다음 주에 아이가 체험학습을 가는데 준비물을 챙겨야 돼"),
    new RoutineSuggestionResponse("🍽️", "저녁 식사 준비", "저녁 식사 시간에 아이가 스스로 준비하도록 도와주고 싶어"),
    new RoutineSuggestionResponse("🥄", "혼자 밥 먹기 연습", "아이가 혼자 숟가락으로 밥을 먹는 연습을 하고 있어"),
    new RoutineSuggestionResponse("🍎", "간식 시간 갖기", "아이랑 정해진 시간에 간식을 먹는 습관을 만들고 싶어"),
    new RoutineSuggestionResponse("🥤", "물 마시는 습관 들이기", "아이가 하루에 물을 자주 마시는 습관을 들였으면 좋겠어"),
    new RoutineSuggestionResponse("🌙", "잠자리 준비하기", "아이가 자기 전에 잠자리를 스스로 준비하도록 알려주고 싶어"),
    new RoutineSuggestionResponse("🛏️", "혼자 잠들기 연습", "아이가 혼자 방에서 잠드는 연습을 하고 있어"),
    new RoutineSuggestionResponse("⏰", "아침에 일어나기", "아이가 아침에 스스로 일어나는 습관을 들이고 싶어"),
    new RoutineSuggestionResponse("🧸", "자기 전 정리 정돈", "자기 전에 아이가 장난감을 스스로 정리했으면 좋겠어"),
    new RoutineSuggestionResponse("😴", "낮잠 준비하기", "아이가 낮잠 자기 전에 준비하는 걸 도와주고 싶어"),
    new RoutineSuggestionResponse("🧭", "새로운 장소 방문", "아이랑 처음 가보는 장소에 방문할 예정이야"),
    new RoutineSuggestionResponse("🏛️", "박물관 다녀오기", "이번 주말에 아이랑 박물관에 다녀오려고 해"),
    new RoutineSuggestionResponse("🎪", "낯선 행사 참여하기", "아이가 처음 가보는 행사에 참여해야 돼"),
    new RoutineSuggestionResponse("🏖️", "처음 가는 여행지 적응", "아이랑 처음 가는 여행지에 가는데 적응을 도와주고 싶어"),
    new RoutineSuggestionResponse("🧑‍🏫", "새로운 선생님 만나기", "다음 주에 아이가 새로운 선생님을 처음 만나야 돼"),
    new RoutineSuggestionResponse("🧩", "친구와 놀이하기", "아이가 친구랑 같이 노는 연습을 하고 있어"),
    new RoutineSuggestionResponse("⚽", "놀이터에서 놀기", "아이랑 놀이터에 놀러 갈 거야"),
    new RoutineSuggestionResponse("🎨", "미술 활동 준비", "아이가 미술 수업에 참여할 준비를 해야 돼"),
    new RoutineSuggestionResponse("📚", "책 읽는 시간 갖기", "아이랑 매일 책 읽는 시간을 가지려고 해"),
    new RoutineSuggestionResponse("🎵", "음악 수업 준비", "아이가 음악 수업을 들으러 가야 돼"),
    new RoutineSuggestionResponse("🎂", "생일 파티 준비", "다음 주에 아이 생일 파티를 준비해야 돼"),
    new RoutineSuggestionResponse("🎄", "명절 가족 모임 준비", "이번 명절에 가족 모임에 아이랑 함께 가야 돼"),
    new RoutineSuggestionResponse("🎁", "선물 주고받기 연습", "아이가 선물을 주고받는 예절을 연습했으면 좋겠어"),
    new RoutineSuggestionResponse("🎇", "불꽃놀이 구경하기", "아이랑 불꽃놀이를 구경하러 갈 건데 아이가 큰 소리를 무서워해"),
    new RoutineSuggestionResponse("🥳", "친구 생일파티 참여", "아이가 친구 생일파티에 처음 초대받았어"),
    new RoutineSuggestionResponse("😢", "속상할 때 마음 다스리기", "아이가 속상할 때 스스로 마음을 다스리는 법을 알려주고 싶어"),
    new RoutineSuggestionResponse("🙅", "싫다고 말하는 연습", "아이가 싫을 때 자기 의사를 표현하는 연습을 하고 있어"),
    new RoutineSuggestionResponse("🤝", "친구와 화해하기", "아이가 친구랑 다퉜는데 화해하는 법을 알려주고 싶어"),
    new RoutineSuggestionResponse("🔄", "새로운 활동으로 전환하기", "아이가 하던 활동을 멈추고 다음 활동으로 넘어가는 걸 힘들어해"),
    new RoutineSuggestionResponse("🧘", "진정하는 시간 갖기", "아이가 흥분했을 때 진정하는 시간을 가졌으면 좋겠어")
  );

  private RoutineSuggestionCatalog() {
  }
}

package com.chuseok22.elumserver.ai.core;

import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import java.util.Set;

// Gemini 요청 User Content에 담기는 아동 설정 조각. nickname/supportGoals가 비어있어도
// (온보딩 미완료) 필드 자체는 항상 포함해 응답 구조를 일정하게 유지한다.
public record ChildProfileInput(String nickname, Set<SupportGoal> supportGoals) {

}

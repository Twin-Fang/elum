package com.chuseok22.elumserver.admin.application.dto.response;

import java.util.List;

/**
 * 가입 단계 (#1436): 가입 > 일과 만듦 > 카드 체크 > 기기 연결 > 스토어 결제, 단계마다 인원·가입 대비·이전 단계 대비 비율
 */
public record AdminUsageFunnel(List<Stage> stages) {

  /** 가입자가 한 명도 없음 (빈 상태) */
  public boolean isEmpty() {
    return stages.isEmpty() || stages.get(0).count() == 0;
  }

  /** 단계 하나: 이름, 인원, 가입 대비 %(막대 폭), 이전 단계 대비 %(첫 단계·이전 0명이면 null) */
  public record Stage(String label, long count, int percentOfSignups, Integer percentOfPrevious) {
  }
}

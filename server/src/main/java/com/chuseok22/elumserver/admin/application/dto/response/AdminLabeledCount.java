package com.chuseok22.elumserver.admin.application.dto.response;

import java.util.List;
import java.util.stream.IntStream;

/**
 * 이름 붙은 인원 한 칸: 이름, 인원, 전체 대비 % (마지막 활동 분포·플랫폼 칸 공통)
 */
public record AdminLabeledCount(String label, long count, int percent) {

  /** 이름·인원 목록 > 전체 대비 % 를 붙인 칸 목록 (전체 0이면 모두 0%) */
  public static List<AdminLabeledCount> withPercents(List<String> labels, List<Long> counts) {
    long total = counts.stream().mapToLong(Long::longValue).sum();
    return IntStream.range(0, labels.size())
      .mapToObj(index -> new AdminLabeledCount(labels.get(index), counts.get(index),
        total == 0 ? 0 : (int) Math.round(counts.get(index) * 100.0 / total)))
      .toList();
  }
}

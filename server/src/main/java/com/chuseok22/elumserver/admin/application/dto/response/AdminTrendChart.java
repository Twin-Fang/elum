package com.chuseok22.elumserver.admin.application.dto.response;

import java.util.List;

/**
 * 추이 그래프 한 벌: 단위(day, month), x축 이름, 칸 첫날(yyyy-MM-dd, 막대 클릭 필터용), 줄 목록
 */
public record AdminTrendChart(String unit, List<String> labels, List<String> bucketStarts, List<AdminTrendSeries> series) {
}

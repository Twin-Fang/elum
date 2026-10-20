package com.chuseok22.elumserver.admin.application.dto.response;

import java.util.List;

/** 추이 그래프 한 줄: key(색·범례 고정용), 이름, 칸별 값 (null = 기록 없음) */
public record AdminTrendSeries(String key, String label, List<Number> values) {
}

package com.chuseok22.elumserver.ai.application.dto.response;

import com.chuseok22.elumserver.ai.core.AiFailureKind;
import java.time.LocalDateTime;

/** 최근 24시간 실패 묶음: 원인 분류 × 제공자 줄 > 건수, 마지막 시각 */
public record AiFailureCount(AiFailureKind kind, String laneLabel, long count, LocalDateTime lastAt) {
}

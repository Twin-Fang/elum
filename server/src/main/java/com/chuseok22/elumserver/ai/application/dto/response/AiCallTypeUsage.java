package com.chuseok22.elumserver.ai.application.dto.response;

import com.chuseok22.elumserver.ai.core.AiCallType;

/** 기간 합계 × 호출 유형: 호출 수·성공 수·추정 비용(USD) */
public record AiCallTypeUsage(AiCallType callType, long totalCount, long successCount, double costUsd) {
}

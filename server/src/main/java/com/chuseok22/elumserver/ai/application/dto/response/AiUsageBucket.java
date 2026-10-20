package com.chuseok22.elumserver.ai.application.dto.response;

import com.chuseok22.elumserver.ai.core.AiCallType;

/** 추이 한 칸 × 호출 유형: bucket(칸 첫날 yyyy-MM-dd) > 호출 수·성공 수·추정 비용(USD) */
public record AiUsageBucket(String bucket, AiCallType callType, long totalCount, long successCount, double costUsd) {
}

package com.chuseok22.elumserver.feedback.core;

import java.time.LocalDateTime;

/**
 * 의견에 실려 온 앱 환경: 앱 버전, OS, 보낸 시각 (관리자 회원 상세의 "마지막으로 알려진" 값, #656)
 */
public record FeedbackAppReport(String appVersion, String os, LocalDateTime reportedAt) {
}

package com.chuseok22.elumserver.feedback.core;

import java.time.LocalDateTime;

/** 보낸 사람에게 다시 보여 주는 의견: 본문, 보낸 시각 */
public record SentFeedback(String message, LocalDateTime sentAt) {

}

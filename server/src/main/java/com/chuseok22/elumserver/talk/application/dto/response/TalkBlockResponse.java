package com.chuseok22.elumserver.talk.application.dto.response;

import java.time.LocalDateTime;

/// 차단한 보호자 1명: 해제에 쓰는 blockId, 닉네임 (보호자 id 는 내려주지 않음)
public record TalkBlockResponse(String blockId, String nickname, LocalDateTime createdAt) {

}

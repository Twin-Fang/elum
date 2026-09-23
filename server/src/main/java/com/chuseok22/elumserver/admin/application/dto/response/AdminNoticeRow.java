package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.notice.core.NoticeStatus;
import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;

/**
 * 공지 목록 한 줄 (이슈 #370). 상태는 서비스가 서버 시계로 한 번 판단해 넘긴다 —
 * 템플릿에서 날짜를 비교하면 앱 API 와 다른 판단이 된다.
 */
public record AdminNoticeRow(AppNotice notice, NoticeStatus status) {

}

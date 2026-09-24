package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.notice.core.NoticeStatus;
import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;

/**
 * 공지 목록 한 줄 (이슈 #370). 상태는 서비스가 서버 시계로 한 번 판단해 넘긴다 —
 * 템플릿에서 날짜를 비교하면 앱 API 와 다른 판단이 된다.
 *
 * @param liveIfEnabled 지금 켜면 곧바로 게시 중이 되는지(게시 기간 안). 목록의 "켜기"가 이 줄만
 *                      한 번 더 묻는다 — 누르는 순간 보호자 모두에게 나간다 (#385 E)
 */
public record AdminNoticeRow(AppNotice notice, NoticeStatus status, boolean liveIfEnabled) {

}

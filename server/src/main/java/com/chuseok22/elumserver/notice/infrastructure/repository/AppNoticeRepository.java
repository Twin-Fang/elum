package com.chuseok22.elumserver.notice.infrastructure.repository;

import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * 게시 판단(기간·켜짐·플랫폼·순서)은 쿼리가 아니라 서비스의 자바 코드가 한다 (이슈 #370).
 *
 * <p>공지는 관리자가 손으로 올리는 몇십 건이라 전부 읽어도 가볍다. 판단을 JPQL 에 두면
 * 이 저장소의 단위 테스트(목)로는 검증할 수 없고, 관리자 목록 배지와 앱 API 가 다른
 * 판단을 쓰게 된다.
 */
public interface AppNoticeRepository extends JpaRepository<AppNotice, String> {

}

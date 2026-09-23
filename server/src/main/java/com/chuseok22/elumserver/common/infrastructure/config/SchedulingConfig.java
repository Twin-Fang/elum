package com.chuseok22.elumserver.common.infrastructure.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * 정해진 때에 도는 작업을 켠다 (이슈 #372 — 보관 기간이 지난 탈퇴 계정 정리).
 *
 * <p>이게 없으면 {@code @Scheduled} 를 붙여도 컴파일·테스트·기동이 전부 통과한 채 한 번도 돌지 않는다.
 * 탈퇴 계정이 방침에 적은 보관 기간을 넘겨 끝없이 남게 된다.
 */
@Configuration
@EnableScheduling
public class SchedulingConfig {

}

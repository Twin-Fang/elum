package com.chuseok22.elumserver.common.application.stats;

/**
 * 추이 집계 한 칸: bucket(칸 첫날 yyyy-MM-dd 문자열) > 건수
 * native 쿼리 날짜 타입 차이를 피하려고 SQL 에서 to_char 로 내린다
 */
public interface StatsBucketCount {

  String getBucket();

  long getTotal();
}

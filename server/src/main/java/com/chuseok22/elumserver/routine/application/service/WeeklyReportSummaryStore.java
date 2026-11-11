package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.application.dto.response.WeeklyReportResponse.SummarySource;
import com.chuseok22.elumserver.routine.infrastructure.entity.WeeklyReportSummary;
import com.chuseok22.elumserver.routine.infrastructure.repository.WeeklyReportSummaryRepository;
import jakarta.persistence.EntityManager;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * 정리 글 저장소 접근: 조회, 한 번만 저장, 이룸이 삭제
 * 저장은 따로 커밋 (동시에 같은 글을 만들어 유일 키가 걸려도 호출부 흐름이 롤백되지 않게)
 */
@Service
@RequiredArgsConstructor
public class WeeklyReportSummaryStore {

  private final WeeklyReportSummaryRepository weeklyReportSummaryRepository;
  private final EntityManager entityManager;

  /// 저장된 글: 줄(이름 자리 {userName})과 출처
  public record StoredSummary(List<String> lines, SummarySource source) {

  }

  @Transactional(readOnly = true)
  public Optional<StoredSummary> find(String profileId, LocalDate weekStart, String languageCode) {
    return weeklyReportSummaryRepository.findOne(profileId, weekStart, languageCode)
      .map(row -> new StoredSummary(WeeklyReportSummaryJson.read(row.getLines()), SummarySource.valueOf(row.getSource().name())));
  }

  /// 없을 때만 저장. 이미 있으면(동시 생성) 유일 키 위반 예외를 올림 — 호출부가 잡고 다시 읽음
  @Transactional(propagation = Propagation.REQUIRES_NEW)
  public void save(String profileId, LocalDate weekStart, String languageCode, List<String> lines, SummarySource source) {
    WeeklyReportSummary row = new WeeklyReportSummary();
    row.setProfile(entityManager.getReference(Profile.class, profileId));
    row.setWeekStart(weekStart);
    row.setLanguage(languageCode);
    row.setLines(WeeklyReportSummaryJson.write(lines));
    row.setSource(WeeklyReportSummary.Source.valueOf(source.name()));
    weeklyReportSummaryRepository.saveAndFlush(row);
  }

  /// 이룸이 삭제: 정리 글 전부 지움 (부르는 쪽 트랜잭션). 지운 행 수
  @Transactional
  public int deleteAllOfProfile(String profileId) {
    return weeklyReportSummaryRepository.deleteByProfileId(profileId);
  }
}

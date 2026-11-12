package com.chuseok22.elumserver.talk.application.service;

import com.chuseok22.elumserver.talk.infrastructure.repository.TalkImportRepository;
import java.time.LocalDateTime;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 이야기 인기 판정 (#1275 자동 알림): since 이후 가져간 보호자 수가 기준 이상인 글이 있는가
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class TalkPopularityService {

  private final TalkImportRepository talkImportRepository;

  public boolean hasPostImportedAtLeastSince(LocalDateTime since, long minimumImportCount) {
    List<Long> topImporterCounts = talkImportRepository.findImporterCountsPerPostSince(since, PageRequest.of(0, 1));
    return !topImporterCounts.isEmpty() && topImporterCounts.get(0) >= minimumImportCount;
  }
}

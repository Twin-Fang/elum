package com.chuseok22.elumserver.link.application.service;

import com.chuseok22.elumserver.link.infrastructure.repository.DeviceLinkRepository;
import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 이룸이 기기 연결 여부 조회 (#1409): 자동 알림이 이룸이 기기 연결 상태로 받을 사람을 거를 때
 * 연결됨 = 연결 암호를 썼고(redeemed) 끊기지 않음(revoked 없음)
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class DeviceLinkStatusQueryService {

  // 한 번에 묻는 이룸이 id 수 (in 절 길이 제한)
  private static final int PROFILE_ID_CHUNK_SIZE = 500;

  private final DeviceLinkRepository deviceLinkRepository;

  /// 이 이룸이들 중 이룸이 기기가 연결된 이룸이 id
  public Set<String> findLinkedProfileIds(Collection<String> profileIds) {
    List<String> distinctProfileIds = profileIds.stream().distinct().toList();
    Set<String> linkedProfileIds = new HashSet<>();
    for (int from = 0; from < distinctProfileIds.size(); from += PROFILE_ID_CHUNK_SIZE) {
      linkedProfileIds.addAll(deviceLinkRepository.findLinkedProfileIdsAmong(
        distinctProfileIds.subList(from, Math.min(from + PROFILE_ID_CHUNK_SIZE, distinctProfileIds.size()))));
    }
    return linkedProfileIds;
  }
}

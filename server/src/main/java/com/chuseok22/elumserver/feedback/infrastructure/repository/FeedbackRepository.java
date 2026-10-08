package com.chuseok22.elumserver.feedback.infrastructure.repository;

import com.chuseok22.elumserver.feedback.infrastructure.entity.Feedback;
import java.time.LocalDateTime;
import org.springframework.data.jpa.repository.JpaRepository;

public interface FeedbackRepository extends JpaRepository<Feedback, String> {

  /// 회원이 since 이후 보낸 건수. 하루 상한 판정에 쓴다.
  long countByMemberIdAndCreatedAtGreaterThanEqual(String memberId, LocalDateTime since);

  /// 계정을 완전히 지울 때 그 회원의 의견과 앱 상태 기록을 함께 지운다.
  void deleteAllByMemberId(String memberId);
}

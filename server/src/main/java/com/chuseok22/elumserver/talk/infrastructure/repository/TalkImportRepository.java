package com.chuseok22.elumserver.talk.infrastructure.repository;

import com.chuseok22.elumserver.talk.infrastructure.entity.TalkImport;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TalkImportRepository extends JpaRepository<TalkImport, String> {

  boolean existsByPostIdAndMemberId(String postId, String memberId);
}

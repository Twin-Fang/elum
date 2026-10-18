package com.chuseok22.elumserver.ai.infrastructure.repository;

import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplateHistory;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PromptTemplateHistoryRepository extends JpaRepository<PromptTemplateHistory, String> {

  // 이력은 append-only로 무한히 쌓이므로 화면에는 최근 50건까지만 보여준다. (키, 언어)마다 따로 본다.
  List<PromptTemplateHistory> findTop50ByPromptKeyAndLocaleOrderByCreatedAtDesc(PromptKey promptKey, String locale);

  // 언어별로 키마다 가장 최근 이력 1건(= 현재 적용본의 수정자 출처). 쿼리 1회로 목록 전체를 채운다
  @Query("""
    select h from PromptTemplateHistory h
    where h.locale = :locale
      and h.createdAt = (select max(h2.createdAt) from PromptTemplateHistory h2
                         where h2.promptKey = h.promptKey and h2.locale = h.locale)
    """)
  List<PromptTemplateHistory> findLatestPerPromptKey(@Param("locale") String locale);
}

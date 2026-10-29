package com.chuseok22.elumserver.consent.infrastructure.repository;

import com.chuseok22.elumserver.consent.core.ConsentKey;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocument;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ConsentDocumentRepository extends JpaRepository<ConsentDocument, String> {

  /** (키, 언어 코드) 한 편 */
  Optional<ConsentDocument> findByConsentKeyAndLocale(ConsentKey consentKey, String locale);

  /** 한 언어의 약관 전부 (순서 없음) */
  List<ConsentDocument> findAllByLocale(String locale);
}

package com.chuseok22.elumserver.consent.infrastructure.repository;

import com.chuseok22.elumserver.consent.core.ConsentKey;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocumentHistory;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ConsentDocumentHistoryRepository
  extends JpaRepository<ConsentDocumentHistory, String> {

  List<ConsentDocumentHistory> findTop50ByConsentKeyOrderByCreatedAtDesc(ConsentKey consentKey);
}

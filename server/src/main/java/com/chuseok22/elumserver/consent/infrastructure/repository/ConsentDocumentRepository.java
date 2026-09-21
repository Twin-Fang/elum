package com.chuseok22.elumserver.consent.infrastructure.repository;

import com.chuseok22.elumserver.consent.core.ConsentKey;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocument;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ConsentDocumentRepository extends JpaRepository<ConsentDocument, String> {

  Optional<ConsentDocument> findByConsentKey(ConsentKey consentKey);

  boolean existsByConsentKey(ConsentKey consentKey);
}

package com.chuseok22.elumserver.consent.infrastructure.config;

import com.chuseok22.elumserver.consent.core.ConsentKey;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocument;
import com.chuseok22.elumserver.consent.infrastructure.repository.ConsentDocumentRepository;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.ApplicationArguments;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StreamUtils;

/**
 * 없는 약관 문서를 앱 번들과 <b>같은 본문</b>으로 채운다 (이슈 #278).
 *
 * <p>본문은 {@code resources/consent/*.txt} 에 있고, 그 파일은 앱의
 * {@code consent_documents.dart} 에서 기계로 떠낸 것이다. 손으로 옮겨 적으면
 * 한 글자씩 어긋나고, 그 어긋남이 "앱에서 본 문구와 서버가 준 문구가 다르다"가 된다.
 *
 * <p><b>이미 있는 문서는 건드리지 않는다.</b> 관리자가 고쳐 둔 내용을 배포할 때마다
 * 되돌리면 관리자 화면이 무의미해진다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ConsentDocumentInitializer implements ApplicationRunner {

  /** 앱 번들이 들고 있는 버전과 같다. 첫 시딩에만 쓴다. */
  private static final String INITIAL_VERSION = "2026-09-21";

  private final ConsentDocumentRepository consentDocumentRepository;

  @Override
  @Transactional
  public void run(ApplicationArguments args) {
    for (ConsentKey key : ConsentKey.values()) {
      var existing = consentDocumentRepository.findByConsentKey(key);
      if (existing.isPresent()) {
        syncRequired(existing.get());
        continue;
      }
      String body = readDefaultBody(key);
      if (body == null) {
        // 본문을 못 읽었는데 빈 문서를 만들면 앱이 빈 약관을 띄운다. 그것보다는
        // 문서가 아예 없어서 앱이 번들 기본값으로 떨어지는 편이 낫다.
        log.error("약관 기본 본문을 읽지 못해 문서를 만들지 않습니다. key={}", key);
        continue;
      }
      ConsentDocument document = new ConsentDocument();
      document.setConsentKey(key);
      document.setVersion(INITIAL_VERSION);
      document.setLabel(key.getLabel());
      document.setSummary(key.getSummary());
      document.setBody(body);
      document.setRequired(key.isRequired());
      document.setPublishedAt(LocalDateTime.now());
      consentDocumentRepository.save(document);
      log.info("약관 문서를 생성했습니다. key={} version={}", key, INITIAL_VERSION);
    }
  }

  /**
   * 필수 여부만은 코드를 따른다. 본문은 관리자가 고친 것을 존중하지만, 필수 여부는 법이 정한
   * 값이라 DB에 다른 값이 남아 있으면 그게 사고다 (예전 화면에서 끈 흔적).
   */
  private void syncRequired(ConsentDocument document) {
    boolean lawful = document.getConsentKey().isRequired();
    if (document.isRequired() != lawful) {
      log.warn("약관 필수 여부가 법이 정한 값과 달라 바로잡습니다. key={} {} -> {}",
        document.getConsentKey(), document.isRequired(), lawful);
      document.setRequired(lawful);
    }
  }

  private String readDefaultBody(ConsentKey key) {
    ClassPathResource resource = new ClassPathResource(key.getDefaultBodyResource());
    try (var stream = resource.getInputStream()) {
      return StreamUtils.copyToString(stream, StandardCharsets.UTF_8).strip();
    } catch (IOException e) {
      log.error("약관 본문 파일을 읽지 못했습니다. path={}", key.getDefaultBodyResource(), e);
      return null;
    }
  }
}

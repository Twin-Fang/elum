package com.chuseok22.elumserver.admin.infrastructure.config;

import com.chuseok22.elumserver.admin.infrastructure.entity.Admin;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminRepository;
import com.chuseok22.elumserver.common.infrastructure.properties.AdminProperties;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
@Slf4j
public class AdminAccountInitializer implements ApplicationRunner {

  private final AdminProperties adminProperties;
  private final AdminRepository adminRepository;
  private final PasswordEncoder passwordEncoder;

  @Override
  public void run(ApplicationArguments args) {
    if (adminProperties.accounts() == null) {
      return;
    }

    adminProperties.accounts().forEach(account -> {
      if (adminRepository.existsByUsername(account.username())) {
        log.info("[AdminAccountInitializer] 이미 존재하는 관리자 계정 스킵: {}", account.username());
        return;
      }

      Admin admin = new Admin();
      admin.setUsername(account.username());
      admin.setPassword(passwordEncoder.encode(account.password()));
      adminRepository.save(admin);
      log.info("[AdminAccountInitializer] 관리자 계정 생성 완료: {}", account.username());
    });
  }
}

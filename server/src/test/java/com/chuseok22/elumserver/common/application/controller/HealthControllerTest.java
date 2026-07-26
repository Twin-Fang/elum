package com.chuseok22.elumserver.common.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

class HealthControllerTest {

  private final HealthController healthController = new HealthController();

  @Test
  @DisplayName("healthz는 200과 UP 상태를 반환한다")
  void healthz_returnsOkWithUpStatus() {
    ResponseEntity<Map<String, String>> response = healthController.healthz();

    assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    assertThat(response.getBody()).containsEntry("status", "UP");
  }
}

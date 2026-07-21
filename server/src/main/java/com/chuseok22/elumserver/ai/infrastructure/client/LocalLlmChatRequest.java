package com.chuseok22.elumserver.ai.infrastructure.client;

import java.util.Map;

public record LocalLlmChatRequest(
  String model,
  String prompt,
  String system,
  double temperature,
  Map<String, Object> format
) {

}

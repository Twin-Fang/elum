package com.chuseok22.elumserver.ai.core;

import java.util.List;

public record SensitiveInfoCheckContent(
  Boolean hasSensitiveInfo,
  List<String> categories,
  String reason,
  String sanitizedText
) {

}

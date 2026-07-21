package com.chuseok22.elumserver.ai.core;

import java.util.List;

public record SensitiveInfoCheckResult(
  boolean checked,
  boolean hasSensitiveInfo,
  List<String> categories,
  String sanitizedText
) {

}

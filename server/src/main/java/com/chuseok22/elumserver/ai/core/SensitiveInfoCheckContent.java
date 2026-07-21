package com.chuseok22.elumserver.ai.core;

import java.util.List;

public record SensitiveInfoCheckContent(List<Detection> detections) {

  public record Detection(String category, String matchedText) {

  }
}

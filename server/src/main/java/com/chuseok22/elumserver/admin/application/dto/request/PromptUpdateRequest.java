package com.chuseok22.elumserver.admin.application.dto.request;

import jakarta.validation.constraints.NotBlank;

public record PromptUpdateRequest(
  @NotBlank String content
) {

}

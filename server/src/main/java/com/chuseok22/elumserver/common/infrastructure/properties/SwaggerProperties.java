package com.chuseok22.elumserver.common.infrastructure.properties;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "springdoc")
public record SwaggerProperties(
  String title,
  String description,
  String version,
  @Valid List<Server> servers
) {

  public record Server(
    @NotBlank String url,
    @NotBlank String description
  ) {

  }

}

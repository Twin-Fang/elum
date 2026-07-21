package com.chuseok22.elumserver.common.infrastructure.properties;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "swagger")
public record SwaggerProperties(
  String title,
  String description,
  String version
) {

}

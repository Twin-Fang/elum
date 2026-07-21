package com.chuseok22.elumserver.common.infrastructure.config;

import com.chuseok22.elumserver.common.infrastructure.properties.SwaggerProperties;
import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityScheme;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@RequiredArgsConstructor
public class SwaggerConfig {

  private final SwaggerProperties swaggerProperties;

  @Bean
  public OpenAPI openAPI() {
    SecurityScheme bearerAuth = new SecurityScheme()
      .type(SecurityScheme.Type.HTTP)
      .scheme("bearer")
      .bearerFormat("JWT");

    return new OpenAPI()
      .info(new Info()
        .title(swaggerProperties.title())
        .description(swaggerProperties.description())
        .version(swaggerProperties.version()))
      .components(new Components().addSecuritySchemes("bearerAuth", bearerAuth));
  }
}

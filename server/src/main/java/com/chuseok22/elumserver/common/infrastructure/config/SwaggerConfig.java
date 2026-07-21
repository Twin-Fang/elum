package com.chuseok22.elumserver.common.infrastructure.config;

import com.chuseok22.elumserver.common.infrastructure.properties.SwaggerProperties;
import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import io.swagger.v3.oas.models.security.SecurityScheme.In;
import io.swagger.v3.oas.models.security.SecurityScheme.Type;
import lombok.RequiredArgsConstructor;
import org.springdoc.core.customizers.OpenApiCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@RequiredArgsConstructor
public class SwaggerConfig {

  private final SwaggerProperties properties;

  @Bean
  public OpenAPI openAPI() {
    SecurityScheme apiKey = new SecurityScheme()
      .type(Type.HTTP)
      .scheme("bearer")
      .bearerFormat("JWT")
      .in(In.HEADER)
      .name("Authorization");

    return new OpenAPI()
      .info(new Info()
        .title(properties.title())
        .description(properties.description())
        .version(properties.version()))
      .components(new Components().addSecuritySchemes("Bearer Token", apiKey))
      .addSecurityItem(new SecurityRequirement().addList("Bearer Token"));
  }

  @Bean
  public OpenApiCustomizer serverCustomizer() {
    return openApi -> {
      properties.servers().forEach(server ->
        openApi.addServersItem(new io.swagger.v3.oas.models.servers.Server()
          .url(server.url())
          .description(server.description()))
      );
    };
  }
}

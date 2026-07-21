package com.chuseok22.elumserver.common.infrastructure.properties;

import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "admin")
public record AdminProperties(
  List<Account> accounts
) {

  public record Account(
    String username,
    String password
  ) {

  }
}

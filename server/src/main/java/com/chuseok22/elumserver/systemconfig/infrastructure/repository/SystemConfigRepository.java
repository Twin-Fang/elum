package com.chuseok22.elumserver.systemconfig.infrastructure.repository;

import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.chuseok22.elumserver.systemconfig.infrastructure.entity.SystemConfig;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SystemConfigRepository extends JpaRepository<SystemConfig, String> {

  Optional<SystemConfig> findByConfigKey(ConfigKey configKey);
}

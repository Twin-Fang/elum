package com.chuseok22.elumserver.notification.infrastructure.repository;

import com.chuseok22.elumserver.notification.infrastructure.entity.NotificationSetting;
import org.springframework.data.jpa.repository.JpaRepository;

public interface NotificationSettingRepository extends JpaRepository<NotificationSetting, String> {
}

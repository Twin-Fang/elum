package com.chuseok22.elumserver.notification.infrastructure.repository;

import com.chuseok22.elumserver.notification.infrastructure.entity.AdminMessage;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AdminMessageRepository extends JpaRepository<AdminMessage, String> {
}

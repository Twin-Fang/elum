package com.chuseok22.elumserver.notification.infrastructure.repository;

import com.chuseok22.elumserver.notification.infrastructure.entity.NoticeSeen;
import org.springframework.data.jpa.repository.JpaRepository;

public interface NoticeSeenRepository extends JpaRepository<NoticeSeen, String> {
}

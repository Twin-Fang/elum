package com.chuseok22.elumserver.talk.infrastructure.repository;

import com.chuseok22.elumserver.talk.infrastructure.entity.TalkReport;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TalkReportRepository extends JpaRepository<TalkReport, String> {
}

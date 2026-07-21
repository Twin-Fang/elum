package com.chuseok22.elumserver.admin.infrastructure.repository;

import com.chuseok22.elumserver.admin.infrastructure.entity.Admin;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AdminRepository extends JpaRepository<Admin, String> {

  boolean existsByUsername(String username);

  Optional<Admin> findByUsername(String username);
}

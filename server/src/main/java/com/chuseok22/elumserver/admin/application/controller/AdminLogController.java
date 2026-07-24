package com.chuseok22.elumserver.admin.application.controller;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class AdminLogController {

  @GetMapping("/admin/logs")
  public String logs() {
    return "admin/logs";
  }
}

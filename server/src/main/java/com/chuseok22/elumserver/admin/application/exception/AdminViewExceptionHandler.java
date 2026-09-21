package com.chuseok22.elumserver.admin.application.exception;

import com.chuseok22.elumserver.admin.application.controller.AdminConfigController;
import com.chuseok22.elumserver.admin.application.controller.AdminConsentController;
import com.chuseok22.elumserver.admin.application.controller.AdminLogController;
import com.chuseok22.elumserver.admin.application.controller.AdminMemberController;
import com.chuseok22.elumserver.admin.application.controller.AdminMonitoringController;
import com.chuseok22.elumserver.admin.application.controller.AdminPromptController;
import com.chuseok22.elumserver.admin.application.controller.AdminRoutineController;
import com.chuseok22.elumserver.admin.application.controller.AdminViewController;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;

/**
 * 관리자 <b>화면</b>에서 난 예외를 오류 화면으로 바꾼다 (이슈 #248).
 *
 * <p>여태 화면 컨트롤러에는 예외 처리가 없었다. {@code GlobalExceptionHandler} 는
 * JSON을 돌려주는 곳({@code AdminPromptTestController} · {@code AdminLogApiController})만
 * 맡고 있어서, 화면에서 예외가 나면 그대로 500으로 떨어졌다.
 *
 * <p>그래서 <b>지워진 항목의 링크를 누르거나 주소를 잘못 친 것뿐인데 서버가 고장난 것처럼
 * 보였다.</b> 실제로는 "그런 회원이 없다"(404)이고, 로그에도 500이 쌓여 진짜 장애와 섞였다.
 *
 * <p>맡을 컨트롤러를 하나씩 적는다. 패키지로 묶으면 JSON을 돌려주는 위 둘까지 삼켜
 * 그쪽이 HTML을 받게 된다.
 */
@ControllerAdvice(assignableTypes = {
  AdminConfigController.class,
  AdminConsentController.class,
  AdminLogController.class,
  AdminMemberController.class,
  AdminMonitoringController.class,
  AdminPromptController.class,
  AdminRoutineController.class,
  AdminViewController.class,
})
@Slf4j
public class AdminViewExceptionHandler {

  @ExceptionHandler(CustomException.class)
  public String handleCustomException(
    CustomException e, Model model, HttpServletRequest request, HttpServletResponse response
  ) {
    ErrorCode code = e.getErrorCode();
    // 상태 코드를 실제로 내려 준다. 화면만 바꾸고 200을 주면 로그·모니터링이 정상으로 센다.
    response.setStatus(code.getStatus().value());
    log.info("[관리자 화면] {} — {} {}", code.name(), request.getMethod(), request.getRequestURI());

    model.addAttribute("status", code.getStatus().value());
    model.addAttribute("error", code.getMessage());
    // 어디서 났는지 알아야 제보를 받았을 때 추적할 수 있다.
    model.addAttribute("path", request.getRequestURI());
    return "error";
  }
}

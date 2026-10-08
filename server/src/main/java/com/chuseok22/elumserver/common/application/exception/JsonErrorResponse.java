package com.chuseok22.elumserver.common.application.exception;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/// {@link GlobalExceptionHandler} 범위 밖 패키지(admin)에 있지만 JSON 에러 응답을 받아야 하는 컨트롤러에 붙인다.
///
/// <p>클래스 단위로 적용된다. 같은 컨트롤러에 SSR 화면과 JSON 엔드포인트를 섞어 두면 화면 쪽도 JSON 에러를 받는다.
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface JsonErrorResponse {
}

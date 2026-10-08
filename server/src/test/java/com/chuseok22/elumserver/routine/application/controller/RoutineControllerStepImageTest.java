package com.chuseok22.elumserver.routine.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineStepResponse;
import com.chuseok22.elumserver.routine.application.service.RoutineCreateService;
import com.chuseok22.elumserver.routine.application.service.RoutineProgressService;
import com.chuseok22.elumserver.routine.application.service.RoutineQueryService;
import com.chuseok22.elumserver.routine.application.service.RoutineService;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository;
import com.chuseok22.elumserver.routine.application.service.RoutineAuthorResolver;
import com.chuseok22.elumserver.routine.application.service.RoutineStepPhotoService;
import java.lang.reflect.Method;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.authentication.TestingAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestPart;

/**
 * 카드 사진 교체 엔드포인트의 연결 (이슈 #455).
 *
 * <p>스프링을 띄우지 않는다. 서비스로 넘기는 인자와 매핑(PUT · multipart · 필드명 image)만 본다.
 */
class RoutineControllerStepImageTest {

  private final RoutineStepPhotoService photoService = mock(RoutineStepPhotoService.class);
  private final RoutineController controller = new RoutineController(mock(RoutineService.class), mock(RoutineCreateService.class),
    mock(RoutineQueryService.class), mock(RoutineProgressService.class), photoService,
    new RoutineAuthorResolver(mock(ProfileGuardianRepository.class)));

  @Test
  @DisplayName("호출자와 경로 값, 파일을 서비스에 그대로 넘기고 카드 응답을 200 으로 돌려준다")
  void delegatesToService() {
    Authentication auth = new TestingAuthenticationToken("member-1", null);
    MockMultipartFile file = new MockMultipartFile("image", "a.jpg", "image/jpeg", new byte[]{1});
    RoutineStepResponse body = new RoutineStepResponse("step-1", 1, "제목", "설명", "step-1/new.jpg", false, null, null);
    when(photoService.replaceStepImage(any(), any(), any(), any())).thenReturn(body);

    ResponseEntity<RoutineStepResponse> response = controller.replaceStepImage(auth, "routine-1", "step-1", file);

    assertThat(response.getStatusCode().value()).isEqualTo(200);
    assertThat(response.getBody()).isEqualTo(body);
    verify(photoService).replaceStepImage(Caller.from(auth), "routine-1", "step-1", file);
  }

  @Test
  @DisplayName("PUT /{routineId}/steps/{stepId}/image 이고 multipart 의 image 파트를 받는다")
  void mapping() throws NoSuchMethodException {
    Method method = RoutineController.class.getMethod("replaceStepImage",
      Authentication.class, String.class, String.class, org.springframework.web.multipart.MultipartFile.class);

    PutMapping mapping = method.getAnnotation(PutMapping.class);
    assertThat(mapping.value()).containsExactly("/{routineId}/steps/{stepId}/image");
    assertThat(mapping.consumes()).containsExactly(MediaType.MULTIPART_FORM_DATA_VALUE);
    assertThat(method.getParameters()[3].getAnnotation(RequestPart.class).value()).isEqualTo("image");
  }
}

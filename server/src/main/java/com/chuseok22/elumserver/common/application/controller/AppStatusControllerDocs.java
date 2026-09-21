package com.chuseok22.elumserver.common.application.controller;

import com.chuseok22.elumserver.common.application.dto.response.AppStatusResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;

@Tag(
  name = "App",
  description = "앱이 시작할 때 서버 상태를 확인하는 API. 점검 중인지, 이 버전으로 계속 써도 되는지를 돌려줍니다."
)
public interface AppStatusControllerDocs {

  @Operation(
    summary = "앱 상태 확인",
    description = """
      점검 여부와 버전 요구를 돌려줍니다.

      **인증이 없습니다.** 로그인 전에도, 점검 중에도 부를 수 있어야 하기 때문입니다.
      이 엔드포인트까지 막으면 앱이 점검 사실을 알 방법이 없습니다.

      **앱이 하는 판단**

      - `maintenance`가 true면 점검 안내만 보여줍니다
      - 현재 버전 < `minVersion` 이면 업데이트해야 계속할 수 있습니다
      - 현재 버전 < `latestVersion` 이면 업데이트를 권하되 건너뛸 수 있습니다
      - **이 요청이 실패하면 그냥 진행합니다** — 서버를 못 봤다는 이유로 앱을 막으면
        서버가 죽었을 때 아무도 앱을 열지 못합니다
      """
  )
  @ApiResponses(@ApiResponse(
    responseCode = "200", description = "확인 완료",
    content = @Content(schema = @Schema(implementation = AppStatusResponse.class),
      examples = @ExampleObject(value = """
        {
          "maintenance": false,
          "maintenanceMessage": "잠시 점검하고 있어요. 조금 뒤에 다시 열어주세요",
          "ios": { "minVersion": "1.2.0", "latestVersion": "1.21.0" },
          "android": { "minVersion": "1.2.0", "latestVersion": "1.21.0" }
        }
        """))
  ))
  ResponseEntity<AppStatusResponse> status();
}

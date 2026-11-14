package com.chuseok22.elumserver.ai.core;

/**
 * 다시 그리기 보호자 요청 규칙 (OpenAI·Gemini): scene.guardianRequest 우선 적용, 물은 수도꼭지 > 세면대
 * 운영 DB 지시문과 별개로 코드에 둠 > 요청 있는 다시 그리기에만 붙음 (#1384, #1378 개선안 openai_prefix_append)
 */
public final class GuardianRequestImageRules {

  public static final String KO = """
    [보호자 요청]
    - scene.guardianRequest가 있으면 이 그림에 대한 보호자의 수정 요청입니다. 그대로 반영합니다. scene.stepDescription과 [물건] 규칙보다 우선합니다 (예: "우산 대신 컵을 들게"는 컵을 그리고 우산은 그리지 않음, "비누를 빼 줘"는 비누, 비누통, 디스펜서를 그리지 않음).
    - 그 밖의 주요 행동과 화풍은 그대로 둡니다.

    [물]
    - 물은 언제나 수도꼭지에서 세면대로 흐릅니다. 손, 물건, 허공에서 나오지 않습니다.""";

  public static final String EN = """
    [Guardian request]
    - If scene.guardianRequest is present, it is the guardian's change to this picture. Apply it exactly. It overrides scene.stepDescription and the [Objects] rules (e.g. "hold a cup instead of the umbrella" means draw a cup and no umbrella; "remove the soap" means no soap bar, soap bottle, or dispenser).
    - Keep the main action and the style otherwise.

    [Water]
    - Water always flows from a faucet into a sink, never from hands, objects, or the air.""";

  private GuardianRequestImageRules() {
  }

  /// 그림 지시문 언어에 맞는 규칙
  public static String of(ImagePromptLanguage language) {
    return language == ImagePromptLanguage.EN ? EN : KO;
  }
}

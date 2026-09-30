package com.chuseok22.elumserver.member.infrastructure.entity;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.member.application.dto.response.ProfileSummaryResponse;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class ImageStyleTest {

  @Test
  @DisplayName("새 프로필의 그림 방식은 만화다 — 기존 동작이 그대로다")
  void newProfile_defaultsToCartoon() {
    assertThat(new Profile().getImageStyle()).isEqualTo(ImageStyle.CARTOON);
  }

  @Test
  @DisplayName("null 이 들어 있어도 getter 는 만화를 돌려준다 — 옛 행·옛 서버가 넣은 행")
  void nullStoredValue_readsAsCartoon() {
    Profile profile = new Profile();
    profile.setImageStyle(null);

    assertThat(profile.getImageStyle()).isEqualTo(ImageStyle.CARTOON);
    assertThat(ImageStyle.orDefault(null)).isEqualTo(ImageStyle.CARTOON);
  }

  @Test
  @DisplayName("고른 방식은 그대로 읽힌다")
  void chosenStyle_isKept() {
    Profile profile = new Profile();
    profile.setImageStyle(ImageStyle.PHOTO_ONLY);

    assertThat(profile.getImageStyle()).isEqualTo(ImageStyle.PHOTO_ONLY);
  }

  @Test
  @DisplayName("ProfileSummaryResponse 는 프로필의 그림 방식을 싣는다")
  void profileSummary_carriesImageStyle() {
    Profile profile = new Profile();
    profile.setId("p1");
    profile.setNickname("하늘");
    profile.setImageStyle(ImageStyle.REALISTIC);

    assertThat(ProfileSummaryResponse.from(profile))
      .isEqualTo(new ProfileSummaryResponse("p1", "하늘", null, ImageStyle.REALISTIC));
  }
}

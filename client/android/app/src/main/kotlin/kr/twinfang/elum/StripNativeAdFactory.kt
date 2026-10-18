package kr.twinfang.elum

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.drawable.GradientDrawable
import android.view.LayoutInflater
import android.view.View
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

/**
 * 하단 한 줄 광고 띠 팩토리 (#743): 레이아웃 생성 > 색 적용 > 에셋 그대로 연결
 * 광고 뷰만 만든다 (소리 재생 없음). 에셋 문구는 가공하지 않음 (AdMob 정책). AdChoices 는 SDK 기본 위치
 */
class StripNativeAdFactory(private val context: Context) : NativeAdFactory {

    companion object {
        // Dart GoogleAdBannerLoader.factoryId 와 같은 값
        const val FACTORY_ID = "elumStrip"

        // customOptions 키: Dart GoogleAdBannerLoader 와 같은 값
        private const val OPTION_BACKGROUND_COLOR = "backgroundColor"
        private const val OPTION_HEADLINE_COLOR = "headlineColor"
        private const val OPTION_CALL_TO_ACTION_COLOR = "callToActionColor"
        private const val OPTION_BADGE_BACKGROUND_COLOR = "badgeBackgroundColor"
        private const val OPTION_BADGE_TEXT_COLOR = "badgeTextColor"
        private const val OPTION_BADGE_LABEL = "badgeLabel"

        // 옵션 누락 시 기본값 (Dart 가 항상 넘기므로 방어용)
        private const val FALLBACK_TEXT_COLOR = 0xFF000000.toInt()
        private const val FALLBACK_BACKGROUND_COLOR = 0xFFFFFFFF.toInt()
        private const val FALLBACK_BADGE_LABEL = "AD"
    }

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?,
    ): NativeAdView {
        val adView = LayoutInflater.from(context)
            .inflate(R.layout.strip_native_ad, null) as NativeAdView
        val badgeView = adView.findViewById<TextView>(R.id.strip_ad_badge)
        val headlineView = adView.findViewById<TextView>(R.id.strip_ad_headline)
        val callToActionView = adView.findViewById<TextView>(R.id.strip_ad_call_to_action)
        val chevronView = adView.findViewById<ImageView>(R.id.strip_ad_chevron)
        val callToActionGroup = adView.findViewById<View>(R.id.strip_ad_call_to_action_group)

        // 색 적용 (라이트·다크 값은 Dart 색 토큰에서 옴)
        val callToActionColor = colorOption(customOptions, OPTION_CALL_TO_ACTION_COLOR, FALLBACK_TEXT_COLOR)
        adView.setBackgroundColor(colorOption(customOptions, OPTION_BACKGROUND_COLOR, FALLBACK_BACKGROUND_COLOR))
        headlineView.setTextColor(colorOption(customOptions, OPTION_HEADLINE_COLOR, FALLBACK_TEXT_COLOR))
        callToActionView.setTextColor(callToActionColor)
        chevronView.imageTintList = ColorStateList.valueOf(callToActionColor)
        badgeView.setTextColor(colorOption(customOptions, OPTION_BADGE_TEXT_COLOR, FALLBACK_TEXT_COLOR))
        badgeView.background = GradientDrawable().apply {
            // 캡슐 모양 (높이보다 큰 반경)
            cornerRadius = 999f
            setColor(colorOption(customOptions, OPTION_BADGE_BACKGROUND_COLOR, FALLBACK_BACKGROUND_COLOR))
        }
        badgeView.text = customOptions?.get(OPTION_BADGE_LABEL) as? String ?: FALLBACK_BADGE_LABEL

        // 에셋 연결: 헤드라인 필수, 행동 문구는 있을 때만 (없으면 화살표만, 클릭은 헤드라인)
        headlineView.text = nativeAd.headline
        adView.headlineView = headlineView
        val callToAction = nativeAd.callToAction
        if (callToAction.isNullOrEmpty()) {
            callToActionView.visibility = View.GONE
        } else {
            callToActionView.text = callToAction
            adView.callToActionView = callToActionGroup
        }

        adView.setNativeAd(nativeAd)
        return adView
    }

    // Dart int 는 크기에 따라 Integer·Long 으로 옴 > ARGB Int 로 통일
    private fun colorOption(options: Map<String, Any>?, key: String, fallback: Int): Int =
        (options?.get(key) as? Number)?.toInt() ?: fallback
}

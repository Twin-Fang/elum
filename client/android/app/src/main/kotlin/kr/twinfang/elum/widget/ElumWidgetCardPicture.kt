package kr.twinfang.elum.widget

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import java.io.File

/**
 * 카드 그림 파일 > 위젯용 작은 비트맵 (긴 변 600px 이하, 파일 없거나 깨졌으면 null > 루미가 카드 든 그림)
 * RemoteViews 비트맵은 런처로 넘어가며 크기 제한이 있어 줄여서 읽음
 */
object ElumWidgetCardPicture {
    // 위젯 카드 그림 긴 변 최대 (px)
    private const val MAX_PICTURE_SIDE_PIXELS = 600

    fun decode(imageFilePath: String?): Bitmap? {
        if (imageFilePath.isNullOrEmpty()) return null
        return try {
            val file = File(imageFilePath)
            if (!file.isFile) return null
            // 크기만 먼저 읽기 > 2의 거듭제곱 축소 비율 > 실제 읽기
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(file.path, bounds)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
            val options = BitmapFactory.Options().apply {
                inSampleSize = sampleSizeOf(maxOf(bounds.outWidth, bounds.outHeight))
            }
            BitmapFactory.decodeFile(file.path, options)
        } catch (error: Exception) {
            Log.w(ElumWidgets.LOG_TAG, "[widget card picture] decode failed : ${error.javaClass.simpleName}")
            null
        } catch (error: OutOfMemoryError) {
            Log.w(ElumWidgets.LOG_TAG, "[widget card picture] decode failed : out of memory")
            null
        }
    }

    private fun sampleSizeOf(longSidePixels: Int): Int {
        var sampleSize = 1
        while (longSidePixels / sampleSize > MAX_PICTURE_SIDE_PIXELS) sampleSize *= 2
        return sampleSize
    }
}

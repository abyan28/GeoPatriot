package com.geotagcamera.geotag_camera

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Matrix
import android.media.ExifInterface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "imageSize" -> runAsync(result) {
                    imageSize(call.argument<String>("path")!!)
                }
                "composite" -> runAsync(result) {
                    composite(
                        sourcePath = call.argument<String>("sourcePath")!!,
                        overlayPng = call.argument<ByteArray>("overlayPng")!!,
                        x = call.argument<Int>("x")!!,
                        y = call.argument<Int>("y")!!,
                        quality = call.argument<Int>("quality")!!,
                        outputPath = call.argument<String>("outputPath")!!,
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Jalankan [block] di thread latar dan kirim hasilnya kembali di main thread. */
    private fun runAsync(result: MethodChannel.Result, block: () -> Any?) {
        worker.execute {
            try {
                val value = block()
                runOnUiThread { result.success(value) }
            } catch (e: Throwable) {
                runOnUiThread { result.error("compositor_failed", e.toString(), null) }
            }
        }
    }

    private fun exifOrientation(path: String): Int =
        ExifInterface(path).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)

    private fun swapsAxes(orientation: Int): Boolean =
        orientation == ExifInterface.ORIENTATION_TRANSPOSE ||
            orientation == ExifInterface.ORIENTATION_ROTATE_90 ||
            orientation == ExifInterface.ORIENTATION_TRANSVERSE ||
            orientation == ExifInterface.ORIENTATION_ROTATE_270

    /** Ukuran foto dalam orientasi tampilan, tanpa mendekode piksel. */
    private fun imageSize(path: String): Map<String, Int> {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        require(bounds.outWidth > 0 && bounds.outHeight > 0) { "Gambar tidak dapat dibaca" }
        val swap = swapsAxes(exifOrientation(path))
        return mapOf(
            "width" to if (swap) bounds.outHeight else bounds.outWidth,
            "height" to if (swap) bounds.outWidth else bounds.outHeight,
        )
    }

    private fun orientationMatrix(orientation: Int): Matrix? {
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                matrix.postRotate(90f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                matrix.postRotate(-90f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(-90f)
            else -> return null
        }
        return matrix
    }

    /**
     * Putar foto sesuai EXIF, tempel [overlayPng] di ([x], [y]) lalu simpan
     * sebagai JPEG. Hasilnya tidak membawa EXIF (sama seperti jalur Dart);
     * tag GPS/waktu ditulis kemudian oleh ExifWriter.
     */
    private fun composite(
        sourcePath: String,
        overlayPng: ByteArray,
        x: Int,
        y: Int,
        quality: Int,
        outputPath: String,
    ): Boolean {
        val orientation = exifOrientation(sourcePath)
        val options = BitmapFactory.Options().apply {
            inPreferredConfig = Bitmap.Config.ARGB_8888
            inMutable = true
        }
        val decoded = BitmapFactory.decodeFile(sourcePath, options) ?: return false
        var photo = decoded
        val overlay = BitmapFactory.decodeByteArray(overlayPng, 0, overlayPng.size)
        try {
            if (overlay == null) return false

            val matrix = orientationMatrix(orientation)
            if (matrix != null) {
                photo = Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
                if (photo !== decoded) decoded.recycle()
            }
            if (!photo.isMutable) {
                val copy = photo.copy(Bitmap.Config.ARGB_8888, true)
                photo.recycle()
                photo = copy
            }

            Canvas(photo).drawBitmap(overlay, x.toFloat(), y.toFloat(), null)

            val output = File(outputPath)
            output.parentFile?.mkdirs()
            FileOutputStream(output).use { stream ->
                if (!photo.compress(Bitmap.CompressFormat.JPEG, quality, stream)) return false
                stream.flush()
            }
            return true
        } finally {
            overlay?.recycle()
            if (!photo.isRecycled) photo.recycle()
        }
    }

    override fun onDestroy() {
        worker.shutdown()
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "geopatriot/compositor"
    }
}

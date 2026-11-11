package com.longevityplate.longevity_plate

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // FCM chép custom data vào Intent, còn FlutterActivity lấy extra "route" làm
    // route khởi đầu. Bỏ qua để route trong thông báo luôn đi qua resolvePushRoute.
    override fun getInitialRoute(): String? = null
    private var pendingSave: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.longevityplate/documents")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "savePdf" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val name = call.argument<String>("name")
                        if (pendingSave != null) {
                            result.error("save_busy", "Đang có một tệp chờ lưu.", null)
                        } else if (bytes == null || bytes.isEmpty() || name == null) {
                            result.error("invalid_pdf", "Không có dữ liệu PDF.", null)
                        } else {
                            pendingSave = result
                            pendingBytes = bytes
                            try {
                                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                    addCategory(Intent.CATEGORY_OPENABLE)
                                    type = "application/pdf"
                                    putExtra(Intent.EXTRA_TITLE, name)
                                }
                                @Suppress("DEPRECATION")
                                startActivityForResult(intent, 393)
                            } catch (error: Exception) {
                                pendingSave = null
                                pendingBytes = null
                                result.error("save_unavailable", error.message, null)
                            }
                        }
                    }
                    "openPdf" -> {
                        val raw = call.argument<String>("uri")
                        val uri = raw?.let { Uri.parse(it) }
                        if (uri?.scheme != "content") {
                            result.error("invalid_uri", "Đường dẫn PDF không hợp lệ.", null)
                        } else {
                            try {
                                startActivity(Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(uri, "application/pdf")
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                })
                                result.success(true)
                            } catch (_: Exception) {
                                result.success(false)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Used for Storage Access Framework result")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 393) return
        val result = pendingSave ?: return
        val bytes = pendingBytes
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || bytes == null) {
            pendingSave = null
            pendingBytes = null
            result.error("save_cancelled", "Đã hủy lưu PDF.", null)
            return
        }
        // Ghi tệp ngoài UI thread, tránh làm treo giao diện khi document provider chậm.
        Thread {
            try {
                contentResolver.openOutputStream(uri, "w")?.use { it.write(bytes) }
                    ?: throw IllegalStateException("Không mở được vị trí lưu.")
                runOnUiThread {
                    pendingSave = null
                    pendingBytes = null
                    result.success(uri.toString())
                }
            } catch (error: Exception) {
                runOnUiThread {
                    pendingSave = null
                    pendingBytes = null
                    result.error("save_failed", error.message, null)
                }
            }
        }.start()
    }
}

package com.example.xirja_frontend

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.os.Bundle
import android.content.pm.PackageManager
import android.os.Build
import android.os.StrictMode
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.bixolon.commonlib.BXLCommonConst
import com.bixolon.commonlib.log.LogService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileWriter
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "xirja/printers"
        private const val REQUEST_BT_CONNECT_PERMISSION = 1101
        private val BLUETOOTH_SPP_UUID: UUID =
            UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    }

    private var pendingPermissionCallback: ((Boolean) -> Unit)? = null
    private val debugLogLock = Any()
    private val appBuildInfo by lazy { resolveAppBuildInfo() }
    private val printExecutor = Executors.newSingleThreadExecutor()
    private val printInProgress = AtomicBoolean(false)
    private val nativeBootstrapInitialized = AtomicBoolean(false)
    private val uncaughtLoggerInstalled = AtomicBoolean(false)
    private val vendorLoggingInitialized = AtomicBoolean(false)
    private val bixolonNativeLibraryLoadAttempted = AtomicBoolean(false)
    @Volatile
    private var bixolonNativeLibraryLoaded = false
    private val bixolonSdkPrinter by lazy {
        BixolonSdkPrinter(applicationContext) { scope, message, data ->
            appendNativeDebugLog(scope = scope, message = message, data = data)
        }
    }

    private data class AppBuildInfo(
        val packageName: String,
        val versionName: String,
        val versionCode: Long,
        val matrixId: String,
        val sampleCompat: Boolean,
        val matrixTargetSdk: Int,
        val androidRelease: String,
        val androidSdk: Int
    )

    private data class PrintExecutionResult(
        val success: Boolean,
        val errorCode: String = "",
        val errorMessage: String = "",
        val errorDetails: String? = null
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        bootstrapNativePrinterEnvironment(trigger = "onCreate")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPairedBluetoothPrinters" -> getPairedBluetoothPrinters(result)
                    "printRawReceipt" -> printRawReceipt(call, result)
                    "appendDebugLog" -> appendDebugLog(call, result)
                    "getDebugLogPath" -> result.success(getDebugLogFile().absolutePath)
                    "clearDebugLog" -> clearDebugLog(result)
                    else -> result.notImplemented()
                }
            }
        appendNativeDebugLog(
            scope = "MainActivity",
            message = "Method channel configured"
        )
        appendNativeDebugLog(
            scope = "MainActivity",
            message = "App build info",
            data = buildString {
                append("package=")
                append(appBuildInfo.packageName)
                append(",versionName=")
                append(appBuildInfo.versionName)
                append(",versionCode=")
                append(appBuildInfo.versionCode)
                append(",matrixId=")
                append(appBuildInfo.matrixId)
                append(",sampleCompat=")
                append(appBuildInfo.sampleCompat)
                append(",matrixTargetSdk=")
                append(appBuildInfo.matrixTargetSdk)
                append(",androidRelease=")
                append(appBuildInfo.androidRelease)
                append(",androidSdk=")
                append(appBuildInfo.androidSdk)
            }
        )
        bootstrapNativePrinterEnvironment(trigger = "configureFlutterEngine")
    }

    override fun onDestroy() {
        try {
            bixolonSdkPrinter.shutdown()
        } catch (_: Throwable) {
            // Never throw from shutdown path.
        }
        super.onDestroy()
    }

    private fun resolveAppBuildInfo(): AppBuildInfo {
        return try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(0)
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, 0)
            }
            val resolvedVersionName = packageInfo.versionName?.trim().orEmpty().ifEmpty { "unknown" }
            val resolvedVersionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                packageInfo.versionCode.toLong()
            }

            AppBuildInfo(
                packageName = packageName,
                versionName = resolvedVersionName,
                versionCode = resolvedVersionCode,
                matrixId = BuildConfig.BIXOLON_MATRIX_ID,
                sampleCompat = BuildConfig.BIXOLON_SAMPLE_COMPAT,
                matrixTargetSdk = BuildConfig.BIXOLON_MATRIX_TARGET_SDK,
                androidRelease = Build.VERSION.RELEASE ?: "unknown",
                androidSdk = Build.VERSION.SDK_INT
            )
        } catch (_: Exception) {
            AppBuildInfo(
                packageName = packageName,
                versionName = "unknown",
                versionCode = -1L,
                matrixId = "unknown",
                sampleCompat = false,
                matrixTargetSdk = -1,
                androidRelease = Build.VERSION.RELEASE ?: "unknown",
                androidSdk = Build.VERSION.SDK_INT
            )
        }
    }

    private fun installUnhandledExceptionLogger() {
        if (!uncaughtLoggerInstalled.compareAndSet(false, true)) {
            return
        }
        val previousHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            appendNativeDebugLog(
                scope = "MainActivity.UncaughtException",
                message = "Unhandled throwable observed",
                data = "thread=${thread.name}, ${summarizeThrowable(throwable)}"
            )
            previousHandler?.uncaughtException(thread, throwable)
        }
        appendNativeDebugLog(
            scope = "MainActivity",
            message = "Unhandled exception logger installed"
        )
    }

    private fun bootstrapNativePrinterEnvironment(trigger: String) {
        if (nativeBootstrapInitialized.compareAndSet(false, true)) {
            appendNativeDebugLog(
                scope = "MainActivity",
                message = "Native printer bootstrap start",
                data = "trigger=$trigger"
            )
            enableSampleCompatStrictModeIfNeeded()
            installUnhandledExceptionLogger()
            // Must load the BIXOLON native library before any class in the
            // vendor SDK is touched — LogService.<clinit> calls a native
            // method, and if the .so isn't loaded yet it fails with
            // UnsatisfiedLinkError, permanently poisoning the class and
            // causing every later SDK call to throw NoClassDefFoundError.
            loadBixolonNativeLibrary()
            initializeBixolonVendorLogging()
            appendNativeDebugLog(
                scope = "MainActivity",
                message = "Native printer bootstrap complete",
                data = "trigger=$trigger"
            )
            return
        }

        appendNativeDebugLog(
            scope = "MainActivity",
            message = "Native printer bootstrap already initialized",
            data = "trigger=$trigger"
        )
    }

    private fun enableSampleCompatStrictModeIfNeeded() {
        if (!BuildConfig.BIXOLON_SAMPLE_COMPAT || Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            return
        }
        StrictMode.setThreadPolicy(
            StrictMode.ThreadPolicy.Builder().permitAll().build()
        )
        appendNativeDebugLog(
            scope = "MainActivity",
            message = "Sample-compat StrictMode enabled"
        )
    }

    private fun appendDebugLog(call: MethodCall, result: MethodChannel.Result) {
        val scope = (call.argument<String>("scope") ?: "Flutter").trim().ifEmpty { "Flutter" }
        val message = (call.argument<String>("message") ?: "").trim()
        val timestamp = (call.argument<String>("timestamp") ?: "").trim()
        val data = (call.argument<String>("data") ?: "").trim()

        appendNativeDebugLog(
            scope = scope,
            message = message.ifEmpty { "No message provided by Flutter logger" },
            timestampOverride = timestamp,
            data = data
        )
        result.success(true)
    }

    private fun loadBixolonNativeLibrary() {
        if (!bixolonNativeLibraryLoadAttempted.compareAndSet(false, true)) {
            return
        }
        try {
            System.loadLibrary("bxl_common")
            bixolonNativeLibraryLoaded = true
            appendNativeDebugLog(
                scope = "MainActivity",
                message = "Bixolon native library loaded",
                data = "lib=bxl_common"
            )
        } catch (t: Throwable) {
            appendNativeDebugLog(
                scope = "MainActivity",
                message = "Bixolon native library load failed",
                data = "${t::class.java.name}: ${t.message}"
            )
        }
    }

    private fun initializeBixolonVendorLogging() {
        if (!vendorLoggingInitialized.compareAndSet(false, true)) {
            return
        }
        if (!bixolonNativeLibraryLoaded) {
            // Touching LogService without the native library bound will
            // permanently poison its class init via UnsatisfiedLinkError,
            // breaking every later BXLConfigLoader/POSPrinter call. Skip.
            appendNativeDebugLog(
                scope = "MainActivity",
                message = "Bixolon vendor logging skipped (native lib not loaded)"
            )
            return
        }
        try {
            val logDir = File(getExternalFilesDir(null) ?: filesDir, "bixolon-sdk-log")
            if (!logDir.exists()) {
                logDir.mkdirs()
            }
            val logPath = "${logDir.absolutePath}${File.separator}"
            LogService.InitDebugLog(
                true,
                true,
                BXLCommonConst._LOG_LEVEL_HIGH,
                128,
                128,
                (1024 * 1024) * 10,
                0,
                logPath,
                "marnisi_bixolon_sdk.log"
            )
            appendNativeDebugLog(
                scope = "MainActivity",
                message = "Bixolon vendor logging initialized",
                data = "path=${logDir.absolutePath}/marnisi_bixolon_sdk.log"
            )
        } catch (t: Throwable) {
            appendNativeDebugLog(
                scope = "MainActivity",
                message = "Bixolon vendor logging init failed",
                data = "${t::class.java.name}: ${t.message}"
            )
        }
    }

    private fun clearDebugLog(result: MethodChannel.Result) {
        try {
            synchronized(debugLogLock) {
                val file = getDebugLogFile()
                if (file.exists()) {
                    file.delete()
                }
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("CLEAR_DEBUG_LOG_FAILED", e.localizedMessage, null)
        }
    }

    private fun getDebugLogFile(): File {
        val baseDir = getExternalFilesDir(null) ?: filesDir
        val logDir = File(baseDir, "logs")
        if (!logDir.exists()) {
            logDir.mkdirs()
        }
        val logFile = File(logDir, "marnisi_printer_debug.log")
        rotateDebugLogIfNeeded(logFile)
        return logFile
    }

    private fun rotateDebugLogIfNeeded(logFile: File) {
        if (!logFile.exists()) {
            return
        }
        val maxBytes = 2L * 1024L * 1024L
        if (logFile.length() <= maxBytes) {
            return
        }
        val rotated = File(logFile.parentFile, "marnisi_printer_debug.log.1")
        if (rotated.exists()) {
            rotated.delete()
        }
        logFile.renameTo(rotated)
    }

    private fun appendNativeDebugLog(
        scope: String,
        message: String,
        timestampOverride: String = "",
        data: String = ""
    ) {
        synchronized(debugLogLock) {
            try {
                val file = getDebugLogFile()
                val ts = if (timestampOverride.isNotEmpty()) {
                    timestampOverride
                } else {
                    SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US).format(Date())
                }
                val line = buildString {
                    append(ts)
                    append(" [")
                    append(scope)
                    append("] ")
                    append(message)
                    if (data.isNotEmpty()) {
                        append(" | data=")
                        append(data)
                    }
                }
                FileWriter(file, true).use { writer ->
                    writer.appendLine(line)
                }
            } catch (_: Exception) {
                // Never throw from debug logger path.
            }
        }
    }

    private fun getPairedBluetoothPrinters(result: MethodChannel.Result) {
        appendNativeDebugLog(
            scope = "MainActivity.getPairedBluetoothPrinters",
            message = "Started paired-printer lookup"
        )
        if (!hasBluetoothRuntimePermissions()) {
            if (pendingPermissionCallback != null) {
                appendNativeDebugLog(
                    scope = "MainActivity.getPairedBluetoothPrinters",
                    message = "Permission request already in progress"
                )
                result.error(
                    "REQUEST_IN_PROGRESS",
                    "Bluetooth permission request is already in progress.",
                    null
                )
                return
            }

            pendingPermissionCallback = { granted ->
                if (granted) {
                    appendNativeDebugLog(
                        scope = "MainActivity.getPairedBluetoothPrinters",
                        message = "Permission granted, loading bonded devices"
                    )
                    result.success(loadBondedPrinterDevices())
                } else {
                    appendNativeDebugLog(
                        scope = "MainActivity.getPairedBluetoothPrinters",
                        message = "Permission denied"
                    )
                    result.error(
                        "BLUETOOTH_PERMISSION_DENIED",
                        "Bluetooth permission denied. Cannot list paired printers.",
                        null
                    )
                }
            }
            requestBluetoothRuntimePermissions()
            return
        }

        appendNativeDebugLog(
            scope = "MainActivity.getPairedBluetoothPrinters",
            message = "Permission available, loading bonded devices"
        )
        result.success(loadBondedPrinterDevices())
    }

    private fun printRawReceipt(call: MethodCall, result: MethodChannel.Result) {
        appendNativeDebugLog(
            scope = "MainActivity.printRawReceipt",
            message = "Print request received"
        )
        if (!hasBluetoothRuntimePermissions()) {
            if (pendingPermissionCallback != null) {
                appendNativeDebugLog(
                    scope = "MainActivity.printRawReceipt",
                    message = "Permission request already in progress"
                )
                result.error(
                    "REQUEST_IN_PROGRESS",
                    "Bluetooth permission request is already in progress.",
                    null
                )
                return
            }

            pendingPermissionCallback = { granted ->
                if (granted) {
                    appendNativeDebugLog(
                        scope = "MainActivity.printRawReceipt",
                        message = "Permission granted, retrying print"
                    )
                    printRawReceipt(call, result)
                } else {
                    appendNativeDebugLog(
                        scope = "MainActivity.printRawReceipt",
                        message = "Permission denied"
                    )
                    result.error(
                        "BLUETOOTH_PERMISSION_DENIED",
                        "Bluetooth permission denied. Cannot print.",
                        null
                    )
                }
            }
            requestBluetoothRuntimePermissions()
            return
        }

        val printerAddress = (call.argument<String>("printerAddress") ?: "").trim()
        val printerName = (call.argument<String>("printerName") ?: "").trim()
        val preferBixolonSdk = call.argument<Boolean>("preferBixolonSdk") ?: false
        val textPayload = (call.argument<String>("text") ?: "").trimEnd()
        if (printerAddress.isEmpty()) {
            appendNativeDebugLog(
                scope = "MainActivity.printRawReceipt",
                message = "Printer address missing"
            )
            result.error("INVALID_PRINTER_ADDRESS", "Printer address is required.", null)
            return
        }

        val payload = call.argument<ByteArray>("data")
        if (payload == null || payload.isEmpty()) {
            appendNativeDebugLog(
                scope = "MainActivity.printRawReceipt",
                message = "Payload missing or empty",
                data = "payloadNull=${payload == null}"
            )
            result.error("INVALID_PRINT_PAYLOAD", "Receipt payload is empty.", null)
            return
        }
        appendNativeDebugLog(
            scope = "MainActivity.printRawReceipt",
            message = "Payload validated",
            data = "printerAddress=$printerAddress, printerName=$printerName, preferBixolonSdk=$preferBixolonSdk, payloadBytes=${payload.size}, textChars=${textPayload.length}"
        )

        val adapter = resolveBluetoothAdapter()
        if (adapter == null || !adapter.isEnabled) {
            appendNativeDebugLog(
                scope = "MainActivity.printRawReceipt",
                message = "Bluetooth adapter unavailable or disabled"
            )
            result.error("BLUETOOTH_UNAVAILABLE", "Bluetooth is unavailable or disabled.", null)
            return
        }

        if (!printInProgress.compareAndSet(false, true)) {
            appendNativeDebugLog(
                scope = "MainActivity.printRawReceipt",
                message = "Print already in progress; rejecting concurrent request"
            )
            result.error(
                "PRINT_ALREADY_IN_PROGRESS",
                "A print job is already in progress.",
                null
            )
            return
        }

        dispatchPrintInBackground(
            adapter = adapter,
            printerAddress = printerAddress,
            printerName = printerName,
            preferBixolonSdk = preferBixolonSdk,
            textPayload = textPayload,
            payload = payload,
            result = result
        )
    }

    private fun dispatchPrintInBackground(
        adapter: BluetoothAdapter,
        printerAddress: String,
        printerName: String,
        preferBixolonSdk: Boolean,
        textPayload: String,
        payload: ByteArray,
        result: MethodChannel.Result
    ) {
        appendNativeDebugLog(
            scope = "MainActivity.printRawReceipt",
            message = "Dispatching print work to background thread",
            data = "printerAddress=$printerAddress, printerName=$printerName, preferBixolonSdk=$preferBixolonSdk, payloadBytes=${payload.size}, textChars=${textPayload.length}"
        )

        printExecutor.execute {
            try {
                val printResult = executePrintRequest(
                    adapter = adapter,
                    printerAddress = printerAddress,
                    printerName = printerName,
                    preferBixolonSdk = preferBixolonSdk,
                    textPayload = textPayload,
                    payload = payload
                )

                appendNativeDebugLog(
                    scope = "MainActivity.printRawReceipt",
                    message = "Background print completed",
                    data = "success=${printResult.success}, errorCode=${printResult.errorCode}"
                )

                runOnUiThread {
                    if (printResult.success) {
                        result.success(true)
                    } else {
                        result.error(
                            printResult.errorCode,
                            printResult.errorMessage,
                            printResult.errorDetails
                        )
                    }
                }
            } finally {
                printInProgress.set(false)
            }
        }
    }

    private fun executePrintRequest(
        adapter: BluetoothAdapter,
        printerAddress: String,
        printerName: String,
        preferBixolonSdk: Boolean,
        textPayload: String,
        payload: ByteArray
    ): PrintExecutionResult {
        return try {
            val targetDevice = adapter.bondedDevices
                ?.firstOrNull { device ->
                    val address = (device.address ?: "").trim()
                    val name = (device.name ?: "").trim()
                    address.equals(printerAddress, ignoreCase = true) ||
                        name.equals(printerAddress, ignoreCase = true)
                }

            if (targetDevice == null) {
                appendNativeDebugLog(
                    scope = "MainActivity.printRawReceipt",
                    message = "Target printer not paired",
                    data = "printerAddress=$printerAddress"
                )
                return PrintExecutionResult(
                    success = false,
                    errorCode = "PRINTER_NOT_PAIRED",
                    errorMessage = "Selected printer is not paired on this Android device."
                )
            }

            appendNativeDebugLog(
                scope = "MainActivity.printRawReceipt",
                message = "Target printer resolved",
                data = "name=${targetDevice.name ?: ""}, address=${targetDevice.address ?: ""}"
            )
            cancelDiscoverySafely(adapter)
            val resolvedAddress = (targetDevice.address ?: "").ifEmpty { printerAddress }
            val resolvedName = printerName.ifEmpty { targetDevice.name ?: "" }
            val isLikelyBixolonModel = resolvedName.uppercase(Locale.US).contains("BIXOLON") ||
                resolvedName.uppercase(Locale.US).contains("SPP-") ||
                resolvedName.uppercase(Locale.US).contains("SRP-")
            val shouldTryBixolonSdk = preferBixolonSdk && isLikelyBixolonModel

            if (shouldTryBixolonSdk) {
                appendNativeDebugLog(
                    scope = "MainActivity.printRawReceipt",
                    message = "Attempting Bixolon SDK print path",
                    data = "resolvedName=$resolvedName, resolvedAddress=$resolvedAddress, textChars=${textPayload.length}"
                )
                val sdkResult = bixolonSdkPrinter.printReceipt(
                    selectedPrinterName = resolvedName,
                    printerAddress = resolvedAddress,
                    text = textPayload
                )

                if (sdkResult.success) {
                    appendNativeDebugLog(
                        scope = "MainActivity.printRawReceipt",
                        message = "Receipt sent via Bixolon SDK",
                        data = "resolvedAddress=$resolvedAddress"
                    )
                    return PrintExecutionResult(success = true)
                }

                appendNativeDebugLog(
                    scope = "MainActivity.printRawReceipt",
                    message = "Bixolon SDK print failed; not falling back to RFCOMM",
                    data = "errorCode=${sdkResult.errorCode}, message=${sdkResult.message}"
                )
                return PrintExecutionResult(
                    success = false,
                    errorCode = sdkResult.errorCode.ifBlank { "BIXOLON_SDK_FAILED" },
                    errorMessage = sdkResult.message.ifBlank { "BIXOLON SDK print failed." },
                    errorDetails = sdkResult.details
                )
            }

            appendNativeDebugLog(
                scope = "MainActivity.printRawReceipt",
                message = "Using RFCOMM print path",
                data = "resolvedName=$resolvedName, resolvedAddress=$resolvedAddress"
            )
            writeReceiptBytes(targetDevice, payload)
            appendNativeDebugLog(
                scope = "MainActivity.printRawReceipt",
                message = "Receipt bytes sent via RFCOMM",
                data = "payloadBytes=${payload.size}"
            )
            PrintExecutionResult(success = true)
        } catch (e: SecurityException) {
            appendNativeDebugLog(
                scope = "MainActivity.printRawReceipt",
                message = "SecurityException while printing",
                data = e.localizedMessage ?: "no details"
            )
            PrintExecutionResult(
                success = false,
                errorCode = "BLUETOOTH_PERMISSION_DENIED",
                errorMessage = "Bluetooth permission denied while printing.",
                errorDetails = e.localizedMessage
            )
        } catch (e: IOException) {
            appendNativeDebugLog(
                scope = "MainActivity.printRawReceipt",
                message = "IOException while printing",
                data = e.localizedMessage ?: "no details"
            )
            PrintExecutionResult(
                success = false,
                errorCode = "PRINT_WRITE_FAILED",
                errorMessage = "Could not send data to printer.",
                errorDetails = e.localizedMessage
            )
        } catch (e: Exception) {
            appendNativeDebugLog(
                scope = "MainActivity.printRawReceipt",
                message = "Unexpected exception while printing",
                data = e.localizedMessage ?: e.toString()
            )
            PrintExecutionResult(
                success = false,
                errorCode = "PRINT_FAILED",
                errorMessage = "Printer operation failed.",
                errorDetails = e.localizedMessage
            )
        } catch (t: Throwable) {
            appendNativeDebugLog(
                scope = "MainActivity.printRawReceipt",
                message = "Fatal Throwable while printing",
                data = summarizeThrowable(t)
            )
            PrintExecutionResult(
                success = false,
                errorCode = "PRINT_FATAL_THROWABLE",
                errorMessage = "Printer operation failed with a fatal native error.",
                errorDetails = t.localizedMessage ?: t.javaClass.simpleName
            )
        }
    }

    private fun summarizeThrowable(t: Throwable): String {
        val reason = t.localizedMessage?.trim().orEmpty().ifEmpty { "no details" }
        val stack = t.stackTraceToString()
            .replace("\r", "")
            .replace("\n", "\\n")
        return "${t.javaClass.name}: $reason | stack=$stack".take(6_000)
    }

    @Throws(IOException::class)
    private fun writeReceiptBytes(device: BluetoothDevice, payload: ByteArray) {
        var socket: BluetoothSocket? = null
        try {
            appendNativeDebugLog(
                scope = "MainActivity.writeReceiptBytes",
                message = "Opening RFCOMM socket",
                data = "device=${device.name ?: ""}, address=${device.address ?: ""}"
            )
            socket = device.createRfcommSocketToServiceRecord(BLUETOOTH_SPP_UUID)
            socket.connect()
            appendNativeDebugLog(
                scope = "MainActivity.writeReceiptBytes",
                message = "Socket connected"
            )
            val output = socket.outputStream

            // ESC @ (initialize) and ESC t 19 (code page 858 - Euro)
            output.write(byteArrayOf(0x1B, 0x40, 0x1B, 0x74, 0x13))
            output.write(payload)
            output.write(byteArrayOf(0x0A, 0x0A, 0x0A))
            output.flush()
            appendNativeDebugLog(
                scope = "MainActivity.writeReceiptBytes",
                message = "Output stream flushed",
                data = "payloadBytes=${payload.size}"
            )
        } finally {
            try {
                socket?.close()
                appendNativeDebugLog(
                    scope = "MainActivity.writeReceiptBytes",
                    message = "Socket closed"
                )
            } catch (_: IOException) {
                // Ignore close failures.
                appendNativeDebugLog(
                    scope = "MainActivity.writeReceiptBytes",
                    message = "Socket close failed"
                )
            }
        }
    }

    private fun loadBondedPrinterDevices(): List<Map<String, String>> {
        val adapter = resolveBluetoothAdapter() ?: return emptyList()
        val devices = adapter.bondedDevices ?: return emptyList()
        appendNativeDebugLog(
            scope = "MainActivity.loadBondedPrinterDevices",
            message = "Bonded devices loaded",
            data = "count=${devices.size}"
        )

        return devices
            .mapNotNull { device ->
                val address = (device.address ?: "").trim()
                if (address.isEmpty()) {
                    return@mapNotNull null
                }
                mapOf(
                    "name" to (device.name ?: "").trim(),
                    "address" to address
                )
            }
            .sortedBy { device ->
                val name = (device["name"] ?: "").lowercase()
                val address = (device["address"] ?: "").lowercase()
                "$name::$address"
            }
    }

    private fun resolveBluetoothAdapter(): BluetoothAdapter? {
        val manager = getSystemService(BLUETOOTH_SERVICE) as? BluetoothManager
        return manager?.adapter ?: BluetoothAdapter.getDefaultAdapter()
    }

    private fun requiresBluetoothRuntimePermissions(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
    }

    private fun requiredBluetoothPermissions(): Array<String> {
        val permissions = linkedSetOf<String>()
        if (BuildConfig.BIXOLON_SAMPLE_COMPAT) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                permissions += Manifest.permission.READ_EXTERNAL_STORAGE
                permissions += Manifest.permission.WRITE_EXTERNAL_STORAGE
                permissions += Manifest.permission.ACCESS_COARSE_LOCATION
                permissions += Manifest.permission.ACCESS_FINE_LOCATION
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                permissions += Manifest.permission.BLUETOOTH_CONNECT
                permissions += Manifest.permission.BLUETOOTH_SCAN
            }
        } else if (requiresBluetoothRuntimePermissions()) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                permissions += Manifest.permission.BLUETOOTH_CONNECT
                permissions += Manifest.permission.BLUETOOTH_SCAN
            }
        }
        return permissions.toTypedArray()
    }

    private fun hasBluetoothRuntimePermissions(): Boolean {
        val permissions = requiredBluetoothPermissions()
        if (permissions.isEmpty()) {
            return true
        }
        return permissions.all { permission ->
            ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun hasBluetoothScanPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return true
        }
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.BLUETOOTH_SCAN
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestBluetoothRuntimePermissions() {
        val permissions = requiredBluetoothPermissions()
        if (permissions.isEmpty()) {
            pendingPermissionCallback?.invoke(true)
            pendingPermissionCallback = null
            return
        }
        appendNativeDebugLog(
            scope = "MainActivity",
            message = "Requesting bluetooth runtime permissions",
            data = permissions.joinToString(separator = ",")
        )
        ActivityCompat.requestPermissions(
            this,
            permissions,
            REQUEST_BT_CONNECT_PERMISSION
        )
    }

    private fun cancelDiscoverySafely(adapter: BluetoothAdapter) {
        if (!hasBluetoothScanPermission()) {
            appendNativeDebugLog(
                scope = "MainActivity.printRawReceipt",
                message = "Skipping cancelDiscovery due to missing BLUETOOTH_SCAN permission"
            )
            return
        }

        try {
            val cancelled = adapter.cancelDiscovery()
            appendNativeDebugLog(
                scope = "MainActivity.printRawReceipt",
                message = "cancelDiscovery invoked",
                data = "cancelled=$cancelled"
            )
        } catch (e: SecurityException) {
            appendNativeDebugLog(
                scope = "MainActivity.printRawReceipt",
                message = "cancelDiscovery SecurityException",
                data = e.localizedMessage ?: "no details"
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode != REQUEST_BT_CONNECT_PERMISSION) {
            return
        }

        val callback = pendingPermissionCallback ?: return
        pendingPermissionCallback = null

        val permissionResults = permissions
            .mapIndexed { index, permission ->
                val granted = grantResults.getOrNull(index) == PackageManager.PERMISSION_GRANTED
                "$permission=$granted"
            }
            .joinToString(separator = ",")
        val permissionGranted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        appendNativeDebugLog(
            scope = "MainActivity.onRequestPermissionsResult",
            message = "Bluetooth permission callback resolved",
            data = "permissionGranted=$permissionGranted, permissions=$permissionResults"
        )

        callback(permissionGranted)
    }
}

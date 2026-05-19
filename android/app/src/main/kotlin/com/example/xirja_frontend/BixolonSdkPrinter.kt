package com.example.xirja_frontend

import android.content.Context
import android.content.ContextWrapper
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import com.bxl.config.editor.BXLConfigLoader
import jpos.POSPrinter
import jpos.POSPrinterConst
import jpos.events.DirectIOEvent
import jpos.events.DirectIOListener
import jpos.events.ErrorEvent
import jpos.events.ErrorListener
import jpos.events.OutputCompleteEvent
import jpos.events.OutputCompleteListener
import jpos.events.StatusUpdateEvent
import jpos.events.StatusUpdateListener
import java.io.File
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

data class BixolonPrintResult(
    val success: Boolean,
    val errorCode: String = "",
    val message: String = "",
    val details: String = ""
)

class BixolonSdkPrinter(
    private val context: Context,
    private val logger: (scope: String, message: String, data: String) -> Unit
) {
    companion object {
        private const val LOG_SCOPE = "BixolonSdkPrinter"
        private const val CLAIM_TIMEOUT_MS = 10_000
        private const val SDK_WARMUP_TIMEOUT_SECONDS = 15L
        private const val SDK_LOGICAL_NAME_SPP_R310 = "SPP-R310"
        // ESC |N — JavaPOS "Normal" reset prefix; matches the Bixolon sample's
        // EscapeSequence.getString(0) used before every printNormal call.
        private const val ESC_NORMAL_RESET = "|N"
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val initializationLock = Any()

    @Volatile
    private var configLoader: BXLConfigLoader? = null

    @Volatile
    private var posPrinter: POSPrinter? = null

    @Volatile
    private var isSdkPrepared = false

    @Volatile
    private var lastErrorEvent: ErrorEvent? = null

    @Volatile
    private var activeLogicalName: String? = null

    @Volatile
    private var activePrinterAddress: String? = null

    @Volatile
    private var isPrinterOpened = false

    @Volatile
    private var isPrinterClaimed = false

    @Volatile
    private var isPrinterEnabled = false

    fun warmUp(): BixolonPrintResult {
        return try {
            ensureSdkPrepared()
            BixolonPrintResult(success = true)
        } catch (t: Throwable) {
            logger(
                LOG_SCOPE,
                "SDK warm-up failed",
                "${t::class.java.name}: ${t.message}\n${t.stackTraceToString()}"
            )
            BixolonPrintResult(
                success = false,
                errorCode = "BIXOLON_SDK_WARMUP_FAILED",
                message = t.message ?: t::class.java.simpleName,
                details = t.stackTraceToString()
            )
        }
    }

    fun shutdown() {
        synchronized(initializationLock) {
            closeActiveSessionQuietly(reason = "shutdown")
            isSdkPrepared = false
            configLoader = null
            posPrinter = null
        }
    }

    fun printReceipt(
        selectedPrinterName: String,
        printerAddress: String,
        text: String
    ): BixolonPrintResult {
        val printData = text.trimEnd()
        if (printData.isBlank()) {
            val msg = "Text payload is blank; nothing to print."
            logger(LOG_SCOPE, "SDK print failed", msg)
            return BixolonPrintResult(
                success = false,
                errorCode = "BIXOLON_SDK_FAILED",
                message = msg
            )
        }
        val modelName = resolveModelName()
        val logicalName = buildLogicalName(modelName, printerAddress)

        return try {
            val productName = resolveProductName(modelName)
            logger(
                LOG_SCOPE,
                "Preparing SDK print session",
                "selectedPrinterName=$selectedPrinterName, modelName=$modelName, logicalName=$logicalName, address=$printerAddress, textChars=${printData.length}"
            )
            printWithLifecycle(
                logicalName = logicalName,
                productName = productName,
                printerAddress = printerAddress,
                printData = printData
            )
        } catch (t: Throwable) {
            logger(
                LOG_SCOPE,
                "SDK print failed",
                "${t::class.java.name}: ${t.message}\n${t.stackTraceToString()}"
            )
            BixolonPrintResult(
                success = false,
                errorCode = "BIXOLON_SDK_FAILED",
                message = t.message ?: t::class.java.simpleName,
                details = t.stackTraceToString()
            )
        }
    }

    private fun printWithLifecycle(
        logicalName: String,
        productName: String,
        printerAddress: String,
        printData: String
    ): BixolonPrintResult {
        ensureSdkPrepared()

        try {
            lastErrorEvent = null
            val printer = ensurePrinterSession(
                logicalName = logicalName,
                productName = productName,
                printerAddress = printerAddress
            )

            // Sample parity: prepend an ESC |N "normal" reset so the printer
            // starts each receipt in a known state, then append a small feed.
            val finalPrintData = buildString {
                append(EscapeSequencePrefix)
                append(ESC_NORMAL_RESET)
                append(printData)
                append("\n\n\n")
            }
            logger(LOG_SCOPE, "POSPrinter.printNormal", "chars=${finalPrintData.length}")
            // Sync mode (setAsyncMode(false) at open time): printNormal blocks
            // until the SDK finishes the job and throws JposException on error.
            printer.printNormal(POSPrinterConst.PTR_S_RECEIPT, finalPrintData)
            logger(LOG_SCOPE, "POSPrinter.printNormal success", "")

            val asyncErr = lastErrorEvent
            if (asyncErr != null) {
                lastErrorEvent = null
                val detail =
                    "errorCode=${asyncErr.errorCode}, errorCodeExtended=${asyncErr.errorCodeExtended}, locus=${asyncErr.errorLocus}, response=${asyncErr.errorResponse}"
                logger(LOG_SCOPE, "POSPrinter async error after printNormal", detail)
                closeActiveSessionQuietly(reason = "async_error_event")
                return BixolonPrintResult(
                    success = false,
                    errorCode = "BIXOLON_PRINTER_ERROR",
                    message = "Printer reported an error event.",
                    details = detail
                )
            }

            return BixolonPrintResult(success = true)
        } catch (t: Throwable) {
            closeActiveSessionQuietly(reason = "print_failure")
            logger(
                LOG_SCOPE,
                "SDK lifecycle failed",
                "${t::class.java.name}: ${t.message}\n${t.stackTraceToString()}"
            )
            return BixolonPrintResult(
                success = false,
                errorCode = "BIXOLON_SDK_LIFECYCLE_FAILED",
                message = t.message ?: t::class.java.simpleName,
                details = t.stackTraceToString()
            )
        }
    }

    private val EscapeSequencePrefix: String
        get() = String(byteArrayOf(0x1B, 0x7C))

    fun printSampleReceipt(
        selectedPrinterName: String,
        printerAddress: String
    ): BixolonPrintResult {
        val now = System.currentTimeMillis()
        val sampleLines = buildString {
            appendLine("MARNISI BIXOLON SDK SAMPLE")
            appendLine("Printer: $selectedPrinterName")
            appendLine("Address: $printerAddress")
            appendLine("Epoch: $now")
            appendLine("------------------------------")
            appendLine("1 x Sample Item      EUR 1.00")
            appendLine("TOTAL                EUR 1.00")
            appendLine("Payment: Card BOV")
            appendLine("THANK YOU")
            appendLine()
        }
        return printReceipt(
            selectedPrinterName = selectedPrinterName,
            printerAddress = printerAddress,
            text = sampleLines
        )
    }

    private fun buildLogicalName(modelName: String, printerAddress: String): String {
        return SDK_LOGICAL_NAME_SPP_R310
    }

    private fun configureLogicalEntry(
        logicalName: String,
        productName: String,
        printerAddress: String
    ) {
        val configLoader = configLoader
            ?: throw IllegalStateException("BXLConfigLoader is not initialized.")

        logger(
            LOG_SCOPE,
            "Using prepared Bixolon config loader",
            "logicalName=$logicalName, printerAddress=$printerAddress"
        )

        try {
            logger(LOG_SCOPE, "BXLConfigLoader.getEntries start", "")
            configLoader.getEntries()
                .firstOrNull { entry -> entry.logicalName == logicalName }
                ?.let {
                    configLoader.removeEntry(logicalName)
                    logger(
                        LOG_SCOPE,
                        "Removed stale logical entry",
                        "logicalName=$logicalName"
                    )
                }
            logger(LOG_SCOPE, "BXLConfigLoader.getEntries success", "")
        } catch (e: Exception) {
            logger(
                LOG_SCOPE,
                "Could not inspect existing config entries",
                "error=${e.localizedMessage ?: e.javaClass.simpleName}"
            )
        }

        logger(
            LOG_SCOPE,
            "BXLConfigLoader.addEntry start",
            "logicalName=$logicalName, productName=$productName, address=$printerAddress"
        )
        configLoader.addEntry(
            logicalName,
            BXLConfigLoader.DEVICE_CATEGORY_POS_PRINTER,
            productName,
            BXLConfigLoader.DEVICE_BUS_BLUETOOTH,
            printerAddress
        )
        logger(LOG_SCOPE, "BXLConfigLoader.addEntry success", "")
        logConfigEnvironment(
            stage = "before_save_file",
            logicalName = logicalName,
            printerAddress = printerAddress
        )
        logger(LOG_SCOPE, "BXLConfigLoader.saveFile start", "")
        configLoader.saveFile()
        logger(LOG_SCOPE, "BXLConfigLoader.saveFile success", "")
        logConfigEnvironment(
            stage = "after_save_file",
            logicalName = logicalName,
            printerAddress = printerAddress
        )
        logger(
            LOG_SCOPE,
            "Saved logical entry",
            "logicalName=$logicalName, productName=$productName, address=$printerAddress"
        )
    }

    private fun resolveModelName(): String {
        return SDK_LOGICAL_NAME_SPP_R310
    }

    private fun resolveProductName(modelName: String): String {
        return when (modelName.uppercase(Locale.US)) {
            "SPP-R310" -> BXLConfigLoader.PRODUCT_NAME_SPP_R310
            else -> throw IllegalArgumentException(
                "Unsupported BIXOLON model for SDK printing: $modelName"
            )
        }
    }

    private fun ensureSdkPrepared() {
        if (isSdkPrepared) {
            return
        }

        synchronized(initializationLock) {
            if (isSdkPrepared) {
                return
            }

            if (Looper.myLooper() == Looper.getMainLooper()) {
                initializeSdkComponents()
                return
            }

            logger(
                LOG_SCOPE,
                "SDK warm-up dispatching to main thread",
                "thread=${Thread.currentThread().name}"
            )
            val latch = CountDownLatch(1)
            var failure: Throwable? = null
            mainHandler.post {
                try {
                    initializeSdkComponents()
                } catch (t: Throwable) {
                    failure = t
                } finally {
                    latch.countDown()
                }
            }
            if (!latch.await(SDK_WARMUP_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
                throw IllegalStateException(
                    "Timed out waiting for Bixolon SDK warm-up on main thread."
                )
            }
            failure?.let { throw it }
            if (!isSdkPrepared) {
                throw IllegalStateException("Bixolon SDK warm-up completed without initialization.")
            }
        }
    }

    private fun initializeSdkComponents() {
        if (isSdkPrepared) {
            return
        }

        logger(
            LOG_SCOPE,
            "SDK warm-up start",
            "thread=${Thread.currentThread().name}, onMainThread=${Looper.myLooper() == Looper.getMainLooper()}"
        )

        logger(LOG_SCOPE, "POSPrinter constructor start", "")
        val printer = POSPrinter(context)
        logger(
            LOG_SCOPE,
            "POSPrinter constructor success",
            "className=${printer.javaClass.name}"
        )
        registerPrinterListeners(printer)

        logSdkRuntimeState(
            stage = "before_bxl_config_loader_ctor",
            logicalName = "sdk_warmup",
            printerAddress = "n/a"
        )
        logConfigEnvironment(
            stage = "before_bxl_config_loader_ctor",
            logicalName = "sdk_warmup",
            printerAddress = "n/a"
        )
        logger(
            LOG_SCOPE,
            "BXLConfigLoader constructor start",
            "logicalName=sdk_warmup, printerAddress=n/a"
        )
        val loader = BXLConfigLoader(context)
        logger(
            LOG_SCOPE,
            "BXLConfigLoader constructor success",
            "className=${loader.javaClass.name}"
        )
        logConfigEnvironment(
            stage = "after_bxl_config_loader_ctor",
            logicalName = "sdk_warmup",
            printerAddress = "n/a"
        )

        try {
            logger(
                LOG_SCOPE,
                "BXLConfigLoader.openFile start",
                "logicalName=sdk_warmup, printerAddress=n/a"
            )
            logConfigEnvironment(
                stage = "before_open_file",
                logicalName = "sdk_warmup",
                printerAddress = "n/a"
            )
            loader.openFile()
            logger(LOG_SCOPE, "BXLConfigLoader.openFile success", "")
            logConfigEnvironment(
                stage = "after_open_file",
                logicalName = "sdk_warmup",
                printerAddress = "n/a"
            )
        } catch (e: Exception) {
            logger(
                LOG_SCOPE,
                "BXLConfigLoader.openFile failed",
                "${e.javaClass.name}: ${e.localizedMessage ?: "no details"}"
            )
            logConfigEnvironment(
                stage = "open_file_failed_before_new_file",
                logicalName = "sdk_warmup",
                printerAddress = "n/a"
            )
            logger(
                LOG_SCOPE,
                "BXLConfigLoader.newFile start",
                "logicalName=sdk_warmup, printerAddress=n/a"
            )
            loader.newFile()
            logger(LOG_SCOPE, "BXLConfigLoader.newFile success", "")
            logConfigEnvironment(
                stage = "after_new_file",
                logicalName = "sdk_warmup",
                printerAddress = "n/a"
            )
        }

        posPrinter = printer
        configLoader = loader
        isSdkPrepared = true
        logger(
            LOG_SCOPE,
            "SDK warm-up success",
            "posPrinterReady=${posPrinter != null}, configLoaderReady=${configLoader != null}"
        )
    }

    private fun registerPrinterListeners(printer: POSPrinter) {
        logger(LOG_SCOPE, "POSPrinter listener registration start", "")
        printer.addStatusUpdateListener(object : StatusUpdateListener {
            override fun statusUpdateOccurred(event: StatusUpdateEvent?) {
                logger(
                    LOG_SCOPE,
                    "POSPrinter status update",
                    "status=${event?.status ?: -1}"
                )
            }
        })
        printer.addErrorListener(object : ErrorListener {
            override fun errorOccurred(event: ErrorEvent?) {
                if (event != null) {
                    lastErrorEvent = event
                }
                logger(
                    LOG_SCOPE,
                    "POSPrinter error event",
                    "errorCode=${event?.errorCode ?: -1}, errorCodeExtended=${event?.errorCodeExtended ?: -1}, locus=${event?.errorLocus ?: -1}, response=${event?.errorResponse ?: -1}"
                )
            }
        })
        printer.addOutputCompleteListener(object : OutputCompleteListener {
            override fun outputCompleteOccurred(event: OutputCompleteEvent?) {
                logger(
                    LOG_SCOPE,
                    "POSPrinter output complete",
                    "outputId=${event?.outputID ?: -1}"
                )
            }
        })
        printer.addDirectIOListener(object : DirectIOListener {
            override fun directIOOccurred(event: DirectIOEvent?) {
                logger(
                    LOG_SCOPE,
                    "POSPrinter direct IO event",
                    "eventNumber=${event?.eventNumber ?: -1}, data=${event?.data ?: -1}, object=${event?.getObject() ?: "null"}"
                )
            }
        })
        logger(LOG_SCOPE, "POSPrinter listener registration success", "")
    }

    private fun ensurePrinterSession(
        logicalName: String,
        productName: String,
        printerAddress: String
    ): POSPrinter {
        synchronized(initializationLock) {
            val printer = posPrinter
                ?: throw IllegalStateException("POSPrinter is not initialized.")

            val sessionMatches = activeLogicalName == logicalName &&
                activePrinterAddress.equals(printerAddress, ignoreCase = true)

            if (sessionMatches && isPrinterOpened && isPrinterClaimed && isPrinterEnabled) {
                logger(
                    LOG_SCOPE,
                    "Reusing active printer session",
                    "logicalName=$logicalName, printerAddress=$printerAddress"
                )
                return printer
            }

            if (isPrinterOpened || isPrinterClaimed || isPrinterEnabled) {
                closeActiveSessionQuietly(reason = "session_reconfigure")
            }

            logger(LOG_SCOPE, "Config openFile/newFile", "logicalName=$logicalName")
            configureLogicalEntry(
                logicalName = logicalName,
                productName = productName,
                printerAddress = printerAddress
            )

            logger(
                LOG_SCOPE,
                "POSPrinter.open",
                "logicalName=$logicalName, thread=${Thread.currentThread().name}, onMainThread=${Looper.myLooper() == Looper.getMainLooper()}"
            )
            printer.open(logicalName)
            isPrinterOpened = true
            logger(
                LOG_SCOPE,
                "POSPrinter.open success",
                listOf(
                    "logicalName=$logicalName",
                    "deviceServiceVersion=${safePrinterValue { printer.deviceServiceVersion.toString() }}",
                    "deviceServiceDescription=${safePrinterValue { printer.deviceServiceDescription }}",
                    "physicalDeviceName=${safePrinterValue { printer.physicalDeviceName }}",
                    "physicalDeviceDescription=${safePrinterValue { printer.physicalDeviceDescription }}"
                ).joinToString(" | ")
            )

            logger(LOG_SCOPE, "POSPrinter.claim", "timeoutMs=$CLAIM_TIMEOUT_MS")
            printer.claim(CLAIM_TIMEOUT_MS)
            isPrinterClaimed = true
            logger(LOG_SCOPE, "POSPrinter.claim success", "timeoutMs=$CLAIM_TIMEOUT_MS")

            logger(LOG_SCOPE, "POSPrinter.setDeviceEnabled(true)", "")
            printer.setDeviceEnabled(true)
            isPrinterEnabled = true
            logger(LOG_SCOPE, "POSPrinter.setDeviceEnabled(true) success", "")

            // Sample parity: sync mode (printNormal blocks and throws on error).
            // setCharacterSet / setCharacterEncoding are intentionally not
            // called — the Bixolon sample never sets them and on SPP-R310 some
            // combinations silently leave the printer unable to print.
            logger(LOG_SCOPE, "POSPrinter.setAsyncMode", "enabled=false")
            printer.setAsyncMode(false)

            activeLogicalName = logicalName
            activePrinterAddress = printerAddress
            logger(
                LOG_SCOPE,
                "Printer session established",
                "logicalName=$logicalName, productName=$productName, printerAddress=$printerAddress"
            )
            return printer
        }
    }

    private fun closeActiveSessionQuietly(reason: String) {
        val printer = posPrinter ?: return
        logger(LOG_SCOPE, "POSPrinter shutdown start", "reason=$reason")
        try {
            if (isPrinterEnabled) {
                printer.setDeviceEnabled(false)
            }
        } catch (t: Throwable) {
            logger(LOG_SCOPE, "Failed disabling printer during shutdown", t.stackTraceToString())
        }
        try {
            if (isPrinterClaimed) {
                printer.release()
            }
        } catch (t: Throwable) {
            logger(LOG_SCOPE, "Failed releasing printer during shutdown", t.stackTraceToString())
        }
        try {
            if (isPrinterOpened) {
                printer.close()
            }
        } catch (t: Throwable) {
            logger(LOG_SCOPE, "Failed closing printer during shutdown", t.stackTraceToString())
        }
        lastErrorEvent = null
        isPrinterEnabled = false
        isPrinterClaimed = false
        isPrinterOpened = false
        activeLogicalName = null
        activePrinterAddress = null
    }

    private fun logConfigEnvironment(
        stage: String,
        logicalName: String,
        printerAddress: String
    ) {
        logger(
            LOG_SCOPE,
            "Config environment",
            listOf(
                "stage=$stage",
                "pkg=${context.packageName}",
                "logicalName=$logicalName",
                "printerAddress=$printerAddress",
                "thread=${Thread.currentThread().name}",
                "filesDir=${describeDir(context.filesDir)}",
                "cacheDir=${describeDir(context.cacheDir)}",
                "noBackupDir=${describeDir(context.noBackupFilesDir)}",
                "externalFilesDir=${describeDir(context.getExternalFilesDir(null))}",
                "externalCacheDir=${describeDir(context.externalCacheDir)}"
            ).joinToString(" | ")
        )
        logger(
            LOG_SCOPE,
            "Config interesting files",
            "stage=$stage | ${collectInterestingFiles()}"
        )
    }

    private fun logSdkRuntimeState(
        stage: String,
        logicalName: String,
        printerAddress: String
    ) {
        val appInfo = context.applicationInfo
        val nativeLibraryDir = appInfo?.nativeLibraryDir.orEmpty()
        val nativeLibDirFile = nativeLibraryDir.takeIf { it.isNotBlank() }?.let(::File)
        val mappedBxlLibName = System.mapLibraryName("bxl_common")
        val mappedCommonLibName = System.mapLibraryName("common")

        logger(
            LOG_SCOPE,
            "SDK runtime state",
            listOf(
                "stage=$stage",
                "logicalName=$logicalName",
                "printerAddress=$printerAddress",
                "contextClass=${context.javaClass.name}",
                "applicationContextClass=${context.applicationContext.javaClass.name}",
                "baseContextClass=${(context as? ContextWrapper)?.baseContext?.javaClass?.name ?: "n/a"}",
                "contextClassLoader=${context.javaClass.classLoader}",
                "sdkProbeClassLoader=${sdkProbeClassLoader()}",
                "bxlConfigClassLoader=${safeClassLoaderName(BXLConfigLoader::class.java)}",
                "posPrinterClassLoader=${safeClassLoaderName(POSPrinter::class.java)}",
                "bxlConfigCodeSource=${safeCodeSource(BXLConfigLoader::class.java)}",
                "posPrinterCodeSource=${safeCodeSource(POSPrinter::class.java)}",
                "packageResourcePath=${safeValue { context.packageResourcePath }}",
                "dataDir=${appInfo?.dataDir ?: "unknown"}",
                "nativeLibraryDir=${nativeLibraryDir.ifBlank { "unknown" }}",
                "sourceDir=${appInfo?.sourceDir ?: "unknown"}",
                "publicSourceDir=${appInfo?.publicSourceDir ?: "unknown"}",
                "splitSourceDirs=${appInfo?.splitSourceDirs?.joinToString(",") ?: "none"}",
                "deviceProtectedDataDir=${safeValue { context.createDeviceProtectedStorageContext().dataDir?.absolutePath ?: "null" }}",
                "codeCacheDir=${safeValue { context.codeCacheDir.absolutePath }}",
                "cacheDir=${context.cacheDir.absolutePath}",
                "filesDir=${context.filesDir.absolutePath}",
                "androidRelease=${Build.VERSION.RELEASE}",
                "androidSdk=${Build.VERSION.SDK_INT}",
                "manufacturer=${Build.MANUFACTURER}",
                "brand=${Build.BRAND}",
                "model=${Build.MODEL}",
                "supportedAbis=${Build.SUPPORTED_ABIS.joinToString(",")}",
                "osArch=${System.getProperty("os.arch")}",
                "is64Bit=${safeValue { Process.is64Bit().toString() }}",
                "mappedBxlLibName=$mappedBxlLibName",
                "mappedCommonLibName=$mappedCommonLibName",
                "bxlLibExists=${nativeLibDirFile?.resolve(mappedBxlLibName)?.exists() ?: false}",
                "commonLibExists=${nativeLibDirFile?.resolve(mappedCommonLibName)?.exists() ?: false}"
            ).joinToString(" | ")
        )

        logger(
            LOG_SCOPE,
            "SDK native library dir entries",
            "stage=$stage | ${describeDirEntries(nativeLibDirFile, maxEntries = 40)}"
        )

        logger(
            LOG_SCOPE,
            "SDK reflective probes",
            listOf(
                "stage=$stage",
                safeClassProbe("com.bxl.config.editor.BXLConfigLoader"),
                safeClassProbe("com.bxl.BXLConst"),
                safeClassProbe("jpos.POSPrinter"),
                safeClassProbe("jpos.JposException")
            ).joinToString(" | ")
        )
    }

    private fun describeDir(dir: File?): String {
        if (dir == null) {
            return "null"
        }
        val exists = dir.exists()
        val isDirectory = dir.isDirectory
        val childCount = dir.listFiles()?.size ?: -1
        return "${dir.absolutePath}(exists=$exists,dir=$isDirectory,children=$childCount)"
    }

    private fun describeDirEntries(dir: File?, maxEntries: Int): String {
        if (dir == null) {
            return "null"
        }
        if (!dir.exists()) {
            return "${dir.absolutePath} missing"
        }
        if (!dir.isDirectory) {
            return "${dir.absolutePath} is_not_directory"
        }
        val entries = dir.listFiles().orEmpty()
            .sortedBy { it.name.lowercase(Locale.US) }
            .take(maxEntries)
            .joinToString(", ") { file ->
                "${file.name}(dir=${file.isDirectory},size=${file.length()})"
            }
        return if (entries.isBlank()) {
            "${dir.absolutePath} empty"
        } else {
            "${dir.absolutePath}: $entries"
        }
    }

    private fun collectInterestingFiles(maxEntries: Int = 20): String {
        val roots = listOfNotNull(
            context.filesDir,
            context.noBackupFilesDir,
            context.cacheDir,
            context.getExternalFilesDir(null),
            context.externalCacheDir
        ).distinctBy { it.absolutePath }

        val interesting = mutableListOf<String>()
        for (root in roots) {
            collectInterestingFilesRecursive(
                root = root,
                current = root,
                depth = 0,
                maxDepth = 2,
                results = interesting,
                maxEntries = maxEntries
            )
            if (interesting.size >= maxEntries) {
                break
            }
        }

        return if (interesting.isEmpty()) {
            "no matching files"
        } else {
            interesting.joinToString(", ")
        }
    }

    private fun collectInterestingFilesRecursive(
        root: File,
        current: File,
        depth: Int,
        maxDepth: Int,
        results: MutableList<String>,
        maxEntries: Int
    ) {
        if (results.size >= maxEntries || !current.exists() || !current.isDirectory || depth > maxDepth) {
            return
        }

        val children = current.listFiles().orEmpty().sortedBy { it.name.lowercase(Locale.US) }
        for (child in children) {
            if (results.size >= maxEntries) {
                return
            }
            val lowerName = child.name.lowercase(Locale.US)
            if (
                lowerName.contains("bxl") ||
                lowerName.contains("bix") ||
                lowerName.contains("jpos") ||
                lowerName.contains("config") ||
                lowerName.endsWith(".xml")
            ) {
                val relativePath = child.absolutePath.removePrefix(root.absolutePath).ifEmpty { "/" }
                results += "${root.name}:$relativePath(exists=${child.exists()},dir=${child.isDirectory},size=${child.length()})"
            }
            if (child.isDirectory) {
                collectInterestingFilesRecursive(
                    root = root,
                    current = child,
                    depth = depth + 1,
                    maxDepth = maxDepth,
                    results = results,
                    maxEntries = maxEntries
                )
            }
        }
    }

    private fun safeClassLoaderName(clazz: Class<*>): String {
        return safeValue { clazz.classLoader?.toString() ?: "bootstrap" }
    }

    private fun safeCodeSource(clazz: Class<*>): String {
        return safeValue { clazz.protectionDomain?.codeSource?.location?.toString() ?: "unknown" }
    }

    private fun sdkProbeClassLoader(): String {
        return safeValue {
            (BixolonSdkPrinter::class.java.classLoader
                ?: POSPrinter::class.java.classLoader
                ?: BXLConfigLoader::class.java.classLoader
            )?.toString() ?: "bootstrap"
        }
    }

    private fun safeClassProbe(className: String): String {
        return try {
            val loader = BixolonSdkPrinter::class.java.classLoader
                ?: POSPrinter::class.java.classLoader
                ?: BXLConfigLoader::class.java.classLoader
            val clazz = Class.forName(className, false, loader)
            "$className=loaded(classLoader=${clazz.classLoader ?: "bootstrap"})"
        } catch (t: Throwable) {
            "$className=failed(${t.javaClass.name}:${t.localizedMessage ?: "no details"})"
        }
    }

    private inline fun safePrinterValue(block: () -> String): String {
        return safeValue(block)
    }

    private inline fun safeValue(block: () -> String): String {
        return try {
            block()
        } catch (t: Throwable) {
            "error(${t.javaClass.name}:${t.localizedMessage ?: "no details"})"
        }
    }
}

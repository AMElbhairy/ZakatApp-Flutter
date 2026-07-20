package com.zakahwealth.app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.text.BidiFormatter
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID
import java.util.Locale

object AndroidSmsCaptureBridge {
    private data class ParsedCaptureNotification(
        val title: String,
        val body: String,
        val tapToken: String,
    )

    private data class NativeSmartCaptureStateSnapshot(
        val smartCaptureAutoApproveEnabled: Boolean,
        val languagePreference: String,
        val merchantAliases: Map<String, String>,
        val merchantRules: Map<String, Map<String, Any?>>,
    )

    private const val notificationChannelId = "smart_capture_android_capture"
    private const val notificationChannelName = "Smart Capture"
    private const val notificationIdBase = 0x5A7A0000
    private const val prefsName = "android_sms_capture_prefs"
    private const val enabledKey = "android_sms_auto_capture_enabled"
    private const val smartCaptureStateKey = "android_smart_capture_state_v1"
    private const val queueKey = "android_sms_capture_queue"
    private const val recentCaptureKey = "android_sms_capture_recent_history"
    private const val maxQueueEntries = 100
    private val supportedCurrencyCodes = setOf(
        "EGP",
        "USD",
        "SAR",
        "EUR",
        "GBP",
        "AED",
        "KWD",
        "QAR",
        "BHD",
        "OMR",
        "JOD",
        "TRY",
        "MYR",
        "PKR",
        "IDR",
    )
    private val currencyMarkers = listOf(
        "$",
        "€",
        "£",
        "₺",
        "⃁",
        "﷼",
        "e£",
        "le",
        "l.e",
        "l.e.",
        "ج.م",
        "جنيه",
        "جنيه مصري",
        "ريال",
        "ر.س",
        "sr",
        "s.r",
        "s.r.",
        "درهم",
        "د.إ",
        "دينار",
        "دينار كويتي",
        "دينار بحريني",
        "دينار أردني",
        "دينار عماني",
        "يورو",
        "جنيه استرليني",
        "ليرة",
        "رينجيت",
        "روبية",
        "روبيه",
        "rupiah",
        "dollar",
        "dollars",
        "pound",
        "pounds",
    )

    private var captureChannel: MethodChannel? = null
    private var flutterReady: Boolean = false

    fun attachChannel(channel: MethodChannel?) {
        captureChannel = channel
    }

    fun setFlutterReady(ready: Boolean) {
        flutterReady = ready
    }

    fun isEnabled(context: Context): Boolean {
        return prefs(context).getBoolean(enabledKey, false)
    }

    fun setEnabled(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(enabledKey, enabled).apply()
    }

    fun saveSmartCaptureState(
        context: Context,
        state: Map<String, Any?>?,
    ) {
        if (state == null) return
        try {
            prefs(context).edit()
                .putString(smartCaptureStateKey, JSONObject(state).toString())
                .apply()
        } catch (_: Throwable) {
        }
    }

    fun hasSmsPermission(context: Context): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.RECEIVE_SMS,
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun enqueueOrDeliver(context: Context, payload: Map<String, String>) {
        val channel = captureChannel
        if (!flutterReady || channel == null) {
            val message = payload["messageContent"].orEmpty().trim()
            val parsed = parseCaptureNotification(context, message)
            val queuedPayload = payload + mapOf("notificationAlreadyShown" to "true")
            showFallbackNotification(context, message, parsed)
            queuePayload(context, queuedPayload)
            return
        }
        try {
            channel.invokeMethod("smsMessageReceived", payload)
        } catch (_: Throwable) {
            val message = payload["messageContent"].orEmpty().trim()
            val parsed = parseCaptureNotification(context, message)
            val queuedPayload = payload + mapOf("notificationAlreadyShown" to "true")
            showFallbackNotification(context, message, parsed)
            queuePayload(context, queuedPayload)
        }
    }

    fun enqueueOrDeliverNotificationLaunch(
        context: Context,
        payload: Map<String, String>,
    ) {
        val channel = captureChannel
        if (!flutterReady || channel == null) {
            queuePayload(context, payload)
            return
        }
        try {
            channel.invokeMethod("notificationLaunchReceived", payload)
        } catch (_: Throwable) {
            queuePayload(context, payload)
        }
    }

    private fun showFallbackNotification(
        context: Context,
        message: String,
        parsed: ParsedCaptureNotification,
    ) {
        if (message.isEmpty()) return
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
            return
        }

        ensureNotificationChannel(context)

        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra("notificationTap", "true")
                putExtra("notificationTapToken", parsed.tapToken)
            } ?: Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("notificationTap", "true")
            putExtra("notificationTapToken", parsed.tapToken)
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationIdBase + message.hashCode(),
            launchIntent,
            pendingIntentFlags(),
        )

        val notification = NotificationCompat.Builder(context, notificationChannelId)
            .setSmallIcon(R.drawable.notification_icon)
            .setContentTitle(parsed.title)
            .setContentText(parsed.body)
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .setBigContentTitle(parsed.title)
                    .bigText(parsed.body),
            )
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        NotificationManagerCompat.from(context)
            .notify(notificationIdBase + message.hashCode(), notification)
    }

    private fun parseCaptureNotification(
        context: Context,
        message: String,
    ): ParsedCaptureNotification {
        val state = loadSmartCaptureState(context)
        val languageCode = state?.languagePreference ?: "en"
        val isArabic = languageCode.lowercase(Locale.ROOT).startsWith("ar")
        val amount = extractAmount(message)
        val merchant = extractMerchantName(message)
        val tapToken = UUID.randomUUID().toString()
        val title = nativeCaptureStatusTitle(
            context = context,
            message = message,
            languageCode = languageCode,
            merchant = merchant,
            amount = amount,
            state = state,
        )
        val body = nativeCaptureBody(
            merchant = merchant,
            amount = amount,
            isArabic = isArabic,
            fallbackMessage = message,
        )

        return ParsedCaptureNotification(
            title = title,
            body = body,
            tapToken = tapToken,
        )
    }

    private fun loadSmartCaptureState(context: Context): NativeSmartCaptureStateSnapshot? {
        val raw = prefs(context).getString(smartCaptureStateKey, null) ?: return null
        return try {
            val root = JSONObject(raw)
            val merchantAliases = root.optJSONObject("merchantAliases")
                ?.let { json ->
                    buildMap {
                        val keys = json.keys()
                        while (keys.hasNext()) {
                            val key = keys.next().toString()
                            val value = json.optString(key, "").trim()
                            if (key.isNotBlank() && value.isNotBlank()) {
                                put(key.lowercase(Locale.ROOT).trim(), value)
                            }
                        }
                    }
                }
                ?: emptyMap()
            val merchantRules = root.optJSONObject("merchantRules")
                ?.let { json ->
                    buildMap {
                        val keys = json.keys()
                        while (keys.hasNext()) {
                            val key = keys.next().toString()
                            val rule = json.optJSONObject(key) ?: continue
                            put(
                                key.lowercase(Locale.ROOT).trim(),
                                buildMap {
                                    val ruleKeys = rule.keys()
                                    while (ruleKeys.hasNext()) {
                                        val ruleKey = ruleKeys.next().toString()
                                        put(ruleKey, rule.opt(ruleKey))
                                    }
                                },
                            )
                        }
                    }
                }
                ?: emptyMap()

            NativeSmartCaptureStateSnapshot(
                smartCaptureAutoApproveEnabled =
                    root.optBoolean("smartCaptureAutoApproveEnabled", false),
                languagePreference = root.optString("languagePreference", "en")
                    .trim()
                    .lowercase(Locale.ROOT),
                merchantAliases = merchantAliases,
                merchantRules = merchantRules,
            )
        } catch (_: Throwable) {
            null
        }
    }

    private fun nativeCaptureStatusTitle(
        context: Context,
        message: String,
        languageCode: String,
        merchant: String?,
        amount: String?,
        state: NativeSmartCaptureStateSnapshot?,
    ): String {
        val isArabic = languageCode.lowercase(Locale.ROOT).startsWith("ar")
        val normalized = message.lowercase(Locale.ROOT)

        if (nativeWasRecentlyCaptured(context, message)) {
            return nativeLocalizedLabel(
                english = "Rejected",
                arabic = "مرفوض",
                isArabic = isArabic,
            )
        }

        if (isLikelyOtpOrSecurityMessage(normalized) ||
            nativeContainsRejectionIndicators(normalized)
        ) {
            return nativeLocalizedLabel(
                english = "Rejected",
                arabic = "مرفوض",
                isArabic = isArabic,
            )
        }

        if (nativeContainsAny(normalized, listOf(
                "pending for approval",
                "pending approval",
                "pending review",
                "awaiting approval",
                "awaiting your approval",
                "approval required",
                "requires approval",
                "requires your approval",
                "waiting for approval",
                "بانتظار الموافقة",
                "في انتظار الموافقة",
                "معلق للموافقة",
                "معلّق للموافقة",
                "محتاج موافقة",
            ))
        ) {
            return nativeLocalizedLabel(
                english = "Pending for Approval",
                arabic = "بانتظار الموافقة",
                isArabic = isArabic,
            )
        }

        if (merchant != null &&
            amount != null &&
            state != null &&
            nativeShouldAutoApprove(message, merchant, amount, state)
        ) {
            return nativeLocalizedLabel(
                english = "Auto approved",
                arabic = "موافق عليه تلقائيًا",
                isArabic = isArabic,
            )
        }

        return nativeLocalizedLabel(
            english = "Pending for Approval",
            arabic = "بانتظار الموافقة",
            isArabic = isArabic,
        )
    }

    private fun nativeShouldAutoApprove(
        message: String,
        merchant: String,
        amount: String,
        state: NativeSmartCaptureStateSnapshot,
    ): Boolean {
        if (!state.smartCaptureAutoApproveEnabled) return false
        if (merchant.isBlank() || amount.isBlank()) return false

        val normalized = message.lowercase(Locale.ROOT)
        if (nativeContainsRejectionIndicators(normalized) ||
            nativeLooksLikeTransferMessage(normalized)
        ) {
            return false
        }

        val resolvedMerchant = nativeResolvedMerchant(merchant, state) ?: return false
        val resolvedKey = resolvedMerchant.lowercase(Locale.ROOT).trim()
        val merchantKey = merchant.lowercase(Locale.ROOT).trim()
        val rule = state.merchantRules[resolvedKey] ?: state.merchantRules[merchantKey]
        if (rule != null) {
            val enabled = (rule["enabled"] as? Boolean) ?: true
            val autoApprove = (rule["autoApprove"] as? Boolean) ?: true
            val defaultType = (rule["defaultType"] as? String)
                ?.trim()
                ?.lowercase(Locale.ROOT)
                ?: "expense"
            return enabled && autoApprove && defaultType != "transfer"
        }

        return nativeBuiltInAutoApproveMerchant(resolvedMerchant)
    }

    private fun nativeResolvedMerchant(
        merchant: String,
        state: NativeSmartCaptureStateSnapshot,
    ): String? {
        val trimmed = merchant.trim()
        if (trimmed.isEmpty()) return null
        val lower = trimmed.lowercase(Locale.ROOT)
        state.merchantAliases[lower]?.let { return it }
        for ((alias, canonical) in state.merchantAliases) {
            if (alias.isNotBlank() && lower.contains(alias)) {
                return canonical
            }
        }
        return trimmed
    }

    private fun nativeBuiltInAutoApproveMerchant(merchant: String): Boolean {
        val lowered = merchant.lowercase(Locale.ROOT).trim()
        return listOf(
            "talabat",
            "toyou",
            "hungerstation",
            "jahez",
            "amazon",
            "noon",
            "jarir",
            "uber",
            "careem",
            "nile air",
            "flynas",
            "saudia",
            "fitness time",
            "whoop",
            "fitness plan",
            "stc",
            "mobily",
            "zain",
        ).any { lowered.contains(it) }
    }

    private fun nativeCaptureBody(
        merchant: String?,
        amount: String?,
        isArabic: Boolean,
        fallbackMessage: String,
    ): String {
        val bodyParts = mutableListOf<String>()
        if (!merchant.isNullOrBlank()) {
            bodyParts.add(nativeWrapNotificationLine(merchant, isArabic))
        }
        if (!amount.isNullOrBlank()) {
            bodyParts.add(nativeWrapNotificationLine(amount, isArabic))
        }
        return when {
            bodyParts.isNotEmpty() -> bodyParts.joinToString(separator = "\n")
            else -> nativeWrapNotificationLine(truncateMessage(fallbackMessage), isArabic)
        }
    }

    private fun nativeWrapNotificationLine(text: String, isArabic: Boolean): String {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return trimmed
        return if (isArabic) {
            BidiFormatter.getInstance().unicodeWrap(trimmed)
        } else {
            trimmed
        }
    }

    private fun nativeLocalizedLabel(
        english: String,
        arabic: String,
        isArabic: Boolean,
    ): String {
        return if (isArabic) arabic else english
    }

    private fun nativeContainsAny(text: String, candidates: List<String>): Boolean {
        return candidates.any { candidate -> text.contains(candidate.lowercase(Locale.ROOT)) }
    }

    private fun nativeContainsRejectionIndicators(text: String): Boolean {
        return nativeContainsAny(text, listOf(
            "declined",
            "decline",
            "rejected",
            "reject",
            "failed",
            "failure",
            "unsuccessful",
            "not approved",
            "not authorized",
            "not authorised",
            "authorization failed",
            "authorisation failed",
            "authorization declined",
            "authorisation declined",
            "authorization rejected",
            "authorisation rejected",
            "payment declined",
            "payment failed",
            "transaction declined",
            "transaction failed",
            "card declined",
            "unable to process",
            "unable to complete",
            "could not be completed",
            "cannot be completed",
            "could not process",
            "not completed",
            "failed to process",
            "cancelled",
            "canceled",
            "timeout",
            "expired",
            "blocked",
            "insufficient funds",
            "otp",
            "one time password",
            "one-time password",
            "verification code",
            "confirmation code",
            "security code",
            "authentication code",
            "login code",
            "passcode",
            "رمز التحقق",
            "كود التحقق",
            "رمز لمرة واحدة",
            "الرمز لمرة واحدة",
            "كلمة مرور لمرة واحدة",
            "رمز الاستخدام لمرة واحدة",
            "رمز خاطئ",
            "الرمز غير صحيح",
            "رمز التحقق غير صحيح",
            "انتهت صلاحية الرمز",
            "فشل التحقق",
            "فشل المصادقة",
            "مرفوضة",
            "مرفوض",
            "رفض",
            "تم الرفض",
            "عملية مرفوضة",
            "تم رفض العملية",
            "فشلت",
            "فشل",
            "فشل الدفع",
            "فشل العملية",
            "غير ناجحة",
            "تم الإلغاء",
            "ألغيت",
            "الرصيد غير كاف",
            "غير مصرح",
            "غير مصرح به",
            "تعذر",
            "تعذرت",
            "لم تتم الموافقة",
            "لم يتم الموافقة",
            "لم يتم إتمام العملية",
        ))
    }

    private fun nativeLooksLikeTransferMessage(text: String): Boolean {
        return nativeContainsAny(text, listOf(
            "transfer",
            "remittance",
            "bank transfer",
            "تحويل",
            "حوالة",
            "from account",
            "to account",
            "من حساب",
            "إلى حساب",
            "الى حساب",
        ))
    }

    private fun nativeCaptureSignature(message: String): String {
        return message.replace(Regex("""\s+"""), " ")
            .trim()
            .lowercase(Locale.ROOT)
    }

    private fun nativeWasRecentlyCaptured(context: Context, message: String): Boolean {
        val signature = nativeCaptureSignature(message)
        if (signature.isBlank()) return false
        val now = System.currentTimeMillis() / 1000.0
        val cutoff = now - 300.0
        val store = prefs(context)
        val raw = store.getString(recentCaptureKey, "[]") ?: "[]"
        val entries = mutableListOf<JSONObject>()
        var seen = false
        try {
            val array = JSONArray(raw)
            for (index in 0 until array.length()) {
                val item = array.optJSONObject(index) ?: continue
                val capturedAt = item.optDouble("capturedAt", 0.0)
                val storedSignature = item.optString("signature", "")
                if (capturedAt >= cutoff) {
                    entries.add(item)
                }
                if (capturedAt >= cutoff && storedSignature == signature) {
                    seen = true
                }
            }
        } catch (_: Throwable) {
        }
        entries.add(
            JSONObject(
                mapOf(
                    "signature" to signature,
                    "capturedAt" to now,
                ),
            ),
        )
        while (entries.size > maxQueueEntries) {
            entries.removeAt(0)
        }
        val output = JSONArray()
        for (entry in entries) {
            output.put(entry)
        }
        store.edit().putString(recentCaptureKey, output.toString()).apply()
        return seen
    }

    private fun extractAmount(message: String): String? {
        val lower = message.lowercase()
        val amountRegex = Regex(
            """(?:\b(?:egp|usd|sar|eur|gbp|aed|kwd|qar|bhd|omr|jod|try|myr|pkr|idr)\b\s*)?([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)\s*(egp|usd|sar|eur|gbp|aed|kwd|qar|bhd|omr|jod|try|myr|pkr|idr|ج\.م|جنيه|ريال|درهم|دينار|ليرة|€|£|\$|₺|⃁|﷼)?""",
            RegexOption.IGNORE_CASE,
        )

        val match = amountRegex.find(lower) ?: return null
        val number = match.groupValues[1].replace(",", "")
        val currency = match.groupValues.getOrNull(2)?.trim().orEmpty()
            .uppercase(Locale.ROOT)
        if (number.isBlank()) return null
        return if (currency.isBlank()) number else "$currency $number".trim()
    }

    private fun extractMerchantName(message: String): String? {
        val normalized = message.replace("\r", "\n")
        val cleaned = normalized.replace("\n", " ")
        val lines = normalized
            .split("\n")
            .map { it.trim() }
            .filter { it.isNotEmpty() }

        val inlinePatterns = listOf(
            Regex(
                """(?i)(?:at|merchant|store|from|to|لدى|عند|من|إلى|الى)\s*[:\-]?\s*([A-Za-z0-9&'().\-\u0600-\u06FF ]{2,80})""",
            ),
        )
        for (pattern in inlinePatterns) {
            val match = pattern.find(cleaned) ?: continue
            val merchant = match.groupValues.getOrNull(1)?.trim().orEmpty()
            val candidate = cleanMerchantCandidate(merchant)
            if (candidate.isNotBlank()) return candidate
        }

        val linePatterns = listOf(
            Regex("""(?i)^\s*(?:merchant|at|to|from|store)\s*[:\-]?\s*(.+)$"""),
            Regex("""(?i)^\s*(?:عند|لدى|من|إلى|الى)\s*[:\-]?\s*(.+)$"""),
        )
        for (line in lines) {
            for (pattern in linePatterns) {
                val match = pattern.find(line) ?: continue
                val merchant = match.groupValues.getOrNull(1)?.trim().orEmpty()
                val candidate = cleanMerchantCandidate(merchant)
                if (candidate.isNotBlank()) return candidate
            }
        }

        for (line in lines) {
            val candidate = cleanMerchantCandidate(line)
            if (candidate.isBlank()) continue
            if (candidate.any { it.isDigit() }) continue
            val lower = candidate.lowercase(Locale.ROOT)
            if (nativeContainsAny(lower, listOf(
                    "otp",
                    "verification",
                    "balance",
                    "الرصيد",
                    "card",
                    "بطاقة",
                    "amount",
                    "مبلغ",
                    "purchase",
                    "payment",
                    "transfer",
                    "حساب",
                    "account",
                ))
            ) {
                continue
            }
            return candidate
        }
        return null
    }

    private fun cleanMerchantCandidate(rawMerchant: String): String {
        val tokenized = rawMerchant
            .replace(Regex("""[\u200e\u200f\u202a-\u202e]"""), "")
            .replace(Regex("""\s+"""), " ")
            .trim()

        val kept = mutableListOf<String>()
        for (token in tokenized.split(Regex("""\s+"""))) {
            val cleaned = token
                .trim()
                .trim('.', ',', ':', ';', '-', '–', '—', '(', ')', '[', ']', '{', '}', '،', '؛')
            if (cleaned.isEmpty()) continue
            if (isMerchantStopWord(cleaned)) break
            kept.add(cleaned)
        }

        return kept.joinToString(" ")
            .replace(
                Regex(
                    """(?i)\s*(?:sar|sr|s\.r|egp|usd|aed|kwd|qar|bhd|omr|jod|try|myr|pkr|idr|r\.s|ج\.م|ريال|جنيه|درهم|دينار|ليرة|د\.إ|د.إ)\s*$""",
                ),
                "",
            )
            .replace(
                Regex(
                    """(?i)\s*-\s*(?:sa|ksa|uae|eg|egy|sr|s\.r|egp|usd|aed|qatar|kw|bh|om|jo|tr|my|pk|id)\s*$""",
                ),
                "",
            )
            .replace(
                Regex("""(?i)\s+\d{1,2}[:/ -]\d{1,2}.*$"""),
                "",
            )
            .replace(
                Regex(
                    """(?i)\s+(?:في|فى|عند|لدى|من|الى|إلى|بتاريخ|تاريخ|الساعة|اليوم|now|today|at|from|to)\s*.*$""",
                ),
                "",
            )
            .trim()
            .take(40)
    }

    private fun isMerchantStopWord(token: String): Boolean {
        val normalized = token.lowercase(Locale.ROOT)
            .trim('.', ',', ':', ';', '-', '–', '—', '(', ')', '[', ']', '{', '}', '،', '؛')
        if (normalized.isBlank()) return true
        if (Regex("""^\d+(?:[\/\-:]\d+)*$""").matches(normalized)) return true
        if (Regex("""^\d+(?:\.\d+)?$""").matches(normalized)) return true
        return normalized in setOf(
            "في",
            "فى",
            "عند",
            "لدى",
            "من",
            "الى",
            "إلى",
            "بتاريخ",
            "تاريخ",
            "الساعة",
            "اليوم",
            "الآن",
            "الان",
            "now",
            "today",
            "at",
            "from",
            "to",
            "purchase",
            "pos",
            "payment",
            "spent",
            "withdrawal",
            "debit",
            "transfer",
            "تحويل",
            "حوالة",
            "merchant",
            "store",
            "card",
            "بطاقة",
            "account",
            "حساب",
            "amount",
            "مبلغ",
            "balance",
            "الرصيد",
            "sar",
            "sr",
            "s.r",
            "egp",
            "usd",
            "aed",
            "kwd",
            "qar",
            "bhd",
            "omr",
            "jod",
            "try",
            "myr",
            "pkr",
            "idr",
            "ريال",
            "جنيه",
            "درهم",
            "دينار",
            "ليرة",
            "ر.س",
            "ج.م",
        )
    }

    private fun truncateMerchant(merchant: String): String {
        return merchant.replace(Regex("""\s+"""), " ").trim().take(40)
    }

    private fun truncateMessage(message: String): String {
        val trimmed = message.replace(Regex("""\s+"""), " ").trim()
        return if (trimmed.length <= 120) trimmed else trimmed.take(117).trimEnd() + "..."
    }

    private fun ensureNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
            as? NotificationManager ?: return
        if (manager.getNotificationChannel(notificationChannelId) != null) {
            return
        }

        val channel = NotificationChannel(
            notificationChannelId,
            notificationChannelName,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Shows smart capture alerts when Flutter is not ready."
        }
        manager.createNotificationChannel(channel)
    }

    private fun pendingIntentFlags(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
    }

    fun queuePayload(context: Context, payload: Map<String, String>) {
        val queue = readPayloadArray(context, queueKey)
        queue.add(JSONObject(payload as Map<*, *>).toString())
        while (queue.size > maxQueueEntries) {
            queue.removeAt(0)
        }
        writePayloadArray(context, queueKey, queue)
    }

    fun drainQueuedPayloads(context: Context): List<Map<String, String>> {
        val queue = readPayloadArray(context, queueKey)
        if (queue.isEmpty()) {
            return emptyList()
        }
        writePayloadArray(context, queueKey, mutableListOf())
        return queue.mapNotNull { raw ->
            try {
                val json = JSONObject(raw)
                jsonToMap(json)
            } catch (_: Throwable) {
                null
            }
        }
    }

    fun isLikelyOtpOrSecurityMessage(message: String): Boolean {
        val lower = message.lowercase()
        return listOf(
            "otp",
            "one time password",
            "one-time password",
            "verification code",
            "confirmation code",
            "security code",
            "authentication code",
            "login code",
            "passcode",
            "pin",
            "password",
            "wrong otp",
            "invalid otp",
            "incorrect otp",
            "otp expired",
            "wrong code",
            "invalid code",
            "incorrect code",
            "verification failed",
            "authentication failed",
            "رمز التحقق",
            "كود التحقق",
            "رمز لمرة واحدة",
            "الرمز لمرة واحدة",
            "كلمة مرور لمرة واحدة",
            "رمز الاستخدام لمرة واحدة",
            "تأكيد الدخول",
            "رمز خاطئ",
            "الرمز غير صحيح",
            "رمز التحقق غير صحيح",
            "انتهت صلاحية الرمز",
            "فشل التحقق",
            "فشل المصادقة",
        ).any { lower.contains(it) }
    }

    fun isLikelyFinancialMessage(message: String): Boolean {
        val lower = message.lowercase()
        if (isLikelyOtpOrSecurityMessage(lower)) return false
        if (nativeContainsRejectionIndicators(lower)) return true
        if (containsAnyCurrencyMarker(lower)) return true
        return listOf(
            "bank",
            "transfer",
            "payment",
            "purchase",
            "debit",
            "credit",
            "card",
            "amount",
            "balance",
            "salary",
            "deposit",
            "withdrawal",
            "wallet",
            "invoice",
            "statement",
            "تحويل",
            "حوالة",
            "سداد",
            "شراء",
            "مبلغ",
            "الرصيد",
            "إيداع",
            "خصم",
            "سحب",
            "محفظة",
            "فاتورة",
        ).any { lower.contains(it) }
    }

    private fun containsAnyCurrencyMarker(message: String): Boolean {
        val lower = message.lowercase()
        if (currencyMarkers.any { marker ->
                if (marker == "$" ||
                    marker == "€" ||
                    marker == "£" ||
                    marker == "₺" ||
                    marker == "⃁" ||
                    marker == "﷼"
                ) {
                    lower.contains(marker)
                } else {
                    marker.length <= 3 && Regex(
                        "(^|[^a-z0-9])${Regex.escape(marker.lowercase())}([^a-z0-9]|$)",
                    ).containsMatchIn(lower)
                }
            }
        ) {
            return true
        }
        return supportedCurrencyCodes.any { code ->
            Regex("(^|[^a-z0-9])${code.lowercase()}([^a-z0-9]|$)")
                .containsMatchIn(lower)
        }
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)

    private fun readPayloadArray(context: Context, key: String): MutableList<String> {
        val raw = prefs(context).getString(key, "[]") ?: "[]"
        val array = JSONArray(raw)
        val result = mutableListOf<String>()
        for (index in 0 until array.length()) {
            result.add(array.optString(index))
        }
        return result
    }

    private fun writePayloadArray(
        context: Context,
        key: String,
        values: List<String>,
    ) {
        prefs(context).edit().putString(key, JSONArray(values).toString()).apply()
    }

    private fun jsonToMap(json: JSONObject): Map<String, String> {
        return mapOf(
            "messageContent" to json.optString("messageContent"),
            "source" to json.optString("source"),
            "sourceIdentifier" to json.optString("sourceIdentifier"),
            "notificationAlreadyShown" to json.optString("notificationAlreadyShown"),
            "notificationTap" to json.optString("notificationTap"),
            "notificationTapToken" to json.optString("notificationTapToken"),
        )
    }
}

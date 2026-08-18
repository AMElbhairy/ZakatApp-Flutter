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
        val notificationId: Int,
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
    private val nativeBuiltinMerchantAliases = mapOf(
        "talabat" to listOf("talabat", "talabat.com", "talabat app", "talabat maa", "talabat pay", "talabat mart", "طلبات"),
        "amazon" to listOf("amazon", "amazon.sa", "amazon.ae"),
        "toyou" to listOf("toyou", "toyou app"),
        "tamimi market" to listOf("tamimi market", "s505 tamimi market", "al tamimi market"),
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
            val parsed = parseCaptureNotification(context, payload, message)
            val queuedPayload = payload + mapOf("notificationAlreadyShown" to "true")
            showFallbackNotification(context, parsed)
            queuePayload(context, queuedPayload)
            return
        }
        try {
            channel.invokeMethod("smsMessageReceived", payload)
        } catch (_: Throwable) {
            val message = payload["messageContent"].orEmpty().trim()
            val parsed = parseCaptureNotification(context, payload, message)
            val queuedPayload = payload + mapOf("notificationAlreadyShown" to "true")
            showFallbackNotification(context, parsed)
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
        parsed: ParsedCaptureNotification,
    ) {
        if (parsed.body.isEmpty() && parsed.title.isEmpty()) return
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
            parsed.notificationId,
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
            .notify(parsed.notificationId, notification)
    }

    private fun parseCaptureNotification(
        context: Context,
        payload: Map<String, String>,
        message: String,
    ): ParsedCaptureNotification {
        val state = loadSmartCaptureState(context)
        val languageCode = state?.languagePreference ?: "en"
        val isArabic = languageCode.lowercase(Locale.ROOT).startsWith("ar")
        val source = payload["source"].orEmpty()
        val amount = extractAmount(message)
        val merchant = extractMerchantName(message, state)
        val tapToken = UUID.randomUUID().toString()
        val notificationId = nativeNotificationId(source = source, message = message)
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
            notificationId = notificationId,
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
            nativeContainsRejectionIndicators(normalized) ||
            nativeContainsSubscriptionActivationIndicators(normalized)
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
        if (nativeContainsRejectionIndicators(normalized)) {
            return false
        }
        if (nativeContainsSubscriptionActivationIndicators(normalized)) {
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

        if (nativeLooksLikeTransferMessage(normalized)) {
            return false
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

    private fun nativeContainsSubscriptionActivationIndicators(text: String): Boolean {
        return nativeContainsAny(text, listOf(
            "subscribe",
            "subscription",
            "subscribed",
            "welcome prepaid",
            "welcome package",
            "new activation",
            "activation successful",
            "activated successfully",
            "package details",
            "bundle price",
            "service number",
            "econtract",
            "contract",
            "mobily welcome prepaid",
            "اشتراك",
            "تم تفعيل اشتراكك",
            "تم الاشتراك",
            "تفعيل الاشتراك",
            "الباقة",
            "الباقة الترحيبية",
            "الباقة مسبقة الدفع",
            "تفاصيل الباقة",
            "سعر الباقة",
            "رقم الخدمة",
            "العقد الإلكتروني",
            "العقد الالكتروني",
            "تطبيق موبايلي",
            "حمّل تطبيق",
            "حمل تطبيق",
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
        val normalized = message.replace("\r", "\n")
        val explicit = nativeExplicitAmountCandidate(normalized)
        if (explicit != null) {
            return nativeFormatAmount(explicit.first, explicit.second)
        }

        val lines = normalized.split("\n").map { it.trim() }.filter { it.isNotEmpty() }
        var selectedPriority = Int.MAX_VALUE
        var bestScore = Double.NEGATIVE_INFINITY
        var selectedAmount: Double? = null

        for (line in lines) {
            val lower = line.lowercase(Locale.ROOT)
            val matches = Regex("""([0-9][0-9,]*(?:\.[0-9]+)?)""").findAll(line)
            for (match in matches) {
                val raw = match.groupValues[1].replace(",", "")
                val value = raw.toDoubleOrNull() ?: continue
                if (value <= 0) continue
                if (value < 100 && nativeLooksLikeDateNumberCandidate(line, value)) {
                    continue
                }
                if (nativeContainsAny(lower, listOf(
                        "الرصيد",
                        "رصيدك الحالي",
                        "حد الصرف",
                        "حد الصرف المتبقي",
                        "remaining amount",
                        "remaining limit",
                        "سعر الصرف",
                        "exchange rate",
                        "available balance",
                        "remaining balance",
                        "credit limit",
                    ))
                ) {
                    continue
                }

                val priorityAndScore = nativeAmountPriorityAndScore(lower)
                var score = priorityAndScore.second
                val localCurrency = nativeCurrencyCode(line)
                if (localCurrency == "SAR" || localCurrency == "EGP") {
                    score += 30.0
                }
                if (priorityAndScore.first < selectedPriority ||
                    (priorityAndScore.first == selectedPriority && score > bestScore)
                ) {
                    selectedPriority = priorityAndScore.first
                    bestScore = score
                    selectedAmount = value
                }
            }
        }

        return selectedAmount?.let { nativeFormatAmount(it, null) }
    }

    private fun extractMerchantName(
        message: String,
        state: NativeSmartCaptureStateSnapshot?,
    ): String? {
        val normalized = message.replace("\r", "\n")
        val text = normalized.lowercase(Locale.ROOT)
        val lines = normalized
            .split(Regex("""\r?\n"""))
            .map { it.trim() }
            .filter { it.isNotEmpty() }

        val effectiveAliases = nativeEffectiveAliases(state)
        val intentMerchant = nativeMerchantFromIntentLabel(message)
        var merchantName: String? = null

        if (intentMerchant != null) {
            merchantName = nativeNormalizeMerchantName(intentMerchant)
        } else {
            nativeMerchantFromInlinePatterns(message, effectiveAliases)?.let {
                merchantName = it
            } ?: run {
                val transferDetails = nativeTransferDetails(
                    message,
                    currentUserName = null,
                )
                when (transferDetails.direction) {
                    "out" -> {
                        merchantName = transferDetails.recipientName?.let {
                            nativeResolveAlias(it, effectiveAliases)
                        }
                    }
                    "in" -> {
                        merchantName = transferDetails.senderName?.let {
                            nativeResolveAlias(it, effectiveAliases)
                        }
                    }
                    else -> {
                        if (!transferDetails.isTransferMessage && !nativeIsWalletTopUpMessage(text)) {
                            merchantName = nativeMerchantFromTransactionField(
                                message,
                                effectiveAliases,
                                hasPurchaseIntent = nativeHasPurchaseIntent(text),
                            )
                            merchantName = merchantName
                                ?: nativeMerchantFromPriorityPatterns(message, effectiveAliases)
                            if (merchantName == null) {
                                for (line in lines) {
                                    val lineLower = line.lowercase(Locale.ROOT)
                                    if (Regex("""^(?:في|داخل|الدولة|country)\s*:""", RegexOption.IGNORE_CASE).containsMatchIn(lineLower)) continue
                                    if (Regex("""^(?:to|إلى|الى)\s*:""", RegexOption.IGNORE_CASE).containsMatchIn(lineLower)) continue
                                    if (nativeContainsAny(lineLower, listOf(
                                            "شراء",
                                            "دفع",
                                            "خصم",
                                            "سداد",
                                            "عملية",
                                            "purchase",
                                            "payment",
                                            "pos",
                                            "debit",
                                            "transfer",
                                            "remittance",
                                            "تحويل",
                                            "حوالة",
                                            "تم",
                                            "دولي",
                                            "محلي",
                                            "بطاقة",
                                            "الخصم",
                                            "المباشر",
                                            "رقم",
                                            "المتاح",
                                            "الرصيد",
                                            "الحساب",
                                            "اليوم",
                                            "الساعة",
                                            "merchant",
                                        )) ||
                                        nativeContainsAny(lineLower, listOf(
                                            "apple pay",
                                            "mada",
                                            "مدى",
                                            "card",
                                            "بطاقة",
                                            "حساب",
                                            "account",
                                            "visa",
                                            "mastercard",
                                        )) ||
                                        nativeContainsAny(lineLower, listOf(
                                            "sar",
                                            "sr",
                                            "s.r",
                                            "egp",
                                            "usd",
                                            "aed",
                                            "درهم",
                                            "ريال",
                                            "جنيه",
                                            "ر.س",
                                            "ج.م",
                                            "fee",
                                            "رسوم",
                                            "total",
                                            "due",
                                            "balance",
                                            "الرصيد",
                                            "مبلغ",
                                            "amount",
                                        )) ||
                                        Regex("""^\s*(?:from|من)\s*[:\-]?\s*\d+\s*$""", RegexOption.IGNORE_CASE).containsMatchIn(lineLower) ||
                                        Regex("""\d""").containsMatchIn(line)
                                    ) {
                                        continue
                                    }
                                    if (Regex("""[A-Za-z\u0600-\u06FF]""").containsMatchIn(line)) {
                                        merchantName = nativeValidatedMerchant(line, effectiveAliases)
                                        if (merchantName != null) break
                                    }
                                }
                            }
                            if (merchantName == null) {
                                merchantName = nativeMerchantFromKnownAlias(text, effectiveAliases)
                            }
                        }
                    }
                }
            }
        }

        if (merchantName != null && nativeIsInvalidMerchantCandidate(merchantName)) {
            merchantName = null
        }
        return merchantName
    }

    private fun nativeHasPurchaseIntent(text: String): Boolean {
        return nativeContainsAny(text, listOf(
            "purchase",
            "online purchase",
            "pos",
            "point of sale",
            "apple pay",
            "mada",
            "visa purchase",
            "mastercard purchase",
            "debit card purchase",
            "شراء",
            "شراء دولي",
            "شراء عبر الإنترنت",
            "شراء عبر نقاط البيع",
            "نقاط البيع",
            "مدى",
            "أبل باي",
            "عملية شراء",
        ))
    }

    private fun nativeEffectiveAliases(state: NativeSmartCaptureStateSnapshot?): Map<String, String> {
        val aliases = mutableMapOf<String, String>()
        for ((merchant, aliasList) in nativeBuiltinMerchantAliases) {
            for (alias in aliasList) {
                aliases[alias.lowercase(Locale.ROOT).trim()] = merchant
            }
        }
        if (state != null) {
            for ((alias, merchant) in state.merchantAliases) {
                aliases[alias.lowercase(Locale.ROOT).trim()] = merchant
            }
            for ((_, rule) in state.merchantRules) {
                val enabled = (rule["enabled"] as? Boolean) ?: true
                if (!enabled) continue
                val builtinKey = (rule["builtinKey"] as? String)?.lowercase(Locale.ROOT)?.trim()
                if (builtinKey != null) {
                    for (alias in nativeBuiltinMerchantAliases[builtinKey].orEmpty()) {
                        aliases[alias.lowercase(Locale.ROOT).trim()] = rule["merchantName"] as? String
                            ?: aliases[alias.lowercase(Locale.ROOT).trim()].orEmpty()
                    }
                }
                val ruleAliases = rule["aliases"] as? List<*>
                if (ruleAliases != null) {
                    for (alias in ruleAliases) {
                        val aliasText = alias?.toString()?.lowercase(Locale.ROOT)?.trim().orEmpty()
                        val merchantName = rule["merchantName"] as? String
                        if (aliasText.isNotEmpty() && !merchantName.isNullOrBlank()) {
                            aliases[aliasText] = merchantName
                        }
                    }
                }
            }
        }
        return aliases
    }

    private fun nativeMerchantFromKnownAlias(
        text: String,
        aliases: Map<String, String>,
    ): String? {
        val orderedAliases = aliases.keys.sortedByDescending { it.length }
        val searchText = nativeMerchantSearchToken(text)
        for (alias in orderedAliases) {
            if (Regex("""(?i)(?<![a-z0-9])${Regex.escape(alias)}(?![a-z0-9])""").containsMatchIn(text)) {
                return nativeValidatedMerchant(aliases[alias].orEmpty(), aliases)
            }
            val aliasToken = nativeMerchantSearchToken(alias)
            if (aliasToken.isNotEmpty() && searchText.contains(aliasToken)) {
                return nativeValidatedMerchant(aliases[alias].orEmpty(), aliases)
            }
        }
        return null
    }

    private fun nativeMerchantFromPriorityPatterns(
        rawMessage: String,
        aliases: Map<String, String>,
    ): String? {
        val lines = rawMessage.split(Regex("""\r?\n"""))
            .map { it.trim() }
            .filter { it.isNotEmpty() }
        val patterns = listOf(
            Regex("""^\s*عند\s+([A-Za-z\u0600-\u06FF0-9][A-Za-z0-9\u0600-\u06FF&*.,\- ]{1,80})""", RegexOption.IGNORE_CASE),
            Regex("""^\s*At\s*[:-]?\s*([A-Za-z\u0600-\u06FF0-9][A-Za-z0-9\u0600-\u06FF&*.,\- ]{1,80})""", RegexOption.IGNORE_CASE),
            Regex("""^\s*Merchant\s*[:-]?\s*([A-Za-z\u0600-\u06FF0-9][A-Za-z0-9\u0600-\u06FF&*.,\- ]{1,80})""", RegexOption.IGNORE_CASE),
        )
        for (line in lines) {
            for (pattern in patterns) {
                val match = pattern.find(line) ?: continue
                val candidate = nativeValidatedMerchant(match.groupValues.getOrNull(1), aliases)
                if (candidate != null) return candidate
            }
        }
        return null
    }

    private fun nativeMerchantFromInlinePatterns(
        rawMessage: String,
        aliases: Map<String, String>,
    ): String? {
        val patterns = listOf(
            Regex("""(?:(?<![A-Za-z0-9])(?:at|merchant|store)(?![A-Za-z0-9])|لدى|عند|في)\s*[:\-]?\s*([A-Za-z\u0600-\u06FF0-9][A-Za-z0-9\u0600-\u06FF&*.,\- ]{1,80})""", RegexOption.IGNORE_CASE),
        )
        for (pattern in patterns) {
            val match = pattern.find(rawMessage) ?: continue
            val candidate = nativeValidatedMerchant(match.groupValues.getOrNull(1), aliases)
            if (candidate != null) return candidate
        }
        return null
    }

    private data class NativeTransferDetails(
        val direction: String,
        val senderName: String?,
        val recipientName: String?,
        val isTransferMessage: Boolean,
    )

    private fun nativeTransferDetails(
        rawMessage: String,
        currentUserName: String? = null,
    ): NativeTransferDetails {
        val lines = rawMessage.split(Regex("""\r?\n"""))
            .map { it.trim() }
            .filter { it.isNotEmpty() }
        val senderName = nativeTransferParty(lines, listOf(
            "sender",
            "from account",
            "from",
            "المرسل",
            "مرسل",
            "من حساب",
            "من",
        ))
        val recipientName = nativeTransferParty(lines, listOf(
            "to account",
            "to",
            "recipient",
            "beneficiary",
            "المستفيد",
            "إلى حساب",
            "إلى",
            "الى",
        ))
        val lowered = rawMessage.lowercase(Locale.ROOT)
        val hasExplicitTransferPartyLabels = nativeContainsAny(lowered, listOf(
            "sender:",
            "recipient:",
            "beneficiary:",
            "from account",
            "to account",
            "المرسل",
            "مرسل",
            "المستفيد",
            "من حساب",
            "إلى حساب",
        ))
        val hasTransferKeywords = nativeContainsAny(lowered, listOf(
            "transfer",
            "remittance",
            "bank transfer",
            "تحويل",
            "حوالة",
            "واردة",
            "وارد",
            "صادرة",
            "صادر",
        ))
        val isInternalTransfer = nativeContainsAny(lowered, listOf(
            "internal transfer",
            "transfer between accounts",
            "account transfer",
            "تحويل داخلي",
            "تحويل بين الحسابات",
            "بين حساباتي",
            "between accounts",
            "between my accounts",
        )) || (
            nativeContainsAny(lowered, listOf(
                "from account",
                "to account",
                "من حساب",
                "إلى حساب",
            )) && (
                nativeLooksLikeOwnAccountReference(senderName) ||
                    nativeLooksLikeOwnAccountReference(recipientName)
            )
        )
        val isTransferMessage = hasTransferKeywords || hasExplicitTransferPartyLabels || isInternalTransfer
        val direction = if (isTransferMessage) {
            nativeTransferDirection(
                rawMessage,
                senderName = senderName,
                recipientName = recipientName,
                currentUserName = currentUserName,
                isInternalTransfer = isInternalTransfer,
            )
        } else {
            "unknown"
        }
        return NativeTransferDetails(direction, senderName, recipientName, isTransferMessage)
    }

    private fun nativeTransferParty(lines: List<String>, labels: List<String>): String? {
        for (line in lines) {
            for (label in labels) {
                val match = Regex("""^\s*${Regex.escape(label)}\s*[:\-]?\s*(.+)$""", RegexOption.IGNORE_CASE)
                    .find(line) ?: continue
                val candidate = match.groupValues.getOrNull(1)?.trim().orEmpty()
                if (candidate.isBlank() || nativeIsTransferPartyNoise(candidate)) continue
                return candidate
            }
        }
        return null
    }

    private fun nativeIsTransferPartyNoise(value: String): Boolean {
        val lower = value.lowercase(Locale.ROOT).trim()
        return nativeContainsAny(lower, listOf(
            "balance",
            "الرصيد",
            "amount",
            "مبلغ",
            "account",
            "حساب",
            "card",
            "بطاقة",
            "visa",
            "mastercard",
            "apple pay",
            "mada",
            "stc pay",
            "stcpay",
        )) || Regex("""^\d+$""").matches(lower)
    }

    private fun nativeLooksLikeOwnAccountReference(value: String?): Boolean {
        if (value == null) return false
        val lower = value.lowercase(Locale.ROOT).trim()
        return nativeContainsAny(lower, listOf("account", "حساب", "card", "بطاقة")) ||
            Regex("""^\*+\d+$""").matches(lower) ||
            Regex("""^\d+$""").matches(lower)
    }

    private fun nativeTransferDirection(
        rawMessage: String,
        senderName: String?,
        recipientName: String?,
        currentUserName: String?,
        isInternalTransfer: Boolean,
    ): String {
        if (isInternalTransfer) return "internal"
        val lower = rawMessage.lowercase(Locale.ROOT)
        val normalizedUser = currentUserName?.let { nativeMerchantSearchToken(it) }
        val normalizedSender = senderName?.let { nativeMerchantSearchToken(it) }
        val normalizedRecipient = recipientName?.let { nativeMerchantSearchToken(it) }
        if (normalizedUser != null) {
            if (normalizedSender != null && normalizedSender == normalizedUser) return "out"
            if (normalizedRecipient != null && normalizedRecipient == normalizedUser) return "in"
        }
        if (nativeContainsAny(lower, listOf(
                "debit transfer intl",
                "debit transfer",
                "transfer sent",
                "paid to",
                "sent to",
                "outgoing transfer",
                "خصم",
                "سحب",
                "دفع",
                "تحويل صادر",
                "حوالة صادرة",
                "حوالة صادر",
                "صادرة",
                "صادر",
                "تم التحويل إلى",
            ))
        ) {
            return "out"
        }
        if (nativeContainsAny(lower, listOf(
                "credit transfer",
                "transfer received",
                "received from",
                "transfer from",
                "incoming transfer",
                "إيداع",
                "تحويل وارد",
                "حوالة واردة",
                "حوالة وارد",
                "واردة",
                "وارد",
                "تم استلام تحويل من",
                "تم الإيداع",
                "تم استلام",
                "credited",
                "received",
            ))
        ) {
            return "in"
        }
        return "unknown"
    }

    private fun nativeMerchantFromTransactionField(
        rawMessage: String,
        aliases: Map<String, String>,
        hasPurchaseIntent: Boolean,
    ): String? {
        val lines = rawMessage.split(Regex("""\r?\n"""))
            .map { it.trim() }
            .filter { it.isNotEmpty() }

        if (hasPurchaseIntent) {
            nativeMerchantFromFieldLines(
                lines,
                aliases,
                listOf("من", "from", "at", "merchant", "store", "لدى", "عند"),
            )?.let { return it }
        }

        nativeMerchantFromFieldLines(
            lines,
            aliases,
            listOf("merchant", "store", "at"),
        )?.let { return it }

        if (nativeContainsAny(rawMessage.lowercase(Locale.ROOT), listOf(
                "credit transfer",
                "incoming transfer",
                "deposit",
                "salary",
                "credited",
                "received",
                "transfer received",
                "payment received",
                "inward transfer",
                "cashback",
                "repayment",
            ))
        ) {
            return nativeMerchantFromFieldLines(
                lines,
                aliases,
                listOf("from", "من", "لدى", "عند"),
            )
        }
        return null
    }

    private fun nativeMerchantFromFieldLines(
        lines: List<String>,
        aliases: Map<String, String>,
        labels: List<String>,
    ): String? {
        for (line in lines) {
            for (label in labels) {
                val match = Regex("""^\s*${Regex.escape(label)}\s*[:\-]?\s*(.+)$""", RegexOption.IGNORE_CASE)
                    .find(line) ?: continue
                val candidate = nativeValidatedMerchant(match.groupValues.getOrNull(1), aliases)
                if (candidate != null) return candidate
            }
        }
        return null
    }

    private fun nativeMerchantSearchToken(input: String): String {
        return input.lowercase(Locale.ROOT)
            .replace(Regex("""[\u200e\u200f\u202a-\u202e]"""), "")
            .replace(Regex("""[^a-z0-9\u0600-\u06FF]+"""), "")
    }

    private fun nativeValidatedMerchant(
        rawMerchant: String?,
        aliases: Map<String, String>,
    ): String? {
        if (rawMerchant == null) return null
        var clean = nativeTrimMerchantCandidate(rawMerchant)
            .lineSequence()
            .firstOrNull()
            .orEmpty()
            .trim()
            .replaceFirst(
                Regex("""^(?:purchase|pos purchase|pos|payment|spent|withdrawal|debit|شراء|عملية شراء|سداد|خصم|دفع|transfer|تحويل|حوالة|تم|وارد|merchant|at|from|من|لدى|عند)\s*[:\-]?\s+""", RegexOption.IGNORE_CASE),
                "",
            )
            .replaceFirst(
                Regex("""\s+(?:sar|egp|usd|aed|ريال|جنيه|درهم|ر\.س|ج\.م)$""", RegexOption.IGNORE_CASE),
                "",
            )
            .replaceFirst(
                Regex("""\s*[-–]\s*(?:sa|ksa|uae|eg|us|usa|uk)$""", RegexOption.IGNORE_CASE),
                "",
            )
            .trim()
        clean = nativeResolveAlias(clean, aliases)
        val normalized = nativeNormalizeMerchantName(clean)
        val key = normalized.lowercase(Locale.ROOT).trim()
        val blacklist = setOf(
            "sa", "ksa", "uae", "eg", "sar", "egp", "usd", "aed", "eur", "gbp",
            "ريال", "جنيه", "درهم", "dollar", "apple", "apple pay", "applepay",
            "mada", "مدى", "visa", "mastercard", "stc pay", "stcpay", "bank transfer",
            "urpay", "ur pay", "hsbc", "cib", "alrajhi", "al rajhi", "ahli", "al ahli",
            "bank", "purchase", "pos purchase", "pos", "payment", "spent", "withdrawal",
            "debit", "شراء", "عملية شراء", "سداد", "خصم", "دفع", "amount", "مبلغ",
        )
        if (clean.isBlank() ||
            key.length <= 2 ||
            blacklist.contains(key) ||
            (nativeContainsAny(key, listOf("card", "account", "balance", "remaining", "visa", "mastercard", "mada", "apple pay", "stc pay", "stcpay")) && Regex("""\d""").containsMatchIn(key)) ||
            Regex("""^[\d\s\.,]+$""").containsMatchIn(key) ||
            Regex("""^(?:في|داخل|الدولة|country)\s*:""").containsMatchIn(key)
        ) {
            return null
        }
        return normalized
    }

    private fun nativeTrimMerchantCandidate(rawMerchant: String): String {
        val tokens = rawMerchant
            .replace(Regex("""[\r\n\t]+"""), " ")
            .trim()
            .split(Regex("""\s+"""))
        val kept = mutableListOf<String>()
        for (token in tokens) {
            val cleaned = token.trim()
            if (cleaned.isEmpty()) continue
            if (isMerchantStopWord(cleaned)) break
            kept.add(cleaned)
        }
        return kept.joinToString(" ").trim()
    }

    private fun nativeResolveAlias(merchant: String, aliases: Map<String, String>): String {
        val key = merchant.lowercase(Locale.ROOT).trim()
        return aliases[key] ?: merchant
    }

    private fun nativeNormalizeMerchantName(merchant: String): String {
        val normalized = merchant.lowercase(Locale.ROOT).trim()
        return when {
            normalized == "talabat.com" ||
                normalized == "talabat app" ||
                normalized == "talabat maa" ||
                normalized == "talabat pay" ||
                normalized == "talabat mart" ||
                normalized.startsWith("talabat") -> "Talabat"
            normalized.startsWith("amazon") || normalized == "amazon.sa" || normalized == "amazon.ae" -> "Amazon"
            normalized.startsWith("toyou") -> "ToYou"
            normalized.startsWith("hungerstation") -> "HungerStation"
            normalized.startsWith("jahez") -> "Jahez"
            normalized.startsWith("noon") -> "Noon"
            normalized.startsWith("jarir") -> "Jarir"
            normalized.startsWith("uber") -> "Uber"
            normalized.startsWith("careem") -> "Careem"
            normalized.startsWith("e-finance") || normalized.startsWith("efinance") -> "E-Finance"
            normalized.startsWith("nile air") -> "Nile Air"
            normalized.startsWith("flynas") -> "Flynas"
            normalized.startsWith("saudia") -> "Saudia"
            normalized.startsWith("fitness time") -> "Fitness Time"
            normalized.startsWith("whoop") -> "WHOOP"
            normalized.startsWith("fitness plan") -> "Fitness Plan"
            normalized.startsWith("stc pay") -> "STC Pay"
            normalized.startsWith("stc") -> "STC"
            normalized.startsWith("mobily pay") -> "Mobily Pay"
            normalized.startsWith("mobily") -> "Mobily"
            normalized.startsWith("zain") -> "Zain"
            Regex("""^(?:s\d+\s+)?tamimi market""").matches(normalized) -> "Tamimi Market"
            else -> capitalizeWords(merchant)
        }
    }

    private fun capitalizeWords(value: String): String {
        return value.split(Regex("""\s+"""))
            .filter { it.isNotEmpty() }
            .joinToString(" ") { word ->
                word.lowercase(Locale.ROOT).replaceFirstChar { char ->
                    if (char.isLowerCase()) char.titlecase(Locale.ROOT) else char.toString()
                }
            }
    }

    private fun nativeIsInvalidMerchantCandidate(merchant: String): Boolean {
        val normalized = merchant.lowercase(Locale.ROOT).trim()
        val searchToken = nativeMerchantSearchToken(merchant)
        val invalidExact = setOf(
            "account",
            "bank",
            "balance",
            "amount",
            "card",
            "merchant",
            "payment",
            "purchase",
            "pos",
            "debit",
            "credit",
            "cash",
            "transfer",
            "expense",
            "income",
            "بطاقة",
            "حساب",
            "الرصيد",
            "مبلغ",
            "عملية",
            "شراء",
            "دفع",
            "سداد",
            "رقم",
            "المتاح",
            "المباشر",
            "الخصم",
            "إلى",
            "الى",
            "من",
            "لدى",
            "عند",
            "في",
            "داخل",
            "pending",
            "approval",
            "approved",
            "rejected",
            "declined",
            "captured",
            "successful",
            "completed",
            "review",
            "smart",
            "capture",
        )
        if (invalidExact.contains(normalized) || invalidExact.contains(searchToken)) {
            return true
        }
        if (searchToken.contains("حساب") ||
            searchToken.contains("account") ||
            searchToken.contains("بطاقة") ||
            searchToken.contains("pending") ||
            searchToken.contains("approval") ||
            searchToken.contains("approved") ||
            searchToken.contains("rejected") ||
            searchToken.contains("declined") ||
            searchToken.contains("captured") ||
            searchToken.contains("successful") ||
            searchToken.contains("completed") ||
            searchToken.startsWith("visa") ||
            searchToken.startsWith("mastercard") ||
            searchToken.startsWith("mada") ||
            searchToken.startsWith("applepay") ||
            searchToken.startsWith("stcpay") ||
            searchToken.contains("الرصيد") ||
            searchToken.contains("balance") ||
            searchToken.contains("amount") ||
            searchToken.contains("مبلغ") ||
            searchToken.contains("رقم")
        ) {
            return true
        }
        return false
    }

    private fun nativeIsTransferMessage(text: String): Boolean {
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

    private fun nativeIsWalletTopUpMessage(text: String): Boolean {
        return nativeContainsAny(text, listOf(
            "wallet top up",
            "wallet top-up",
            "wallet topup",
            "top up wallet",
            "top-up wallet",
            "topup wallet",
            "wallet recharge",
            "recharge wallet",
            "wallet reload",
            "load wallet",
            "wallet load",
            "wallet refill",
            "add money to wallet",
            "add funds to wallet",
            "fund wallet",
            "wallet funding",
            "account funding",
            "funding via apple pay",
            "wallet deposit",
            "deposit to wallet",
            "cash in wallet",
            "wallet cash in",
            "شحن المحفظة",
            "شحن رصيد المحفظة",
            "شحن المحفظه",
            "شحن رصيد المحفظه",
            "تعبئة المحفظة",
            "تعبئة المحفظه",
            "إعادة شحن المحفظة",
            "اعادة شحن المحفظة",
            "إعادة شحن المحفظه",
            "اعادة شحن المحفظه",
            "إضافة رصيد للمحفظة",
            "اضافة رصيد للمحفظة",
            "إضافة رصيد للمحفظه",
            "اضافة رصيد للمحفظه",
            "إيداع في المحفظة",
            "إيداع في المحفظه",
            "إضافة إلى المحفظة",
            "اضافة إلى المحفظة",
            "إضافة الى المحفظة",
            "اضافة الى المحفظة",
            "تم شحن المحفظة",
            "تم شحن المحفظه",
            "تم تعبئة المحفظة",
            "تم تعبئة المحفظه",
            "تمويل المحفظة",
            "تمويل المحفظه",
            "تمويل الحساب",
            "تم تعبئة الحساب",
            "شحن الحساب",
            "إضافة رصيد للحساب",
            "اضافة رصيد للحساب",
        ))
    }

    private fun nativeMerchantFromIntentLabel(rawMessage: String): String? {
        val lower = rawMessage.lowercase(Locale.ROOT)
        val labels = listOf(
            Regex("""credit\s*card\s*:\s*payment""", RegexOption.IGNORE_CASE),
            Regex("""debit\s*:\s*loan\s+instalment""", RegexOption.IGNORE_CASE),
            Regex("""تم\s+سداد\s+البطاقة\s+الائتمانية""", RegexOption.IGNORE_CASE),
        )
        return when {
            labels[0].containsMatchIn(lower) -> "Credit Card Payment"
            labels[1].containsMatchIn(lower) -> "Loan Instalment"
            labels[2].containsMatchIn(lower) -> "سداد البطاقة الائتمانية"
            else -> null
        }
    }

    private fun nativeExplicitAmountCandidate(text: String): Pair<Double, String?>? {
        val patterns = listOf(
            Regex("""(?i)(?:SAR|SR|S\.R|EGP|USD|AED|KWD|QAR|BHD|OMR|ر\.س|ج\.م|ريال|جنيه|درهم|د\.إ|د.إ)\s*(?:amount|المبلغ|مبلغ)\s*[:\-]?\s*([0-9][0-9,]*(?:\.[0-9]+)?)"""),
            Regex("""(?i)(?:amount|المبلغ|مبلغ|charged amount|transaction amount|purchase amount|total|value|price|due)\s*[:\-]?\s*(?:SAR|SR|S\.R|EGP|USD|AED|KWD|QAR|BHD|OMR|ر\.س|ج\.م|ريال|جنيه|درهم|د\.إ|د.إ)?\s*([0-9][0-9,]*(?:\.[0-9]+)?)"""),
            Regex("""(?i)(?:SAR|SR|S\.R|EGP|USD|AED|KWD|QAR|BHD|OMR|ر\.س|ج\.م|ريال|جنيه|درهم|د\.إ|د.إ)\s*([0-9][0-9,]*(?:\.[0-9]+)?)"""),
            Regex("""(?i)([0-9][0-9,]*(?:\.[0-9]+)?)\s*(?:SAR|SR|S\.R|EGP|USD|AED|KWD|QAR|BHD|OMR|ر\.س|ج\.م|ريال|جنيه|درهم|د\.إ|د.إ)"""),
        )
        for (pattern in patterns) {
            val match = pattern.find(text) ?: continue
            val rawAmount = match.groupValues.getOrNull(1).orEmpty().replace(",", "")
            val parsedAmount = rawAmount.toDoubleOrNull() ?: continue
            if (parsedAmount <= 0) continue
            val currency = nativeCurrencyCode(match.value)
            return parsedAmount to currency
        }
        return null
    }

    private fun nativeAmountPriorityAndScore(lineLower: String): Pair<Int, Double> {
        return when {
            nativeContainsAny(lineLower, listOf(
                    "total due",
                    "total charged",
                    "إجمالي المبلغ المستحق",
                    "المبلغ النهائي",
                    "إجمالي المبلغ",
                )) -> 1 to 10000.0
            nativeContainsAny(lineLower, listOf(
                    "charged amount",
                    "المبلغ المطلوب",
                    "total charged amount",
                )) -> 2 to 8000.0
            nativeContainsAny(lineLower, listOf(
                    "مبلغ",
                    "amount",
                    "amt",
                    "value",
                    "بقيمة",
                    "بقيمه",
                    "purchase amount",
                    "transaction amount",
                )) -> 3 to 6000.0
            nativeContainsAny(lineLower, listOf(
                    "purchase",
                    "pos",
                    "payment",
                    "debit",
                    "credit",
                    "شراء",
                    "دفع",
                    "خصم",
                    "سحب",
                )) -> 3 to 5500.0
            nativeContainsAny(lineLower, listOf(
                    "fee",
                    "fees",
                    "رسوم",
                    "رسوم العملية",
                )) -> 4 to 4000.0
            nativeContainsAny(lineLower, listOf(
                    "balance",
                    "remaining",
                    "spending limit",
                    "remaining amount",
                    "remaining limit",
                )) -> 5 to 2000.0
            else -> 5 to 0.0
        }
    }

    private fun nativeLooksLikeDateNumberCandidate(line: String, value: Double): Boolean {
        if (value >= 100) return false
        val lower = line.lowercase(Locale.ROOT)
        return nativeContainsAny(lower, listOf(
            "jan",
            "feb",
            "mar",
            "apr",
            "may",
            "jun",
            "jul",
            "aug",
            "sep",
            "oct",
            "nov",
            "dec",
            "يناير",
            "فبراير",
            "مارس",
            "أبريل",
            "ابريل",
            "مايو",
            "يونيو",
            "يوليو",
            "أغسطس",
            "اغسطس",
            "سبتمبر",
            "أكتوبر",
            "اكتوبر",
            "نوفمبر",
            "ديسمبر",
        )) || lower.contains("-") || lower.contains("/")
    }

    private fun nativeCurrencyCode(text: String): String? {
        val patterns = listOf(
            Regex("""(?i)\b(SAR|SR|S\.R)\b""") to "SAR",
            Regex("""(?i)\b(EGP|ج\.م|جنيه)\b""") to "EGP",
            Regex("""(?i)\b(USD|\$)\b""") to "USD",
            Regex("""(?i)\b(AUD|A\$)\b""") to "AUD",
            Regex("""(?i)\b(CAD|C\$)\b""") to "CAD",
            Regex("""(?i)\b(AED|د\.إ|د.إ|درهم)\b""") to "AED",
            Regex("""(?i)\b(KWD)\b""") to "KWD",
            Regex("""(?i)\b(QAR)\b""") to "QAR",
            Regex("""(?i)\b(BHD)\b""") to "BHD",
            Regex("""(?i)\b(OMR)\b""") to "OMR",
            Regex("""(?i)ر\.س""") to "SAR",
            Regex("""(?i)⃁""") to "SAR",
            Regex("""(?i)€""") to "EUR",
            Regex("""(?i)£""") to "GBP",
        )
        for ((pattern, code) in patterns) {
            if (pattern.containsMatchIn(text)) return code
        }
        return null
    }

    private fun nativeFormatAmount(amount: Double, currency: String?): String {
        val formatted = String.format(Locale.ROOT, "%.2f", amount)
            .replace(Regex("""(\.\d*?[1-9])0+$"""), "$1")
            .replace(Regex("""\.0+$"""), "")
        return if (currency.isNullOrBlank()) {
            formatted
        } else {
            "${nativeDisplayCurrencyLabel(currency)} $formatted".trim()
        }
    }

    private fun nativeDisplayCurrencyLabel(currency: String): String {
        val code = currency.trim().uppercase(Locale.ROOT)
        return when (code) {
            "SAR", "⃁", "﷼" -> saudiRiyalSymbol()
            "AUD" -> "A$"
            "CAD" -> "C$"
            else -> code
        }
    }

    private fun saudiRiyalSymbol(): String {
        return if (Build.VERSION.SDK_INT >= 36) "⃁" else "SAR"
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
        if (nativeContainsSubscriptionActivationIndicators(lower)) return false
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

    private fun nativeNotificationId(source: String, message: String): Int {
        val normalizedSource = source.trim().lowercase(Locale.ROOT)
        val normalizedMessage = message.replace(Regex("""\s+"""), " ")
            .trim()
        val bytes = "$normalizedSource|$normalizedMessage".toByteArray(Charsets.UTF_8)
        var hash = 0x811c9dc5.toInt()
        for (byte in bytes) {
            hash = hash xor (byte.toInt() and 0xff)
            hash *= 0x01000193
        }
        return hash and 0x7fffffff
    }
}

package com.zakahwealth.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

class SmsCaptureReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            return
        }

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        val message = messages
            .joinToString(separator = "") { sms -> sms.messageBody.orEmpty() }
            .trim()
        if (message.isEmpty()) {
            return
        }

        val enabled = AndroidSmsCaptureBridge.isEnabled(context)
        if (!enabled) {
            return
        }

        if (!AndroidSmsCaptureBridge.hasSmsPermission(context)) {
            return
        }

        if (AndroidSmsCaptureBridge.isLikelyOtpOrSecurityMessage(message)) {
            return
        }

        if (!AndroidSmsCaptureBridge.isLikelyFinancialMessage(message)) {
            return
        }

        val sender = messages.firstOrNull()?.originatingAddress.orEmpty().trim()
        val receivedAtIso = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US).apply {
            timeZone = java.util.TimeZone.getTimeZone("UTC")
        }.format(java.util.Date())

        AndroidSmsCaptureBridge.enqueueOrDeliver(
            context,
            mapOf(
                "messageContent" to message,
                "source" to "sms",
                "sourceIdentifier" to (if (sender.isNotEmpty()) sender else "Android SMS"),
                "senderHeader" to sender,
                "receivedAt" to receivedAtIso,
                "platform" to "android",
            ),
        )
    }
}


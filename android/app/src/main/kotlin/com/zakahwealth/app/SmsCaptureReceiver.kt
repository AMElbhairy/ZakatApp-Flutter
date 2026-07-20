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

        val message = Telephony.Sms.Intents.getMessagesFromIntent(intent)
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

        AndroidSmsCaptureBridge.enqueueOrDeliver(
            context,
            mapOf(
                "messageContent" to message,
                "source" to "sms",
                "sourceIdentifier" to "Android SMS",
            ),
        )
    }
}

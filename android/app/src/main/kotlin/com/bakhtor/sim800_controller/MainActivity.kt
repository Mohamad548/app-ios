package com.bakhtor.sim800_controller

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.provider.Telephony
import android.app.PendingIntent
import android.telephony.SmsManager
import android.telephony.SmsMessage
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * SMS bridge: send commands, optional inbox events for STATUS replies,
 * best-effort deletion of our own sent rows from the SMS provider.
 */
class MainActivity : FlutterActivity() {

    private val methodChannelName = "sim800/sms"
    private val eventChannelName = "sim800/sms_inbox"
    private val smsRequestCode = 4711
    private val sentAction = "com.bakhtor.sim800_controller.SMS_SENT"
    private var pendingResult: MethodChannel.Result? = null
    private var sendResult: MethodChannel.Result? = null
    private var sentReceiver: BroadcastReceiver? = null
    private var eventSink: EventChannel.EventSink? = null
    private var smsReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    registerSmsReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    unregisterSmsReceiver()
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canSend" -> result.success(hasPermission(Manifest.permission.SEND_SMS))

                    "canReceive" -> result.success(
                        hasPermission(Manifest.permission.RECEIVE_SMS) &&
                            hasPermission(Manifest.permission.READ_SMS)
                    )

                    "shouldShowRationale" -> result.success(
                        ActivityCompat.shouldShowRequestPermissionRationale(
                            this,
                            Manifest.permission.SEND_SMS
                        )
                    )

                    "requestPermission" -> {
                        if (hasPermission(Manifest.permission.SEND_SMS)) {
                            result.success(true)
                            return@setMethodCallHandler
                        }
                        pendingResult?.success(false)
                        pendingResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.SEND_SMS),
                            smsRequestCode
                        )
                    }

                    "requestReceivePermission" -> {
                        val need = mutableListOf<String>()
                        if (!hasPermission(Manifest.permission.RECEIVE_SMS)) {
                            need += Manifest.permission.RECEIVE_SMS
                        }
                        if (!hasPermission(Manifest.permission.READ_SMS)) {
                            need += Manifest.permission.READ_SMS
                        }
                        if (need.isEmpty()) {
                            result.success(true)
                            return@setMethodCallHandler
                        }
                        pendingResult?.success(false)
                        pendingResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            need.toTypedArray(),
                            smsRequestCode
                        )
                    }

                    "openAppSettings" -> {
                        try {
                            val intent = Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.fromParts("package", packageName, null)
                            )
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (t: Throwable) {
                            result.error("SETTINGS", t.message, null)
                        }
                    }

                    "send" -> {
                        val number = call.argument<String>("number")
                        val message = call.argument<String>("message")
                        val hide = call.argument<Boolean>("hide") ?: true
                        when {
                            number.isNullOrBlank() || message.isNullOrBlank() ->
                                result.error("ARGS", "number or message is empty", null)

                            !hasPermission(Manifest.permission.SEND_SMS) ->
                                result.error("PERMISSION", "SEND_SMS not granted", null)

                            else -> try {
                                sendSms(number, message, hide, result)
                            } catch (t: Throwable) {
                                result.error("SEND_FAILED", t.message ?: "unknown", null)
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun registerSmsReceiver() {
        if (smsReceiver != null) return
        smsReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
                val bundle = intent.extras ?: return
                try {
                    @Suppress("DEPRECATION")
                    val pdus = bundle.get("pdus") as? Array<*> ?: return
                    val format = bundle.getString("format")
                    val sb = StringBuilder()
                    var from = ""
                    for (pdu in pdus) {
                        val bytes = pdu as ByteArray
                        val msg = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            SmsMessage.createFromPdu(bytes, format)
                        } else {
                            @Suppress("DEPRECATION")
                            SmsMessage.createFromPdu(bytes)
                        }
                        from = msg.displayOriginatingAddress ?: from
                        sb.append(msg.messageBody ?: "")
                    }
                    val body = sb.toString()
                    if (body.isNotEmpty()) {
                        eventSink?.success(
                            mapOf(
                                "from" to from,
                                "body" to body,
                            )
                        )
                    }
                } catch (_: Throwable) {
                    // ignore malformed PDUs
                }
            }
        }
        val filter = IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION)
        filter.priority = IntentFilter.SYSTEM_HIGH_PRIORITY
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(smsReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(smsReceiver, filter)
        }
    }

    private fun unregisterSmsReceiver() {
        smsReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Throwable) {
            }
        }
        smsReceiver = null
    }

    @Suppress("DEPRECATION")
    private fun sendSms(
        number: String,
        message: String,
        hide: Boolean,
        result: MethodChannel.Result
    ) {
        if (sendResult != null) {
            result.error("BUSY", "another SMS is still sending", null)
            return
        }
        sendResult = result
        val manager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(SmsManager::class.java) ?: SmsManager.getDefault()
        } else {
            SmsManager.getDefault()
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val sentIntent = PendingIntent.getBroadcast(
            this,
            0,
            Intent(sentAction).setPackage(packageName),
            flags
        )
        if (sentReceiver == null) {
            sentReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    val code = resultCode
                    val pending = sendResult
                    sendResult = null
                    if (code == android.app.Activity.RESULT_OK) {
                        if (hide) deleteSentBestEffort(number, message)
                        pending?.success(true)
                    } else {
                        pending?.error(
                            "SEND_FAILED",
                            "radio result $code",
                            null
                        )
                    }
                }
            }
            val filter = IntentFilter(sentAction)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(sentReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(sentReceiver, filter)
            }
        }
        // Protocol bodies are short ASCII; single-part is the normal path.
        manager.sendTextMessage(number, null, message, sentIntent, null)
    }

    /** Best-effort: many OEMs still log the SMS; full hide needs default-SMS role. */
    private fun deleteSentBestEffort(number: String, message: String) {
        try {
            val tail = number.filter { it.isDigit() }.takeLast(10)
            if (tail.isEmpty()) return
            contentResolver.delete(
                Uri.parse("content://sms/sent"),
                "address LIKE ? AND body = ?",
                arrayOf("%$tail", message)
            )
            contentResolver.delete(
                Uri.parse("content://sms/outbox"),
                "address LIKE ? AND body = ?",
                arrayOf("%$tail", message)
            )
        } catch (_: Throwable) {
            // No WRITE access as non-default SMS app — ignore.
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != smsRequestCode) return
        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        pendingResult?.success(granted)
        pendingResult = null
    }

    override fun onDestroy() {
        unregisterSmsReceiver()
        sentReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Throwable) {
            }
        }
        sentReceiver = null
        super.onDestroy()
    }

    private fun hasPermission(name: String): Boolean =
        ContextCompat.checkSelfPermission(this, name) ==
            PackageManager.PERMISSION_GRANTED
}

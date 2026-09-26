package dev.abdeldjalilchougui.ussd_session

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Sends single-response USSD requests through `TelephonyManager.sendUssdRequest` (API 26+),
 * lists active SIMs and opens the dialer as a fallback. It never reads or drives other apps' UI.
 */
class UssdSessionPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "send" -> send(call, result)
            "simCards" -> simCards(result)
            "permissionsStatus" -> result.success(
                mapOf(
                    "callPhone" to granted(Manifest.permission.CALL_PHONE),
                    "readPhoneState" to granted(Manifest.permission.READ_PHONE_STATE),
                ),
            )
            "dial" -> dial(call, result)
            else -> result.notImplemented()
        }
    }

    private fun granted(permission: String): Boolean =
        context.checkPermission(permission, Process.myPid(), Process.myUid()) ==
            PackageManager.PERMISSION_GRANTED

    private fun hasTelephony(): Boolean =
        context.packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)

    private fun send(call: MethodCall, result: Result) {
        val code = call.argument<String>("code")
        if (code.isNullOrEmpty()) {
            result.error("INVALID_CODE", "Missing USSD code", null)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.error(
                "UNSUPPORTED",
                "sendUssdRequest needs Android 8.0 (API 26); this device runs API ${Build.VERSION.SDK_INT}. Use dial() instead.",
                null,
            )
            return
        }
        val subscriptionId = call.argument<Number>("subscriptionId")?.toInt()
        val timeoutMillis = call.argument<Number>("timeoutMillis")?.toLong() ?: 30_000L
        sendApi26(code, subscriptionId, timeoutMillis, result)
    }

    @SuppressLint("MissingPermission")
    @RequiresApi(Build.VERSION_CODES.O)
    private fun sendApi26(code: String, subscriptionId: Int?, timeoutMillis: Long, result: Result) {
        if (!hasTelephony()) {
            result.error("UNSUPPORTED", "This device has no telephony feature", null)
            return
        }
        if (!granted(Manifest.permission.CALL_PHONE)) {
            result.error("CALL_PHONE_PERMISSION_DENIED", "CALL_PHONE permission is not granted", null)
            return
        }
        val base = context.getSystemService(TelephonyManager::class.java)
        if (base == null) {
            result.error("UNSUPPORTED", "TelephonyManager is not available", null)
            return
        }
        val manager = if (subscriptionId == null) {
            base
        } else {
            if (granted(Manifest.permission.READ_PHONE_STATE)) {
                val active = context.getSystemService(SubscriptionManager::class.java)
                    ?.activeSubscriptionInfoList
                    .orEmpty()
                    .map { it.subscriptionId }
                if (subscriptionId !in active) {
                    result.error(
                        "INVALID_SUBSCRIPTION",
                        "Subscription $subscriptionId is not an active SIM",
                        mapOf("activeSubscriptionIds" to active),
                    )
                    return
                }
            }
            base.createForSubscriptionId(subscriptionId)
        }
        UssdLogic.errorForSimState(manager.simState)?.let {
            result.error(it, "SIM is absent or not ready (state ${manager.simState})", null)
            return
        }

        val done = AtomicBoolean(false)
        val timeout = Runnable {
            if (done.compareAndSet(false, true)) {
                result.error("TIMEOUT", "No USSD reply within $timeoutMillis ms", null)
            }
        }
        val callback = object : TelephonyManager.UssdResponseCallback() {
            override fun onReceiveUssdResponse(
                telephonyManager: TelephonyManager,
                request: String,
                response: CharSequence,
            ) {
                if (done.compareAndSet(false, true)) {
                    mainHandler.removeCallbacks(timeout)
                    result.success(
                        mapOf(
                            "text" to response.toString(),
                            "subscriptionId" to subscriptionId,
                            "receivedAtMillis" to System.currentTimeMillis(),
                        ),
                    )
                }
            }

            override fun onReceiveUssdResponseFailed(
                telephonyManager: TelephonyManager,
                request: String,
                failureCode: Int,
            ) {
                if (done.compareAndSet(false, true)) {
                    mainHandler.removeCallbacks(timeout)
                    result.error(
                        UssdLogic.errorForFailureCode(failureCode),
                        "USSD request failed (failure code $failureCode)",
                        mapOf("failureCode" to failureCode),
                    )
                }
            }
        }
        try {
            mainHandler.postDelayed(timeout, timeoutMillis)
            manager.sendUssdRequest(code, callback, mainHandler)
        } catch (e: SecurityException) {
            if (done.compareAndSet(false, true)) {
                mainHandler.removeCallbacks(timeout)
                result.error("CALL_PHONE_PERMISSION_DENIED", e.message ?: "SecurityException", null)
            }
        } catch (e: RuntimeException) {
            if (done.compareAndSet(false, true)) {
                mainHandler.removeCallbacks(timeout)
                result.error("UNKNOWN", e.message ?: e.javaClass.name, null)
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun simCards(result: Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP_MR1) {
            result.error("UNSUPPORTED", "SubscriptionManager needs Android 5.1 (API 22)", null)
            return
        }
        if (!granted(Manifest.permission.READ_PHONE_STATE)) {
            result.error(
                "READ_PHONE_STATE_PERMISSION_DENIED",
                "READ_PHONE_STATE permission is not granted",
                null,
            )
            return
        }
        try {
            @Suppress("DEPRECATION")
            val list = SubscriptionManager.from(context).activeSubscriptionInfoList.orEmpty()
            result.success(
                list.map { info ->
                    val mcc: String?
                    val mnc: String?
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        mcc = info.mccString
                        mnc = info.mncString
                    } else {
                        @Suppress("DEPRECATION")
                        mcc = UssdLogic.formatMcc(info.mcc)
                        @Suppress("DEPRECATION")
                        mnc = UssdLogic.formatMnc(info.mnc)
                    }
                    UssdLogic.subscriptionMap(
                        subscriptionId = info.subscriptionId,
                        slotIndex = info.simSlotIndex,
                        carrierName = info.carrierName,
                        displayName = info.displayName,
                        mcc = mcc,
                        mnc = mnc,
                        countryIso = info.countryIso,
                    )
                },
            )
        } catch (e: SecurityException) {
            result.error("READ_PHONE_STATE_PERMISSION_DENIED", e.message ?: "SecurityException", null)
        }
    }

    private fun dial(call: MethodCall, result: Result) {
        val code = call.argument<String>("code")
        if (code.isNullOrEmpty()) {
            result.error("INVALID_CODE", "Missing USSD code", null)
            return
        }
        val intent = Intent(Intent.ACTION_DIAL, Uri.parse(UssdLogic.telUri(code)))
        val host = activity
        try {
            if (host != null) {
                host.startActivity(intent)
            } else {
                context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            }
            result.success(null)
        } catch (e: ActivityNotFoundException) {
            result.error("NO_DIALER", "No app handles ACTION_DIAL", null)
        }
    }

    private companion object {
        const val CHANNEL = "dev.abdeldjalilchougui/ussd_session"
    }
}

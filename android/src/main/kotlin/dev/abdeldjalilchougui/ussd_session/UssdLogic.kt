package dev.abdeldjalilchougui.ussd_session

/** Pure logic shared by the plugin, kept free of Android types so it can be unit tested. */
internal object UssdLogic {
    /** `TelephonyManager.USSD_RETURN_FAILURE`. */
    const val USSD_RETURN_FAILURE = -1

    /** `TelephonyManager.USSD_ERROR_SERVICE_UNAVAIL`. */
    const val USSD_ERROR_SERVICE_UNAVAIL = -2

    private const val SIM_STATE_UNKNOWN = 0
    private const val SIM_STATE_ABSENT = 1
    private const val SIM_STATE_READY = 5

    /** Channel error code for a `UssdResponseCallback.onReceiveUssdResponseFailed` failure code. */
    fun errorForFailureCode(failureCode: Int): String = when (failureCode) {
        USSD_RETURN_FAILURE -> "USSD_RETURN_FAILURE"
        USSD_ERROR_SERVICE_UNAVAIL -> "SERVICE_UNAVAILABLE"
        else -> "UNKNOWN"
    }

    /** Channel error code for a `TelephonyManager.getSimState()` value, or null if sending may proceed. */
    fun errorForSimState(state: Int): String? = when (state) {
        SIM_STATE_READY, SIM_STATE_UNKNOWN -> null
        else -> "NO_SIM"
    }

    /**
     * Builds a `tel:` URI for `ACTION_DIAL`. Digits, `*` and `+` are kept; everything else is
     * percent-encoded as UTF-8, so `#` becomes `%23` instead of starting a URI fragment.
     */
    fun telUri(code: String): String {
        val out = StringBuilder("tel:")
        for (byte in code.toByteArray(Charsets.UTF_8)) {
            val c = byte.toInt() and 0xFF
            if (c in '0'.code..'9'.code || c == '*'.code || c == '+'.code) {
                out.append(c.toChar())
            } else {
                out.append('%').append(HEX[c shr 4]).append(HEX[c and 0x0F])
            }
        }
        return out.toString()
    }

    private val HEX = "0123456789ABCDEF".toCharArray()

    /** Formats a legacy integer MCC (Android < 10) as three digits, or null when unknown. */
    fun formatMcc(mcc: Int): String? =
        if (mcc <= 0 || mcc == Int.MAX_VALUE) null else mcc.toString().padStart(3, '0')

    /**
     * Formats a legacy integer MNC (Android < 10). A leading zero is restored for one-digit values;
     * a three-digit MNC with a leading zero cannot be recovered from the integer.
     */
    fun formatMnc(mnc: Int): String? =
        if (mnc < 0 || mnc == Int.MAX_VALUE) null else mnc.toString().padStart(2, '0')

    /** Builds the channel map for one active subscription. Blank strings become null. */
    fun subscriptionMap(
        subscriptionId: Int,
        slotIndex: Int,
        carrierName: CharSequence?,
        displayName: CharSequence?,
        mcc: String?,
        mnc: String?,
        countryIso: String?,
    ): Map<String, Any?> = mapOf(
        "subscriptionId" to subscriptionId,
        "slotIndex" to slotIndex,
        "carrierName" to clean(carrierName),
        "displayName" to clean(displayName),
        "mcc" to clean(mcc),
        "mnc" to clean(mnc),
        "countryIso" to clean(countryIso)?.lowercase(),
    )

    private fun clean(value: CharSequence?): String? =
        value?.toString()?.trim()?.takeIf { it.isNotEmpty() }
}

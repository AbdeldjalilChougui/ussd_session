package dev.abdeldjalilchougui.ussd_session

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

internal class UssdLogicTest {
    @Test
    fun failureCode_mapsPlatformConstants() {
        // TelephonyManager.USSD_RETURN_FAILURE == -1
        assertEquals("USSD_RETURN_FAILURE", UssdLogic.errorForFailureCode(-1))
        // TelephonyManager.USSD_ERROR_SERVICE_UNAVAIL == -2
        assertEquals("SERVICE_UNAVAILABLE", UssdLogic.errorForFailureCode(-2))
    }

    @Test
    fun failureCode_unknownValuesMapToUnknown() {
        assertEquals("UNKNOWN", UssdLogic.errorForFailureCode(0))
        assertEquals("UNKNOWN", UssdLogic.errorForFailureCode(-3))
        assertEquals("UNKNOWN", UssdLogic.errorForFailureCode(42))
    }

    @Test
    fun telUri_encodesHash() {
        assertEquals("tel:*222%23", UssdLogic.telUri("*222#"))
        assertEquals("tel:%23100%23", UssdLogic.telUri("#100#"))
        assertEquals("tel:*123*1*2%23", UssdLogic.telUri("*123*1*2#"))
        assertEquals("tel:*200*+213555%23", UssdLogic.telUri("*200*+213555#"))
    }

    @Test
    fun telUri_percentEncodesAnythingUnexpected() {
        assertEquals("tel:*1%202%23", UssdLogic.telUri("*1 2#"))
        assertEquals("tel:%25%23", UssdLogic.telUri("%#"))
    }

    @Test
    fun simState_absentAndNotReadyAreErrors() {
        assertEquals("NO_SIM", UssdLogic.errorForSimState(1)) // ABSENT
        assertEquals("NO_SIM", UssdLogic.errorForSimState(2)) // PIN_REQUIRED
        assertEquals("NO_SIM", UssdLogic.errorForSimState(6)) // NOT_READY
        assertNull(UssdLogic.errorForSimState(5)) // READY
        assertNull(UssdLogic.errorForSimState(0)) // UNKNOWN: let the network decide
    }

    @Test
    fun mccMnc_formatsLegacyIntegers() {
        assertEquals("603", UssdLogic.formatMcc(603))
        assertEquals("001", UssdLogic.formatMcc(1))
        assertNull(UssdLogic.formatMcc(0))
        assertNull(UssdLogic.formatMcc(Int.MAX_VALUE))
        assertEquals("01", UssdLogic.formatMnc(1))
        assertEquals("03", UssdLogic.formatMnc(3))
        assertEquals("310", UssdLogic.formatMnc(310))
        assertNull(UssdLogic.formatMnc(Int.MAX_VALUE))
        assertNull(UssdLogic.formatMnc(-1))
    }

    @Test
    fun subscriptionMap_buildsAllFields() {
        val map = UssdLogic.subscriptionMap(
            subscriptionId = 3,
            slotIndex = 1,
            carrierName = "Djezzy",
            displayName = " SIM 2 ",
            mcc = "603",
            mnc = "02",
            countryIso = "DZ",
        )
        assertEquals(
            mapOf(
                "subscriptionId" to 3,
                "slotIndex" to 1,
                "carrierName" to "Djezzy",
                "displayName" to "SIM 2",
                "mcc" to "603",
                "mnc" to "02",
                "countryIso" to "dz",
            ),
            map,
        )
    }

    @Test
    fun subscriptionMap_blankValuesBecomeNull() {
        val map = UssdLogic.subscriptionMap(
            subscriptionId = 1,
            slotIndex = 0,
            carrierName = "",
            displayName = null,
            mcc = " ",
            mnc = null,
            countryIso = "",
        )
        assertNull(map["carrierName"])
        assertNull(map["displayName"])
        assertNull(map["mcc"])
        assertNull(map["mnc"])
        assertNull(map["countryIso"])
        assertEquals(1, map["subscriptionId"])
        assertEquals(0, map["slotIndex"])
    }
}

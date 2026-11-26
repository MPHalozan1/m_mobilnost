package si.marprom.m_mobilnost

import android.content.Context
import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference
import java.nio.charset.StandardCharsets

/**
 * Android Host Card Emulation (HCE) service allowing the phone's built-in NFC
 * chip to act as a contactless Marprom Vozovnica transit card (AID F222222222).
 */
class VozovnicaHceService : HostApduService() {

    companion object {
        const val PREFS_NAME = "marprom_hce_prefs"
        const val KEY_TICKET_ID = "armed_ticket_id"
        const val KEY_PAYLOAD = "armed_ticket_payload"
        const val KEY_ARMED = "is_armed"
        const val KEY_LAST_TAP_MS = "last_tap_ms"
        const val AID_HEX = "F222222222"

        private val SELECT_APDU_HEADER = byteArrayOf(0x00.toByte(), 0xA4.toByte(), 0x04.toByte(), 0x00.toByte())
        private val SW_OK = byteArrayOf(0x90.toByte(), 0x00.toByte())
        private val SW_NOT_ARMED = byteArrayOf(0x69.toByte(), 0x85.toByte())
        private val SW_UNKNOWN = byteArrayOf(0x6A.toByte(), 0x82.toByte())

        @Volatile
        private var channelRef: WeakReference<MethodChannel>? = null

        fun attachFlutterChannel(channel: MethodChannel) {
            channelRef = WeakReference(channel)
        }

        fun armTicket(context: Context, ticketId: String, payload: String) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_TICKET_ID, ticketId)
                .putString(KEY_PAYLOAD, payload)
                .putBoolean(KEY_ARMED, true)
                .apply()
        }

        fun disarmTicket(context: Context) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .remove(KEY_TICKET_ID)
                .remove(KEY_PAYLOAD)
                .putBoolean(KEY_ARMED, false)
                .apply()
        }

        private fun notifyFlutterTapValidated(ticketId: String, tapMs: Long) {
            val channel = channelRef?.get() ?: return
            Handler(Looper.getMainLooper()).post {
                try {
                    channel.invokeMethod(
                        "onTicketValidated",
                        mapOf(
                            "ticketId" to ticketId,
                            "timestampMs" to tapMs
                        )
                    )
                } catch (_: Exception) {
                    // Flutter engine may be detached during background tap.
                }
            }
        }
    }

    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray {
        if (commandApdu == null || commandApdu.size < 4) {
            return SW_UNKNOWN
        }

        val isSelect = commandApdu[0] == SELECT_APDU_HEADER[0] &&
            commandApdu[1] == SELECT_APDU_HEADER[1] &&
            commandApdu[2] == SELECT_APDU_HEADER[2] &&
            commandApdu[3] == SELECT_APDU_HEADER[3]

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val armed = prefs.getBoolean(KEY_ARMED, false)
        val ticketId = prefs.getString(KEY_TICKET_ID, "") ?: ""
        val payload = prefs.getString(KEY_PAYLOAD, null)

        if (!armed || payload.isNullOrBlank()) {
            return if (isSelect) SW_NOT_ARMED else SW_UNKNOWN
        }

        val tapMs = System.currentTimeMillis()
        prefs.edit().putLong(KEY_LAST_TAP_MS, tapMs).apply()
        notifyFlutterTapValidated(ticketId, tapMs)

        val dataBytes = payload.toByteArray(StandardCharsets.UTF_8)
        return dataBytes + SW_OK
    }

    override fun onDeactivated(reason: Int) {
        // Stateless APDU exchange; armed ticket stays cached until expiration or swap.
    }
}

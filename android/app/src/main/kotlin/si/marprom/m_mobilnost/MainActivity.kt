package si.marprom.m_mobilnost

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.nfc.NfcAdapter
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val nfcChannelName = "si.marprom.m_mobilnost/nfc"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, nfcChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getNfcStatus" -> {
                        val adapter = NfcAdapter.getDefaultAdapter(this)
                        val hasNfc = adapter != null
                        val isNfcEnabled = adapter?.isEnabled == true
                        val hasHce = packageManager.hasSystemFeature(PackageManager.FEATURE_NFC_HOST_CARD_EMULATION)
                        val prefs = getSharedPreferences(MarpromHceTicketService.PREFS_NAME, Context.MODE_PRIVATE)
                        result.success(
                            mapOf(
                                "hasNfcHardware" to hasNfc,
                                "isNfcEnabled" to isNfcEnabled,
                                "hasHce" to hasHce,
                                "isHceArmed" to prefs.getBoolean(MarpromHceTicketService.KEY_ARMED, false),
                                "armedTicketId" to prefs.getString(MarpromHceTicketService.KEY_TICKET_ID, null),
                                "aidHex" to MarpromHceTicketService.AID_HEX
                            )
                        )
                    }

                    "armTicketHce" -> {
                        val ticketId = call.argument<String>("ticketId") ?: ""
                        val payload = call.argument<String>("payload") ?: ""
                        if (ticketId.isBlank() || payload.isBlank()) {
                            result.error("INVALID_ARGS", "ticketId and payload are required", null)
                        } else {
                            MarpromHceTicketService.armTicket(this, ticketId, payload)
                            result.success(true)
                        }
                    }

                    "disarmTicketHce" -> {
                        MarpromHceTicketService.disarmTicket(this)
                        result.success(true)
                    }

                    "openNfcSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_NFC_SETTINGS))
                            result.success(true)
                        } catch (_: Exception) {
                            try {
                                startActivity(Intent(Settings.ACTION_WIRELESS_SETTINGS))
                                result.success(true)
                            } catch (_: Exception) {
                                result.success(false)
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}

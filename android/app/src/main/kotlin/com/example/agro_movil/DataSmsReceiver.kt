package com.example.agro_movil

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * Recibe los SMS de DATOS dirigidos al puerto de AgroSmart (ver AndroidManifest.xml).
 * Android los entrega solo a la app que registró ese puerto: no pasan por la app de Mensajes.
 */
class DataSmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "android.intent.action.DATA_SMS_RECEIVED") return
        val mensajes = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        for (m in mensajes) {
            val datos = m.userData ?: continue
            DataSmsStore.agregar(context, m.originatingAddress ?: "", m.timestampMillis, datos)
        }
        DataSmsPlugin.avisarNuevo()
    }
}

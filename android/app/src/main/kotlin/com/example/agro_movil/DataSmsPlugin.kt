package com.example.agro_movil

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.SmsManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicInteger

/**
 * Puente Flutter <-> SMS de datos.
 *  - enviar(destino, puerto, datos): manda UN SMS de datos y responde {ok, codigo|error}.
 *  - bandeja(): devuelve (y vacía) los SMS de datos recibidos [{a, t, d}].
 *  - hacia Flutter: "nuevo" cuando llega un SMS de datos y la app está viva.
 */
class DataSmsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var canal: MethodChannel? = null
    private var ctx: Context? = null
    private val ui = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        ctx = binding.applicationContext
        canal = MethodChannel(binding.binaryMessenger, CANAL).also { it.setMethodCallHandler(this) }
        instancia = this
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        canal?.setMethodCallHandler(null)
        canal = null
        ctx = null
        if (instancia === this) instancia = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val c = ctx
        if (c == null) {
            result.error("sin_contexto", "El plugin no está conectado", null)
            return
        }
        when (call.method) {
            "enviar" -> enviar(c, call, result)
            "bandeja" -> result.success(DataSmsStore.vaciar(c))
            else -> result.notImplemented()
        }
    }

    private fun enviar(c: Context, call: MethodCall, result: MethodChannel.Result) {
        val destino = call.argument<String>("destino")
        val puerto = call.argument<Int>("puerto")
        val datos = call.argument<ByteArray>("datos")
        if (destino.isNullOrBlank() || puerto == null || datos == null) {
            result.error("argumentos", "Faltan destino, puerto o datos", null)
            return
        }

        val accion = "com.example.agro_movil.DATASMS_ENVIADO_" + contador.incrementAndGet()
        var respondido = false

        fun responder(valores: Map<String, Any?>, receptor: BroadcastReceiver?) {
            if (respondido) return
            respondido = true
            if (receptor != null) {
                try { c.unregisterReceiver(receptor) } catch (e: Exception) { /* ya desregistrado */ }
            }
            result.success(valores)
        }

        // Android avisa por este receptor si el SMS salió (RESULT_OK) o falló.
        val receptor = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                responder(mapOf("ok" to (resultCode == Activity.RESULT_OK), "codigo" to resultCode), this)
            }
        }
        val filtro = IntentFilter(accion)
        if (Build.VERSION.SDK_INT >= 33) {
            c.registerReceiver(receptor, filtro, Context.RECEIVER_NOT_EXPORTED)
        } else {
            c.registerReceiver(receptor, filtro)
        }

        val banderas = PendingIntent.FLAG_ONE_SHOT or
            (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)
        val enviado = PendingIntent.getBroadcast(c, 0, Intent(accion).setPackage(c.packageName), banderas)

        try {
            gestor(c).sendDataMessage(destino, null, puerto.toShort(), datos, enviado, null)
        } catch (e: Exception) {
            responder(mapOf("ok" to false, "error" to (e.message ?: "excepcion")), receptor)
            return
        }
        // Si el sistema no avisa en 20 s se da por fallido.
        ui.postDelayed({ responder(mapOf("ok" to false, "error" to "sin_respuesta"), receptor) }, 20000)
    }

    @Suppress("DEPRECATION")
    private fun gestor(c: Context): SmsManager =
        if (Build.VERSION.SDK_INT >= 31) c.getSystemService(SmsManager::class.java) else SmsManager.getDefault()

    companion object {
        const val CANAL = "agrosmart/datasms"
        private val contador = AtomicInteger(0)
        @Volatile private var instancia: DataSmsPlugin? = null

        /** Lo llama el receptor: si la app está viva, Flutter lee el buzón al instante. */
        fun avisarNuevo() {
            val p = instancia ?: return
            p.ui.post { p.canal?.invokeMethod("nuevo", null) }
        }
    }
}

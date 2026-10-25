package com.example.agro_movil

import android.content.Context
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject

/**
 * Buzón nativo de SMS de datos. El receptor guarda aquí cada SMS aunque la app esté cerrada;
 * Flutter los lee (y vacía el buzón) cuando se abre o cuando el plugin le avisa.
 */
object DataSmsStore {
    private const val ARCHIVO = "agro_datasms"
    private const val CLAVE = "cola"
    private const val MAXIMO = 200

    @Synchronized
    fun agregar(c: Context, origen: String, ts: Long, datos: ByteArray) {
        val p = c.getSharedPreferences(ARCHIVO, Context.MODE_PRIVATE)
        val actual = try { JSONArray(p.getString(CLAVE, "[]")) } catch (e: Exception) { JSONArray() }
        actual.put(
            JSONObject()
                .put("a", origen)
                .put("t", ts)
                .put("d", Base64.encodeToString(datos, Base64.NO_WRAP))
        )
        val inicio = if (actual.length() > MAXIMO) actual.length() - MAXIMO else 0
        val recortado = JSONArray()
        for (i in inicio until actual.length()) recortado.put(actual.get(i))
        // commit (no apply): el receptor puede terminar antes de que apply() escriba.
        p.edit().putString(CLAVE, recortado.toString()).commit()
    }

    /** Devuelve todo lo guardado y deja el buzón vacío. */
    @Synchronized
    fun vaciar(c: Context): List<Map<String, Any>> {
        val p = c.getSharedPreferences(ARCHIVO, Context.MODE_PRIVATE)
        val arr = try { JSONArray(p.getString(CLAVE, "[]")) } catch (e: Exception) { JSONArray() }
        p.edit().remove(CLAVE).commit()
        val salida = ArrayList<Map<String, Any>>()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            salida.add(
                mapOf(
                    "a" to o.getString("a"),
                    "t" to o.getLong("t"),
                    "d" to Base64.decode(o.getString("d"), Base64.NO_WRAP)
                )
            )
        }
        return salida
    }
}

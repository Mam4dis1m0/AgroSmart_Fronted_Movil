# AgroSmart · app Flutter (cliente del backend NestJS)

Consume la API de `AgroSmart_Backend` (JWT). **No** se conecta a Supabase directamente.
Por defecto apunta al backend LOCAL; en Android usa `127.0.0.1` (requiere `adb reverse`
al depurar por USB). Para configurar otro servidor, usa `--dart-define=API_URL=...`
(por ejemplo, Render/Railway).

## Instalar
1. `flutter create agrosmart_proto --org co.agrosmart`
2. Copia `pubspec.yaml` y `lib/` encima del proyecto generado, luego `flutter pub get`.
3. Android: en `android/app/src/main/AndroidManifest.xml` agrega
   `<uses-permission android:name="android.permission.INTERNET"/>` y, para http local,
   `android:usesCleartextTraffic="true"` dentro de `<application ...>`.
4. Backend: `npm run start:dev` (con su `.env`). Para depurar un celular físico por USB:
   ejecuta `adb reverse tcp:3000 tcp:3000` una vez tras conectar el teléfono y luego
   `flutter run -d ID_DEL_DISPOSITIVO`. La app apunta automáticamente a
   `http://127.0.0.1:3000`. En el emulador Android, usa
   `--dart-define=API_URL=http://10.0.2.2:3000`.

## Qué incluye
- Cuenta: login, registro (dueño/comprador), recuperar contraseña, selector y creación de finca, perfil.
- Inicio: KPIs de la finca (tareas, stock bajo, cultivos, miembros, ventas).
- Producción: CRUD de lotes, cultivos y cosechas.
- Operación: tareas (crear, asignar, cambiar estado, completar, editar, borrar) e insumos (CRUD, compras, alerta de stock bajo).
- Mercado: catálogo + detalle + comprar/carrito (comprador); mis ofertas y ventas (aceptar/rechazar/cerrar) (dueño).
- Más: equipo (alta de empleados, activar/desactivar), nómina, plan/suscripción, asistente IA, auditoría, avisos.
- Roles: admin / empleado / comprador, con permisos igual que el backend.

## Aún no incluido
Palmas y producción de palma, reportes/exportar PDF, subir fotos de ofertas, login con Google,
wishlist, mensajería/SMS, modo offline con cola de sincronización.

## Añadido en la 3.ª versión
Palmas y producción de palma · reportes (costos por cultivo + exportar CSV/Excel y compartir) ·
fotos de ofertas (galería → Cloudinary vía backend) · favoritos (wishlist) ·
login con Google (`--dart-define=GOOGLE_CLIENT_ID=...`, client ID *web*) ·
modo sin conexión de solo lectura (caché de las últimas listas) con aviso en pantalla.

iOS: agrega `NSPhotoLibraryUsageDescription` en Info.plist para elegir fotos.

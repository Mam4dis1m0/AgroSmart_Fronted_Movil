# AgroSmart · app Flutter (cliente del backend NestJS)

Consume la API de `AgroSmart_Backend` (JWT). **No** se conecta a Supabase directamente.
Por defecto apunta al backend LOCAL; en Android usa `127.0.0.1` (requiere `adb reverse`
al depurar por USB). Para configurar otro servidor, usa `--dart-define=API_URL=...`
(por ejemplo, Render/Railway).

## Instalar
1. `flutter create agrosmart_proto --org co.agrosmart`
2. Copia `pubspec.yaml` y `lib/` encima del proyecto generado, luego `flutter pub get`.
3. Android: el permiso de Internet y la política de tráfico por variante ya están en el
   manifiesto. HTTP solo se permite al depurar; los builds `release` requieren HTTPS.
4. Backend: `npm run start:dev` (con su `.env`). Para depurar un celular físico por USB,
   conecta y autoriza el teléfono. En PowerShell, ejecuta `adb reverse tcp:3000 tcp:3000`
   si `adb` está en el PATH. Si PowerShell no reconoce `adb` y el SDK está en la ubicación
   habitual de Windows, usa:

   ```powershell
   & "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" reverse tcp:3000 tcp:3000
   ```

   Si instalaste el SDK en otra carpeta, cambia la ruta por la ubicación de
   `platform-tools\adb.exe`. Luego ejecuta `flutter run -d ID_DEL_DISPOSITIVO`.
   En un celular físico por USB, la app apunta a `http://127.0.0.1:3000`; `adb reverse`
   permite que esa dirección llegue al backend de la PC incluso si el teléfono no tiene
   Wi-Fi o datos. En el emulador Android, usa
   `--dart-define=API_URL=http://10.0.2.2:3000`. No uses `10.0.2.2` en un celular físico.

## Seguridad móvil y build de producción

- La sesión, los logins locales, la caché de respuestas, la cola offline y los metadatos de
   adjuntos se guardan mediante `flutter_secure_storage` (Keystore/Keychain). Al abrir una
   versión actualizada, los valores equivalentes de SharedPreferences se migran y se borran
   después de confirmar su copia segura.
- Android desactiva las copias de seguridad de la app. El tráfico HTTP solo está permitido
   en `debug`; en `release` se rechaza HTTP tanto en la configuración nativa como en el
   cliente API.
- Los archivos de fotos/audio que esperan por conectividad todavía se guardan en el
   directorio privado de la app, pero no se cifran individualmente. No instales una versión
   con datos reales en un dispositivo compartido o rooteado mientras esto siga pendiente.
- No publiques el APK de `debug`. Para un build de producción crea una clave propia y
   configura el archivo local ignorado `android/key.properties` con `keyAlias`, `keyPassword`,
   `storeFile` y `storePassword`. Nunca envíes el archivo de propiedades ni el keystore al
   repositorio o al informe.

Ejemplo para crear una clave en PowerShell (guárdala en un lugar seguro y haz una copia
fuera del equipo):

```powershell
& "$env:JAVA_HOME\bin\keytool.exe" -genkeypair -v `
   -keystore "$env:USERPROFILE\agrosmart-release.jks" `
   -alias agrosmart -keyalg RSA -keysize 2048 -validity 10000
```

En `android/key.properties`, coloca los valores reales de esa clave. Para una ruta de
Windows, escapa las barras invertidas en `storeFile`, por ejemplo:
`storeFile=C:\\Users\\TU_USUARIO\\agrosmart-release.jks`.

Compila indicando la URL HTTPS pública del backend:

```powershell
flutter build apk --release --dart-define=API_URL=https://TU_DOMINIO_API
```

La compilación `release` falla intencionalmente si no existe `android/key.properties`.
En desarrollo local, continúa usando `flutter run` con HTTP y `adb reverse` como se indica
arriba.

## Ver datos de ejemplo
Para recorrer la app con datos ficticios de una finca, lotes, cultivos y cosechas sin
conectarse ni escribir en el backend, ejecuta:

```powershell
flutter run --dart-define=DEMO=true
```

El modo de demostración incluye cultivos de ciclo y permanentes, así como varias
cosechas del mismo cultivo permanente. La app muestra un aviso cuando presenta estos
datos. Sin `DEMO=true`, la aplicación usa el backend configurado y los datos reales
de la cuenta.

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

## 4.ª versión: diseño Figma + Market + AgroChat
- Tema y tipografías del diseño (Fraunces + Outfit vía `google_fonts`, necesita internet la primera vez).
- Login rediseñado. «Recordar mis datos» guarda solo el correo, nunca la contraseña.
- Comprador: Inicio (market), Explorar, Pedidos, Chats (con insignia de no leídos) y Perfil.
- AgroChat sobre `/api/v1/mensajeria` + Socket.IO `/mercado` (`socket_io_client`). Solo comprador y admin.
- Publicar producto con **cámara** (o galería), hasta 6 fotos; se suben por `POST /api/v1/marketplace/fotos`.

### Permisos de cámara
- iOS (`ios/Runner/Info.plist`): `NSCameraUsageDescription` y `NSPhotoLibraryUsageDescription`.
- Android: `image_picker` abre la cámara del sistema; no requiere configuración extra.

### Requisito del backend para las fotos
`main.ts` debe subir el límite de JSON (por defecto 100 KB y una foto en base64 pesa más):
```ts
const app = await NestFactory.create<NestExpressApplication>(AppModule, { abortOnError: false });
app.useBodyParser('json', { limit: '10mb' });
```
(`import { NestExpressApplication } from '@nestjs/platform-express';`)

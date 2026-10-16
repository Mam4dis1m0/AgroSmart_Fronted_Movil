// Datos mock EXACTOS del prototipo (carpeta agrosmart-design / src/mockData.ts),
// mapeados a las formas que esperan las pantallas de la app.
//
// Con kDemoMode la app NO usa el backend: responde todo desde aquí.
// Se activa solo con: flutter run --dart-define=DEMO=true
library;

import 'package:dio/dio.dart';

const bool kDemoMode = bool.fromEnvironment('DEMO');

// ── Sesión (usuario + fincas del prototipo) ─────────────────────────────────
List<Map<String, dynamic>> demoFincas() => [
      {
        'idfinca': 1,
        'nombre': 'Finca San José Del Magdalena',
        'ubicacion': 'Zona Bananera - Magdalena',
        'rol': 'admin',
        'plan': 'premium',
      },
      {
        'idfinca': 2,
        'nombre': 'Hacienda La Esperanza',
        'ubicacion': 'Valle del Cauca - Palmira',
        'rol': 'admin',
        'plan': 'freemium',
      },
    ];

Map<String, dynamic> demoUsuario() => {
      'id': 1,
      'nombre': 'Carlos',
      'apellido': 'Mendoza',
      'email': 'carlos.mendoza@agrosmart.co',
      'role': 'admin',
      'fotoperfil': null,
    };

Map<String, dynamic> demoLoginResponse() => {
      'usuario': demoUsuario(),
      'token': 'demo-token',
      'idfinca': 1,
      'fincas': demoFincas(),
      'requiereSeleccionFinca': false,
    };

// ── Finca activa / dashboard ────────────────────────────────────────────────
Map<String, dynamic> _fincaActiva() => {
      'idfinca': 1,
      'nombre': 'Finca San José Del Magdalena',
      'ubicacion': 'Zona Bananera - Magdalena',
      'municipio': 'Ciénaga',
      'departamento': 'Magdalena',
      'tipoproduccion': 'Palma',
      'plan': 'premium',
      'hectareas': 120,
      'miembros': 3,
    };

List<Map<String, dynamic>> _dashboard() => [
      {
        'idfinca': 1,
        'tareas_pendientes': 3,
        'tareas_en_progreso': 2,
        'tareas_completadas': 1,
        'insumos_stock_bajo': 2,
        'cultivos': 4,
        'miembros': 3,
        'ventas_marketplace': 26800000,
      },
      {
        'idfinca': 2,
        'tareas_pendientes': 0,
        'tareas_en_progreso': 0,
        'tareas_completadas': 0,
        'insumos_stock_bajo': 0,
        'cultivos': 0,
        'miembros': 1,
        'ventas_marketplace': 0,
      },
    ];

List<Map<String, dynamic>> _miembros() => [
      {
        'idusuario': 1,
        'primernombre': 'Carlos',
        'primerapellido': 'Mendoza',
        'email': 'carlos.mendoza@agrosmart.co',
        'rol': 'admin',
        'activo': true,
        'telefono': '+57 312 884 9201',
      },
      {
        'idusuario': 3,
        'primernombre': 'Mateo',
        'primerapellido': 'Ortiz',
        'email': 'mateo.ortiz@fincasanjose.co',
        'rol': 'empleado',
        'activo': true,
        'telefono': '+57 301 552 1109',
      },
      {
        'idusuario': 4,
        'primernombre': 'Javier',
        'primerapellido': 'Alvarado',
        'email': 'javier.alvarado@agrosmart.co',
        'rol': 'empleado',
        'activo': true,
        'telefono': '+57 314 772 3388',
      },
    ];

// ── Producción: lotes, cultivos, palmas, cosechas, prod. palma ──────────────
List<Map<String, dynamic>> _lotes() => [
      {
        'idlote': 1,
        'nombre': 'Lote 1 - Palma Africana (Tenera)',
        'areahectareas': 25,
        'ubicacion': 'Finca San José · Ciénaga, Magdalena',
        'descripcion': 'Palma africana (Tenera) en producción, 25 Ha.',
        'cultivos': [
          {'tipo': 'Palma'}
        ],
      },
      {
        'idlote': 2,
        'nombre': 'Lote 2 - Maíz Blanco Híbrido',
        'areahectareas': 18,
        'ubicacion': 'Finca San José · Ciénaga, Magdalena',
        'descripcion': 'Maíz blanco híbrido, 18 Ha.',
        'cultivos': [
          {'tipo': 'Maíz'}
        ],
      },
      {
        'idlote': 3,
        'nombre': 'Lote 3 - Cacao Trinitario Fino Aroma',
        'areahectareas': 12,
        'ubicacion': 'Finca San José · Ciénaga, Magdalena',
        'descripcion': 'Cacao trinitario fino de aroma, 12 Ha.',
        'cultivos': [
          {'tipo': 'Cacao'}
        ],
      },
      {
        'idlote': 4,
        'nombre': 'Lote 4 - Arroz Fedearroz 68',
        'areahectareas': 30,
        'ubicacion': 'Finca San José · Ciénaga, Magdalena',
        'descripcion': 'Arroz Fedearroz 68, 30 Ha.',
        'cultivos': [
          {'tipo': 'Arroz'}
        ],
      },
    ];

List<Map<String, dynamic>> _cultivos() => [
      {
        'idcultivo': 1,
        'tipo': 'Palma',
        'nombrelote': 'Lote 1 - Palma Africana (Tenera)',
        'idlote': {'idlote': 1, 'nombre': 'Lote 1 - Palma Africana (Tenera)'},
        'fechasiembra': '2021-03-15',
        'fechacosechaestimada': '2026-10-18',
      },
      {
        'idcultivo': 2,
        'tipo': 'Maíz',
        'nombrelote': 'Lote 2 - Maíz Blanco Híbrido',
        'idlote': {'idlote': 2, 'nombre': 'Lote 2 - Maíz Blanco Híbrido'},
        'fechasiembra': '2024-01-10',
        'fechacosechaestimada': '2026-11-06',
      },
      {
        'idcultivo': 3,
        'tipo': 'Cacao',
        'nombrelote': 'Lote 3 - Cacao Trinitario Fino Aroma',
        'idlote': {'idlote': 3, 'nombre': 'Lote 3 - Cacao Trinitario Fino Aroma'},
        'fechasiembra': '2022-06-20',
        'fechacosechaestimada': '2026-10-20',
      },
      {
        'idcultivo': 4,
        'tipo': 'Arroz',
        'nombrelote': 'Lote 4 - Arroz Fedearroz 68',
        'idlote': {'idlote': 4, 'nombre': 'Lote 4 - Arroz Fedearroz 68'},
        'fechasiembra': '2024-02-01',
        'fechacosechaestimada': '2026-11-27',
      },
    ];

List<Map<String, dynamic>> _palmas() => [
      {
        'idpalma': 1,
        'codigo': 'PAL-A1-001',
        'variedad': 'Tenera',
        'fechasiembra': '2021-03-15',
        'estadosanitario': 'Sano',
        'idlote': {'idlote': 1, 'nombre': 'Lote 1 - Palma Africana (Tenera)'},
        'observaciones': 'Índice de madurez óptimo.',
      },
      {
        'idpalma': 2,
        'codigo': 'PAL-A1-002',
        'variedad': 'Tenera',
        'fechasiembra': '2021-03-15',
        'estadosanitario': 'En observación',
        'idlote': {'idlote': 1, 'nombre': 'Lote 1 - Palma Africana (Tenera)'},
        'observaciones': 'Presencia leve de Opsiphanes.',
      },
      {
        'idpalma': 3,
        'codigo': 'PAL-A1-003',
        'variedad': 'Dura',
        'fechasiembra': '2020-11-02',
        'estadosanitario': 'Tratamiento',
        'idlote': {'idlote': 1, 'nombre': 'Lote 1 - Palma Africana (Tenera)'},
        'observaciones': 'En tratamiento fitosanitario.',
      },
    ];

List<Map<String, dynamic>> _produccionPalma() => [
      {
        'idproduccionpalma': 1,
        'fecharegistro': '2026-10-12',
        'cantidadracimos': 420,
        'pesokg': 8600,
        'calidad': 'Excelente',
        'idlote': {'idlote': 1},
        'idpalma': {'idpalma': 1},
        'observaciones': 'Racimos con excelente índice de madurez.',
      },
      {
        'idproduccionpalma': 2,
        'fecharegistro': '2026-10-05',
        'cantidadracimos': 380,
        'pesokg': 7450,
        'calidad': 'Buena',
        'idlote': {'idlote': 1},
        'idpalma': {'idpalma': 2},
        'observaciones': '',
      },
    ];

List<Map<String, dynamic>> _cosechas() => [
      {
        'idcosecha': 1,
        'idcultivo': 1,
        'fechacosecha': '2026-09-12',
        'cantidad': 18.5,
        'unidad': 'Tn',
        'calidad': 'Excelente',
        'observaciones': 'Racimos de fruta fresca con excelente índice de madurez.',
      },
      {
        'idcosecha': 2,
        'idcultivo': 3,
        'fechacosecha': '2026-09-08',
        'cantidad': 850,
        'unidad': 'Kg',
        'calidad': 'Fino de aroma',
        'observaciones': 'Grano fermentado 85%, secado al sol en paseras.',
      },
      {
        'idcosecha': 3,
        'idcultivo': 2,
        'fechacosecha': '2026-08-28',
        'cantidad': 12,
        'unidad': 'Tn',
        'calidad': 'Grado 1',
        'observaciones': 'Grano entero, humedad 13.5%. Almacenado en silo.',
      },
    ];

// ── Operación: insumos y tareas ─────────────────────────────────────────────
List<Map<String, dynamic>> _insumos() => [
      {
        'idinsumo': 1,
        'nombre': 'Urea Agrícola 46% N',
        'tipo': 'Fertilizante',
        'unidadmedida': 'bultos',
        'stockactual': 12,
        'stockminimo': 25,
        'costounitario': 98000,
      },
      {
        'idinsumo': 2,
        'nombre': 'Cloruro de Potasio (KCl)',
        'tipo': 'Fertilizante',
        'unidadmedida': 'bultos',
        'stockactual': 48,
        'stockminimo': 15,
        'costounitario': 112000,
      },
      {
        'idinsumo': 3,
        'nombre': 'Fungicida Cobre Orgánico',
        'tipo': 'Fitosanitario',
        'unidadmedida': 'L',
        'stockactual': 5,
        'stockminimo': 10,
        'costounitario': 45000,
      },
      {
        'idinsumo': 4,
        'nombre': 'Semilla Certificada Arroz F68',
        'tipo': 'Semilla',
        'unidadmedida': 'kg',
        'stockactual': 60,
        'stockminimo': 20,
        'costounitario': 9500,
      },
    ];

List<Map<String, dynamic>> _tareas() => [
      {
        'idtarea': 1,
        'tipoactividad': 'Corte y plateo de racimos maduros (RFB)',
        'fechaprogramada': '2026-10-15',
        'estado': 'En progreso',
        'idcultivo': 1,
        'costototal': 350000,
      },
      {
        'idtarea': 2,
        'tipoactividad': 'Supervisión y volteo de cajones de fermentación',
        'fechaprogramada': '2026-10-15',
        'estado': 'Completada',
        'idcultivo': 3,
        'costototal': 120000,
      },
      {
        'idtarea': 3,
        'tipoactividad': 'Aplicación de fertilizante foliar Nitrogenado',
        'fechaprogramada': '2026-10-16',
        'estado': 'Pendiente',
        'idcultivo': 2,
        'costototal': 180000,
      },
      {
        'idtarea': 4,
        'tipoactividad': 'Control de niveles de lámina de agua en piscina B',
        'fechaprogramada': '2026-10-15',
        'estado': 'En progreso',
        'idcultivo': 4,
        'costototal': 90000,
      },
      {
        'idtarea': 5,
        'tipoactividad': 'Poda de chupones basales y ramas improductivas',
        'fechaprogramada': '2026-10-17',
        'estado': 'Pendiente',
        'idcultivo': 3,
        'costototal': 150000,
      },
      {
        'idtarea': 6,
        'tipoactividad': 'Fumigación preventiva fitosanitaria contra Opsiphanes',
        'fechaprogramada': '2026-10-18',
        'estado': 'Pendiente',
        'idcultivo': 1,
        'costototal': 210000,
      },
    ];

// ── Nómina / plan / avisos / reportes ───────────────────────────────────────
List<Map<String, dynamic>> _nomina() => [
      {
        'idnomina': 1,
        'fechainicio': '2026-09-01',
        'fechafin': '2026-09-15',
        'estado': 'PAGADA',
        'empleados': 2,
        'total': 1850000,
      },
    ];

List<Map<String, dynamic>> _planes() => [
      {
        'idplan': 1,
        'codigo': 'FREEMIUM',
        'nombre': 'Freemium',
        'descripcion':
            'Soporte esencial, crop management básico, registro de cultivos y gastos básicos.',
        'preciomensual': 0,
        'maxcultivos': 3,
        'maxempleados': 3,
        'maxfincas': 1,
        'comisionmarketplace': 5,
      },
      {
        'idplan': 2,
        'codigo': 'PREMIUM',
        'nombre': 'Premium (Plan Pro)',
        'descripcion':
            'Gestión avanzada ilimitada: nómina, Excel, Talent Center, Chat IA, offline completo y soporte 24/7.',
        'preciomensual': 49900,
        'maxcultivos': null,
        'maxempleados': null,
        'maxfincas': null,
        'comisionmarketplace': 3,
      },
    ];

Map<String, dynamic> _suscripcion() => {
      'suscripcion': {
        'plan': 'PREMIUM',
        'estado': 'ACTIVA',
        'fechainicio': '2026-10-01',
        'fechafin': '2026-11-01',
        'renovacionautomatica': true,
      },
      'planEfectivo': {'codigo': 'PREMIUM', 'maxcultivos': null, 'maxempleados': null, 'maxfincas': null, 'comisionmarketplace': 3},
    };

List<Map<String, dynamic>> _auditoria() => [
      {
        'operacion': 'CREAR',
        'tablaNombre': 'cultivo',
        'descripcion': 'Carlos Mendoza registró el cultivo "Palma" en Lote 1.',
      },
      {
        'operacion': 'ACTUALIZAR',
        'tablaNombre': 'tarea',
        'descripcion': 'Mateo Ortiz completó "Supervisión y volteo de cajones".',
      },
      {
        'operacion': 'DENEGADO',
        'tablaNombre': 'nomina',
        'descripcion': 'Intento de acceso sin permisos a la nómina de la finca.',
      },
    ];

List<Map<String, dynamic>> _notificaciones() => [
      {
        'idnotificacion': 1,
        'titulo': 'Stock bajo: Urea Agrícola 46% N',
        'mensaje': 'Quedan 12 bultos (mínimo 25). Programa una compra.',
        'leida': false,
      },
      {
        'idnotificacion': 2,
        'titulo': 'Tarea completada',
        'mensaje': 'Supervisión y volteo de cajones de fermentación.',
        'leida': false,
      },
      {
        'idnotificacion': 3,
        'titulo': 'Nueva orden de compra',
        'mensaje': 'Extractora del Caribe ordenó 18.5 Tn de palma.',
        'leida': true,
      },
    ];

List<Map<String, dynamic>> _reportes() => [
      {
        'idcultivo': 1,
        'cultivo': 'Palma Africana',
        'total': 14500000,
        'costo_insumos': 6200000,
        'costo_mano_obra': 8300000,
      },
      {
        'idcultivo': 2,
        'cultivo': 'Maíz Blanco',
        'total': 8200000,
        'costo_insumos': 3900000,
        'costo_mano_obra': 4300000,
      },
      {
        'idcultivo': 3,
        'cultivo': 'Cacao Trinitario',
        'total': 6400000,
        'costo_insumos': 2600000,
        'costo_mano_obra': 3800000,
      },
      {
        'idcultivo': 4,
        'cultivo': 'Arroz Fedearroz 68',
        'total': 16800000,
        'costo_insumos': 9100000,
        'costo_mano_obra': 7700000,
      },
    ];

// ── Marketplace ─────────────────────────────────────────────────────────────
List<Map<String, dynamic>> _listados() => [
      {
        'idlistado': 1,
        'titulo': 'Racimos de Fruta Fresca de Palma Aceitera (RFF)',
        'finca': 'Finca San José Del Magdalena',
        'ubicacion': 'Ciénaga, Magdalena',
        'categoria': 'palma',
        'preciounitario': 480000,
        'unidad': 'Tn',
        'volumendisponible': 18.5,
        'destacado': true,
        'estado': 'PUBLICADO',
        'descripcion':
            'Palma africana de excelente calidad, recién cosechada. Tasa de extracción estimada de aceite >23.5%. Disponible para recojo en finca o flete acordado.',
        'vendedor': 'Carlos Mendoza',
        'telefono': '+57 312 884 9201',
        'fotos': [
          'https://images.unsplash.com/photo-1595123550441-d377e017de6a?w=600&h=400&fit=crop&auto=format'
        ],
      },
      {
        'idlistado': 2,
        'titulo': 'Grano de Cacao Trinitario Fermentado y Seco',
        'finca': 'Hacienda La Esperanza',
        'ubicacion': 'Palmira, Valle del Cauca',
        'categoria': 'cacao',
        'preciounitario': 22500,
        'unidad': 'Kg',
        'volumendisponible': 850,
        'destacado': false,
        'estado': 'PUBLICADO',
        'descripcion':
            'Cacao fino de aroma, 85% grado de fermentación, humedad 7%, sin moho ni olores extraños. Ideal para chocolatería fina de exportación.',
        'vendedor': 'Elena Gómez',
        'telefono': '+57 300 451 2299',
        'fotos': [
          'https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?w=600&h=400&fit=crop&auto=format'
        ],
      },
      {
        'idlistado': 3,
        'titulo': 'Maíz Blanco Híbrido Grano Seco y Limpio',
        'finca': 'Agropecuaria El Litoral',
        'ubicacion': 'Montería, Córdoba',
        'categoria': 'maiz',
        'preciounitario': 1350000,
        'unidad': 'Tn',
        'volumendisponible': 25,
        'destacado': false,
        'estado': 'PUBLICADO',
        'descripcion':
            'Maíz limpio empacado en bultos de 50kg o a granel. Humedad controlada 13%. Apto para industria de harinas o alimento concentrado.',
        'vendedor': 'Jorge Barreto',
        'telefono': '+57 315 992 0182',
        'fotos': [
          'https://images.unsplash.com/photo-1551754655-cd27e38d2076?w=600&h=400&fit=crop&auto=format'
        ],
      },
      {
        'idlistado': 4,
        'titulo': 'Arroz Padí Verde en Cosecha Fedearroz 68',
        'finca': 'Arroceros del Tolima',
        'ubicacion': 'Espinal, Tolima',
        'categoria': 'arroz',
        'preciounitario': 0,
        'unidad': 'Tn',
        'volumendisponible': 40,
        'destacado': false,
        'estado': 'PUBLICADO',
        'descripcion':
            'Cosecha lista para recojo directo de tolva en lote. Excelente rendimiento de molinería y porcentaje de grano entero.',
        'vendedor': 'Luz Marina Ríos',
        'telefono': '+57 318 204 1120',
        'fotos': [
          'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=600&h=400&fit=crop&auto=format'
        ],
      },
    ];

List<Map<String, dynamic>> _listadosDeFinca(int idfinca) =>
    _listados().where((l) => l['idlistado'] == 1 || l['idlistado'] == 2).toList();

List<Map<String, dynamic>> _misCompras() => [
      {
        'idorden': 1,
        'titulo': 'Grano de Cacao Trinitario Fermentado y Seco',
        'finca': 'Hacienda La Esperanza',
        'cantidad': 100,
        'unidad': 'Kg',
        'subtotal': 2250000,
        'estado': 'PENDIENTE',
      },
      {
        'idorden': 2,
        'titulo': 'Maíz Blanco Híbrido Grano Seco y Limpio',
        'finca': 'Agropecuaria El Litoral',
        'cantidad': 5,
        'unidad': 'Tn',
        'subtotal': 6750000,
        'estado': 'ACEPTADA',
      },
    ];

List<Map<String, dynamic>> _ventas() => [
      {
        'idorden': 10,
        'titulo': 'Racimos de Fruta Fresca de Palma Aceitera (RFF)',
        'compradorNombre': 'Extractora del Caribe S.A.',
        'compradorTelefono': '+57 300 451 2299',
        'cantidad': 18.5,
        'unidad': 'Tn',
        'subtotal': 8880000,
        'netovendedor': 8524800,
        'puntoentrega': 'Planta extractora · Ciénaga',
        'estado': 'PENDIENTE',
      },
      {
        'idorden': 11,
        'titulo': 'Grano de Cacao Trinitario Fermentado y Seco',
        'compradorNombre': 'Chocolates Artesanales S.A.S.',
        'compradorTelefono': '+57 318 204 1120',
        'cantidad': 850,
        'unidad': 'Kg',
        'subtotal': 19125000,
        'netovendedor': 18360000,
        'puntoentrega': 'Recojo en finca',
        'estado': 'ACEPTADA',
      },
    ];

List<Map<String, dynamic>> _carrito() => [
      {
        'idlistado': 2,
        'titulo': 'Grano de Cacao Trinitario Fermentado y Seco',
        'cantidad': 50,
        'unidad': 'Kg',
        'subtotal': 1125000,
        'disponible': true,
      },
    ];

List<Map<String, dynamic>> _wishlist() => [
      {
        'idlistado': 1,
        'titulo': 'Racimos de Fruta Fresca de Palma Aceitera (RFF)',
        'preciounitario': 480000,
        'unidad': 'Tn',
        'disponible': true,
      },
      {
        'idlistado': 4,
        'titulo': 'Arroz Padí Verde en Cosecha Fedearroz 68',
        'preciounitario': 0,
        'unidad': 'Tn',
        'disponible': false,
      },
    ];

List<Map<String, dynamic>> _filtrar(List<Map<String, dynamic>> items, dynamic q) {
  final s = (q ?? '').toString().trim().toLowerCase();
  if (s.isEmpty) return items;
  return items
      .where((l) =>
          (l['titulo'] ?? '').toString().toLowerCase().contains(s) ||
          (l['categoria'] ?? '').toString().toLowerCase().contains(s))
      .toList();
}

// ── Resolución de GET por ruta ──────────────────────────────────────────────
Object? demoGet(String path, Map<String, dynamic> query) {
  switch (path) {
    case '/api/v1/fincas/activa':
      return _fincaActiva();
    case '/api/v1/fincas/dashboard':
      return _dashboard();
    case '/api/v1/fincas/activa/miembros':
      return _miembros();
    case '/lotes':
      return _lotes();
    case '/cultivos':
      return _cultivos();
    case '/palmas':
      return _palmas();
    case '/produccion-palma':
      return _produccionPalma();
    case '/api/v1/cosechas':
      return _cosechas();
    case '/api/v1/insumos':
      return _insumos();
    case '/api/v1/insumos/stock-bajo':
      return _insumos()
          .where((i) => (i['stockactual'] as num) <= (i['stockminimo'] as num))
          .toList();
    case '/api/v1/tareas':
      return _tareas();
    case '/api/v1/nomina':
      return _nomina();
    case '/api/v1/planes':
      return _planes();
    case '/api/v1/suscripcion':
      return _suscripcion();
    case '/auditoria':
      return _auditoria();
    case '/notificaciones':
      return _notificaciones();
    case '/api/v1/reportes/costos':
      return _reportes();
    case '/usuarios/me':
      return {'usuario': demoUsuario()};
    case '/api/v1/marketplace/listados':
      return _filtrar(_listados(), query['q']);
    case '/api/v1/marketplace/listados/mios':
      return _listadosDeFinca(1);
    case '/api/v1/marketplace/ordenes/mis-compras':
      return _misCompras();
    case '/api/v1/marketplace/ordenes/ventas':
      return _ventas();
    case '/api/v1/marketplace/carrito':
      return _carrito();
    case '/api/v1/marketplace/wishlist':
      return _wishlist();
    case '/notificaciones/no-leidas':
      return _notificaciones().where((n) => n['leida'] != true).toList();
    case '/api/v1/mensajeria/no-leidos':
      return {'total': 0};
    case '/api/v1/mensajeria/hilos':
    case '/api/v1/insumos/compras':
    case '/api/v1/suscripcion/pagos':
      return <Map<String, dynamic>>[];
    case '/usuarios/comprador/perfil':
      return {'ubicacion': 'Santa Marta, Magdalena', 'radioalertaskm': 50, 'notificaciones': true};
  }
  if (path.startsWith('/detalle-tarea/tarea/')) return <Map<String, dynamic>>[];
  if (RegExp(r'^/usuarios/\d+$').hasMatch(path)) {
    final u = demoUsuario();
    return {...u, 'primernombre': u['nombre'], 'primerapellido': u['apellido'], 'telefono': '300 123 4567', 'cedula': '1065000000'};
  }
  final nomina = RegExp(r'^/api/v1/nomina/(\d+)$').firstMatch(path);
  if (nomina != null) {
    final id = int.parse(nomina.group(1)!);
    final n = _nomina().firstWhere((x) => x['idnomina'] == id, orElse: () => _nomina().first);
    return {...n, 'detalles': <Map<String, dynamic>>[]};
  }
  // Detalle genérico: /recurso/{id} se resuelve buscando en la lista /recurso.
  final m = RegExp(r'^(.+)/(\d+)$').firstMatch(path);
  if (m != null) {
    final lista = demoGet(m.group(1)!, const {});
    final id = int.parse(m.group(2)!);
    if (lista is List && lista.isNotEmpty) {
      for (final it in lista.cast<Map<String, dynamic>>()) {
        final idKey = it.keys.firstWhere((k) => k.startsWith('id'), orElse: () => 'id');
        if (it[idKey] == id) return it;
      }
      return lista.first;
    }
  }
  return null;
}

/// ¿La ruta es un recurso que el modo demo debe responder (escrituras)?
bool demoHandlesWrite(String path) {
  const prefijos = [
    '/api/v1/',
    '/lotes',
    '/cultivos',
    '/palmas',
    '/produccion-palma',
    '/auditoria',
    '/notificaciones',
    '/usuarios/',
  ];
  return prefijos.any(path.startsWith);
}

// ── Interceptor de Dio: responde todo desde el mock ─────────────────────────
class DemoInterceptor extends Interceptor {
  Response _ok(RequestOptions o, Object? data) =>
      Response(requestOptions: o, statusCode: 200, data: data);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.path;
    final method = options.method.toUpperCase();

    if (path == '/usuarios/login' || path == '/usuarios/login-google') {
      handler.resolve(_ok(options, demoLoginResponse()));
      return;
    }

    final sel = RegExp(r'/fincas/(\d+)/seleccionar').firstMatch(path);
    if (sel != null) {
      handler.resolve(_ok(options, {'token': 'demo-token', 'idfinca': int.parse(sel.group(1)!)}));
      return;
    }

    if (method == 'GET') {
      final data = demoGet(path, options.queryParameters);
      if (data != null) {
        handler.resolve(_ok(options, data));
        return;
      }
    } else if (demoHandlesWrite(path)) {
      handler.resolve(_ok(options, {'message': 'Operación simulada (demo)'}));
      return;
    }

    handler.next(options);
  }
}

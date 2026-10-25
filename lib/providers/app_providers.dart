import '../services/auth_service.dart';
import '../services/aviso_service.dart';
import '../services/chat_service.dart';
import '../services/finca_service.dart';
import '../services/marketplace_service.dart';
import '../services/mensajeria_service.dart';
import '../services/nomina_service.dart';
import '../services/operacion_service.dart';
import '../services/plan_service.dart';
import '../services/produccion_service.dart';
import '../services/reporte_service.dart';
import '../services/sms_service.dart';

/// Instancias únicas de los servicios de dominio (capa de acceso a datos).
/// Las vistas importan estas instancias en vez de hablar con `Api.i` directo.
final authService = AuthService();
final fincaService = FincaService();
final produccionService = ProduccionService();
final operacionService = OperacionService();
final nominaService = NominaService();
final planService = PlanService();
final marketplaceService = MarketplaceService();
final avisoService = AvisoService();
final reporteService = ReporteService();
final chatService = ChatService();
final mensajeriaService = MensajeriaService();
final smsService = SmsService();

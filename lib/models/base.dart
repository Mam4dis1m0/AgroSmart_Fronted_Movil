/// Base para los modelos de dominio: envuelven el mapa crudo de la API y
/// exponen getters tipados, conservando todos los campos para la UI.
abstract class AgroModel {
  final Map<String, dynamic> raw;
  const AgroModel(this.raw);

  Map<String, dynamic> toMap() => raw;

  int get id => (raw['id'] as num?)?.toInt() ?? 0;
  String get nombre => (raw['nombre'] ?? '').toString();
}

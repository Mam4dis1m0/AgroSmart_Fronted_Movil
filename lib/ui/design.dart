import 'package:flutter/material.dart';
import 'package:agrosmart_proto/theme.dart';

/// Badge de tipo de cultivo con color e icono del design system.
class CropBadge extends StatelessWidget {
  final String type;
  final bool showIcon;
  final bool large;

  const CropBadge(this.type, {super.key, this.showIcon = true, this.large = false});

  static const _configs = <String, _BadgeStyle>{
    'palma': _BadgeStyle('Palma', Color(0xFFDDEAE0), Color(0xFF0A2216), Color(0xFFB8D3C0), Icons.grass),
    'maiz': _BadgeStyle('Maíz', Color(0xFFFEF3C7), Color(0xFF78350F), Color(0xFFFDE68A), Icons.agriculture),
    'cacao': _BadgeStyle('Cacao', Color(0xFFFFEDD5), Color(0xFF7C2D12), Color(0xFFFED7AA), Icons.eco),
    'arroz': _BadgeStyle('Arroz', Color(0xFFECFCCB), Color(0xFF365314), Color(0xFFD9F99D), Icons.wb_sunny),
    'cafe': _BadgeStyle('Café', Color(0xFFEDE9FE), Color(0xFF4C1D95), Color(0xFFDDD6FE), Icons.coffee),
    'cana': _BadgeStyle('Caña', Color(0xFFE0F2FE), Color(0xFF075985), Color(0xFFBAE6FD), Icons.grass),
  };

  @override
  Widget build(BuildContext context) {
    final key = type.toLowerCase().trim();
    final c = _configs[key] ?? _BadgeStyle(_title(type), AgroColors.surfaceGreen, AgroColors.forest, const Color(0xFFB8D3C0), Icons.spa);
    return _pill(
      c,
      showIcon: showIcon,
      large: large,
    );
  }

  static String _title(String v) => v.isEmpty ? 'Cultivo' : v[0].toUpperCase() + v.substring(1);
}

/// Badge de estado (publicación, sincronización, calidad).
class StatusBadge extends StatelessWidget {
  final String status;
  final bool large;

  const StatusBadge(this.status, {super.key, this.large = false});

  static const _styles = <String, _BadgeStyle>{
    'activa': _BadgeStyle('Activa', Color(0xFFDDEAE0), Color(0xFF0A2216), null, Icons.check_circle),
    'activo': _BadgeStyle('Activo', Color(0xFFDDEAE0), Color(0xFF0A2216), null, Icons.check_circle),
    'sincronizado': _BadgeStyle('Sincronizado', Color(0xFFDDEAE0), Color(0xFF0A2216), null, Icons.check_circle),
    'completada': _BadgeStyle('Completada', Color(0xFFDDEAE0), Color(0xFF0A2216), null, Icons.check_circle),
    'excelente': _BadgeStyle('Excelente', Color(0xFFDDEAE0), Color(0xFF0A2216), null, null),
    'optimo': _BadgeStyle('Óptimo', Color(0xFFE0F2FE), Color(0xFF0369A1), null, null),
    'pausada': _BadgeStyle('Pausada', Color(0xFFF1F5F9), Color(0xFF334155), null, Icons.schedule),
    'pendiente': _BadgeStyle('Pendiente', Color(0xFFFEF3C7), Color(0xFF78350F), null, Icons.schedule),
    'en progreso': _BadgeStyle('En progreso', Color(0xFFFFEDD5), Color(0xFF9A3412), null, Icons.autorenew),
    'atencion': _BadgeStyle('Atención', Color(0xFFFEF3C7), Color(0xFF78350F), null, Icons.warning_amber),
    'vendida': _BadgeStyle('Vendida', Color(0xFFDBEAFE), Color(0xFF1E3A8A), null, Icons.check_circle),
    'confirmada': _BadgeStyle('Confirmada', Color(0xFFE0F2FE), Color(0xFF0369A1), null, Icons.verified),
    'pagada': _BadgeStyle('Pagada', Color(0xFFDDEAE0), Color(0xFF0A2216), null, Icons.payments),
    'anulada': _BadgeStyle('Anulada', Color(0xFFFEE2E2), Color(0xFF991B1B), null, Icons.cancel),
    'borrador': _BadgeStyle('Borrador', Color(0xFFF1F5F9), Color(0xFF334155), null, Icons.edit_note),
    'sano': _BadgeStyle('Sano', Color(0xFFDDEAE0), Color(0xFF0A2216), null, Icons.check_circle),
    'en observacion': _BadgeStyle('En observación', Color(0xFFFEF3C7), Color(0xFF78350F), null, Icons.visibility),
    'en observación': _BadgeStyle('En observación', Color(0xFFFEF3C7), Color(0xFF78350F), null, Icons.visibility),
    'enfermo': _BadgeStyle('Enfermo', Color(0xFFFEE2E2), Color(0xFF991B1B), null, Icons.coronavirus),
    'tratamiento': _BadgeStyle('Tratamiento', Color(0xFFE0F2FE), Color(0xFF0369A1), null, Icons.medical_services),
    'aceptada': _BadgeStyle('Aceptada', Color(0xFFE0F2FE), Color(0xFF0369A1), null, Icons.verified),
    'rechazada': _BadgeStyle('Rechazada', Color(0xFFFEE2E2), Color(0xFF991B1B), null, Icons.cancel),
    'cancelada': _BadgeStyle('Cancelada', Color(0xFFF1F5F9), Color(0xFF334155), null, Icons.block),
    'cerrada': _BadgeStyle('Cerrada', Color(0xFFDDEAE0), Color(0xFF0A2216), null, Icons.check_circle),
    'publicado': _BadgeStyle('Publicado', Color(0xFFDDEAE0), Color(0xFF0A2216), null, Icons.check_circle),
    'pausado': _BadgeStyle('Pausado', Color(0xFFF1F5F9), Color(0xFF334155), null, Icons.pause),
    'agotado': _BadgeStyle('Agotado', Color(0xFFFEE2E2), Color(0xFF991B1B), null, Icons.remove_shopping_cart),
  };

  @override
  Widget build(BuildContext context) {
    final c = _styles[status.toLowerCase().trim()] ??
        _BadgeStyle(status, const Color(0xFFF1F5F9), AgroColors.textDark, null, null);
    return _pill(c, showIcon: c.icon != null, large: large);
  }
}

class _BadgeStyle {
  final String label;
  final Color bg;
  final Color fg;
  final Color? border;
  final IconData? icon;
  const _BadgeStyle(this.label, this.bg, this.fg, this.border, this.icon);
}

Widget _pill(_BadgeStyle c, {bool showIcon = true, bool large = false}) {
  final iconSize = large ? 15.0 : 13.0;
  return Container(
    padding: EdgeInsets.symmetric(horizontal: large ? 12 : 10, vertical: large ? 6 : 4),
    decoration: BoxDecoration(
      color: c.bg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: c.border ?? Colors.black.withValues(alpha: 0.06)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showIcon && c.icon != null) ...[
          Icon(c.icon, size: iconSize, color: c.fg),
          const SizedBox(width: 4),
        ],
        Text(
          c.label,
          style: TextStyle(
            color: c.fg,
            fontSize: large ? 14 : 12,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ],
    ),
  );
}

/// Barra de aviso de modo sin conexión / sincronización (estilo prototipo).
class OfflineBanner extends StatelessWidget {
  final bool offline;
  final bool syncing;
  final int pending;
  final VoidCallback? onSync;

  const OfflineBanner({
    super.key,
    required this.offline,
    this.syncing = false,
    this.pending = 0,
    this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    if (!offline && !syncing) return const SizedBox.shrink();
    final bg = syncing ? AgroColors.primaryLight : AgroColors.amber;
    final fg = syncing ? Colors.white : AgroColors.forestDeep;
    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(syncing ? Icons.sync : Icons.wifi_off, size: 15, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              syncing
                  ? 'Sincronizando datos guardados localmente…'
                  : 'Modo sin conexión — datos guardados en el dispositivo',
              style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          if (!syncing && onSync != null)
            TextButton(
              onPressed: onSync,
              style: TextButton.styleFrom(
                foregroundColor: fg,
                minimumSize: const Size(0, 0),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Probar sinc.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, decoration: TextDecoration.underline)),
            ),
          if (syncing)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
        ],
      ),
    );
  }
}

/// Header superior oscuro con nombre de finca y píldora Online/Offline.
class AgroHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool offline;
  final VoidCallback? onMenu;
  final VoidCallback? onToggleStatus;

  const AgroHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.offline = false,
    this.onMenu,
    this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AgroColors.forest,
        border: Border(bottom: BorderSide(color: Color(0xFF163D27))),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 14,
        right: 14,
        bottom: 10,
      ),
      child: Row(
        children: [
          if (onMenu != null)
            _MenuButton(onTap: onMenu!),
          if (onMenu != null) const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, height: 1.2),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF88D4A6), fontSize: 10, fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),
          if (onToggleStatus != null) ...[
            const SizedBox(width: 10),
            _StatusPill(offline: offline, onTap: onToggleStatus!),
          ],
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MenuButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: const Icon(Icons.menu, size: 18, color: Colors.white),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool offline;
  final VoidCallback onTap;
  const _StatusPill({required this.offline, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: offline ? AgroColors.amber : const Color(0xFF143B26),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: offline ? Colors.transparent : const Color(0xFF23583C)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              offline ? Icons.wifi_off : Icons.wifi,
              size: 12,
              color: offline ? AgroColors.forestDeep : AgroColors.mint,
            ),
            const SizedBox(width: 4),
            Text(
              offline ? 'Offline' : 'Online',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: offline ? AgroColors.forestDeep : const Color(0xFFA3E5BC),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AgroNavItem {
  final String label;
  final IconData icon;
  final int? badge;
  const AgroNavItem(this.label, this.icon, {this.badge});
}

/// Barra de navegación inferior oscura (estilo prototipo).
class AgroBottomNav extends StatelessWidget {
  final int index;
  final List<AgroNavItem> items;
  final ValueChanged<int> onTap;
  final VoidCallback? onMenu;

  const AgroBottomNav({
    super.key,
    required this.index,
    required this.items,
    required this.onTap,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AgroColors.navBg,
        border: Border(top: BorderSide(color: AgroColors.navBorder)),
      ),
      padding: EdgeInsets.only(top: 6, bottom: MediaQuery.of(context).padding.bottom + 4, left: 4, right: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < items.length; i++) _tab(i),
        ],
      ),
    );
  }

  Widget _tab(int i) {
    final item = items[i];
    final active = i == index;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(i),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: active
                    ? BoxDecoration(
                        color: AgroColors.surfaceGreen,
                        borderRadius: BorderRadius.circular(14),
                      )
                    : null,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      item.icon,
                      size: 20,
                      color: active ? const Color(0xFF0A2216) : AgroColors.navInactive,
                    ),
                    if (item.badge != null && item.badge! > 0)
                      Positioned(
                        top: -5,
                        right: -8,
                        child: Container(
                          width: 15,
                          height: 15,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AgroColors.amber,
                            shape: BoxShape.circle,
                            border: Border.all(color: AgroColors.navBg, width: 2),
                          ),
                          child: Text(
                            '${item.badge}',
                            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AgroColors.forestDeep),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 10,
                  height: 1,
                  letterSpacing: -0.2,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                  color: active ? const Color(0xFFDDEAE0) : AgroColors.navInactive,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta blanca base del design system (borde suave, esquinas redondeadas).
class AgroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  const AgroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AgroColors.slateBorder),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: content,
    );
  }
}

/// Tarjeta destacada verde bosque (hero del dashboard).
class AgroHeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AgroHeroCard({super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A2216), Color(0xFF103221), Color(0xFF15432B)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF214D36)),
      ),
      child: child,
    );
  }
}

/// Encabezado de sección con acción opcional ("Ver todo").
class AgroSectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const AgroSectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AgroColors.textDark)),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AgroColors.primary)),
          ),
      ],
    );
  }
}

/// Tarjeta-fila reutilizable para listas (CRUD, tareas, ofertas, miembros…).
class AgroListCard extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final Widget? badges;
  final VoidCallback? onTap;
  final Color? tint;

  const AgroListCard({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.badges,
    this.onTap,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return AgroCard(
      onTap: onTap,
      color: tint,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                if (subtitle != null) ...[const SizedBox(height: 3), subtitle!],
                if (badges != null) ...[const SizedBox(height: 8), badges!],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// Cuadrado redondeado con icono (leading de las tarjetas del design system).
class AgroIconTile extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final Color? bg;
  final double size;

  const AgroIconTile({
    super.key,
    required this.icon,
    this.color = AgroColors.primary,
    this.bg = AgroColors.surfaceGreen,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// Estado vacío con icono y acción opcional.
class AgroEmpty extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const AgroEmpty({super.key, this.icon = Icons.inbox_outlined, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 46, color: AgroColors.navInactive),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AgroColors.textMuted, fontWeight: FontWeight.w600)),
        if (action != null) ...[const SizedBox(height: 14), action!],
      ]),
    );
  }
}

/// Estado de error de carga con botón de reintento.
class AgroError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AgroError({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const AgroIconTile(icon: Icons.cloud_off, color: AgroColors.amber, bg: Color(0xFFFEF3C7), size: 56),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AgroColors.textMuted)),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
          ],
        ]),
      ),
    );
  }
}

/// Métrica sobre fondo oscuro (hero del dashboard).
class AgroHeroStat extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const AgroHeroStat({super.key, required this.label, required this.value, this.valueColor = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(color: valueColor, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFA3E5BC), fontSize: 9, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

/// Tarjeta de KPI (fondo claro) para grillas del dashboard.
class AgroStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const AgroStatCard({super.key, required this.label, required this.value, required this.icon, this.color = AgroColors.primary});

  @override
  Widget build(BuildContext context) {
    return AgroCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AgroIconTile(icon: icon, color: color, bg: color.withValues(alpha: 0.12), size: 38),
        const SizedBox(height: 10),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AgroColors.textDark, height: 1)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AgroColors.textMuted, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Chip de acción rápida (fila del dashboard).
class AgroActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  const AgroActionChip({super.key, required this.icon, required this.label, this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) {
    final bg = primary ? AgroColors.forest : AgroColors.surfaceGreen;
    final fg = primary ? Colors.white : AgroColors.forest;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: primary ? null : Border.all(color: const Color(0xFFA1C5AB)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: primary ? AgroColors.mint : AgroColors.forest),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

/// Tarjeta de alerta (ámbar) para stock bajo / avisos.
class AgroAlert extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? action;
  final VoidCallback? onAction;

  const AgroAlert({super.key, this.icon = Icons.warning_amber, required this.message, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: const Color(0xFFB45309)),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF78350F)))),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AgroColors.amber, borderRadius: BorderRadius.circular(8)),
              child: Text(action!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AgroColors.forestDeep)),
            ),
          ),
      ]),
    );
  }
}

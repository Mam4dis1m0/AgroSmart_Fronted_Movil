import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:agrosmart_proto/theme.dart';

/// Badge de tipo de cultivo con color e icono del design system.
class CropBadge extends StatelessWidget {
  final String type;
  final bool showIcon;
  final bool large;

  const CropBadge(this.type, {super.key, this.showIcon = true, this.large = false});

  static const _configs = <String, _BadgeStyle>{
    'palma': _BadgeStyle('Palma', AgroColors.surfaceGreen, AgroColors.forest, Color(0xFFB8D3C0), Icons.grass),
    'maiz': _BadgeStyle('Maíz', AgroColors.warningBg, AgroColors.warningText, AgroColors.warningBorder, Icons.agriculture),
    'maíz': _BadgeStyle('Maíz', AgroColors.warningBg, AgroColors.warningText, AgroColors.warningBorder, Icons.agriculture),
    'cacao': _BadgeStyle('Cacao', Color(0xFFFFEDD5), Color(0xFF7C2D12), Color(0xFFFED7AA), Icons.eco),
    'arroz': _BadgeStyle('Arroz', Color(0xFFECFCCB), Color(0xFF365314), Color(0xFFD9F99D), Icons.wb_sunny),
    'cafe': _BadgeStyle('Café', Color(0xFFEDE9FE), Color(0xFF4C1D95), Color(0xFFDDD6FE), Icons.coffee),
    'café': _BadgeStyle('Café', Color(0xFFEDE9FE), Color(0xFF4C1D95), Color(0xFFDDD6FE), Icons.coffee),
    'cana': _BadgeStyle('Caña', AgroColors.infoBg, Color(0xFF075985), Color(0xFFBAE6FD), Icons.grass),
    'caña': _BadgeStyle('Caña', AgroColors.infoBg, Color(0xFF075985), Color(0xFFBAE6FD), Icons.grass),
  };

  @override
  Widget build(BuildContext context) {
    final key = type.toLowerCase().trim();
    final c = _configs[key] ?? _BadgeStyle(_title(type), AgroColors.surfaceGreen, AgroColors.forest, const Color(0xFFB8D3C0), Icons.spa);
    return _pill(c, showIcon: showIcon, large: large);
  }

  static String _title(String v) => v.isEmpty ? 'Cultivo' : v[0].toUpperCase() + v.substring(1);
}

/// Badge de estado (publicación, tareas, órdenes, nómina, roles, planes…).
class StatusBadge extends StatelessWidget {
  final String status;
  final bool large;

  const StatusBadge(this.status, {super.key, this.large = false});

  static const _ok = AgroColors.surfaceGreen, _okFg = AgroColors.forest;
  static const _styles = <String, _BadgeStyle>{
    'activa': _BadgeStyle('Activa', _ok, _okFg, null, Icons.check_circle),
    'activo': _BadgeStyle('Activo', _ok, _okFg, null, Icons.check_circle),
    'inactivo': _BadgeStyle('Inactivo', AgroColors.neutralBg, Color(0xFF334155), null, Icons.block),
    'sincronizado': _BadgeStyle('Sincronizado', _ok, _okFg, null, Icons.check_circle),
    'completada': _BadgeStyle('Completada', _ok, _okFg, null, Icons.check_circle),
    'completado': _BadgeStyle('Completada', _ok, _okFg, null, Icons.check_circle),
    'asignado': _BadgeStyle('Asignada', AgroColors.infoBg, AgroColors.info, null, Icons.person_pin),
    'asignada': _BadgeStyle('Asignada', AgroColors.infoBg, AgroColors.info, null, Icons.person_pin),
    'excelente': _BadgeStyle('Excelente', _ok, _okFg, null, null),
    'optimo': _BadgeStyle('Óptimo', AgroColors.infoBg, AgroColors.info, null, null),
    'pausada': _BadgeStyle('Pausada', AgroColors.neutralBg, Color(0xFF334155), null, Icons.schedule),
    'pendiente': _BadgeStyle('Pendiente', AgroColors.warningBg, AgroColors.warningText, null, Icons.schedule),
    'en progreso': _BadgeStyle('En progreso', Color(0xFFFFEDD5), Color(0xFF9A3412), null, Icons.autorenew),
    'atencion': _BadgeStyle('Stock bajo', AgroColors.warningBg, AgroColors.warningText, null, Icons.warning_amber),
    'vendida': _BadgeStyle('Vendida', Color(0xFFDBEAFE), Color(0xFF1E3A8A), null, Icons.check_circle),
    'confirmada': _BadgeStyle('Confirmada', AgroColors.infoBg, AgroColors.info, null, Icons.verified),
    'pagada': _BadgeStyle('Pagada', _ok, _okFg, null, Icons.payments),
    'anulada': _BadgeStyle('Anulada', AgroColors.dangerBg, AgroColors.dangerText, null, Icons.cancel),
    'borrador': _BadgeStyle('Borrador', AgroColors.neutralBg, Color(0xFF334155), null, Icons.edit_note),
    'sano': _BadgeStyle('Sano', _ok, _okFg, null, Icons.check_circle),
    'en observacion': _BadgeStyle('En observación', AgroColors.warningBg, AgroColors.warningText, null, Icons.visibility),
    'en observación': _BadgeStyle('En observación', AgroColors.warningBg, AgroColors.warningText, null, Icons.visibility),
    'enfermo': _BadgeStyle('Enfermo', AgroColors.dangerBg, AgroColors.dangerText, null, Icons.coronavirus),
    'tratamiento': _BadgeStyle('Tratamiento', AgroColors.infoBg, AgroColors.info, null, Icons.medical_services),
    'aceptada': _BadgeStyle('Aceptada', AgroColors.infoBg, AgroColors.info, null, Icons.verified),
    'rechazada': _BadgeStyle('Rechazada', AgroColors.dangerBg, AgroColors.dangerText, null, Icons.cancel),
    'cancelada': _BadgeStyle('Cancelada', AgroColors.neutralBg, Color(0xFF334155), null, Icons.block),
    'cerrada': _BadgeStyle('Cerrada', _ok, _okFg, null, Icons.check_circle),
    'publicado': _BadgeStyle('Publicado', _ok, _okFg, null, Icons.check_circle),
    'pausado': _BadgeStyle('Pausado', AgroColors.neutralBg, Color(0xFF334155), null, Icons.pause),
    'agotado': _BadgeStyle('Agotado', AgroColors.dangerBg, AgroColors.dangerText, null, Icons.remove_shopping_cart),
    'vencida': _BadgeStyle('Vencida', AgroColors.dangerBg, AgroColors.dangerText, null, Icons.event_busy),
    'aprobado': _BadgeStyle('Aprobado', _ok, _okFg, null, Icons.check_circle),
    'fallido': _BadgeStyle('Fallido', AgroColors.dangerBg, AgroColors.dangerText, null, Icons.error_outline),
    'admin': _BadgeStyle('Administrador', AgroColors.surfaceGreen, AgroColors.forest, null, Icons.shield_outlined),
    'empleado': _BadgeStyle('Empleado', AgroColors.infoBg, AgroColors.info, null, Icons.badge_outlined),
    'comprador': _BadgeStyle('Comprador', AgroColors.warningBg, AgroColors.warningText, null, Icons.shopping_bag_outlined),
    'premium': _BadgeStyle('Premium', AgroColors.warningBg, AgroColors.warningText, null, Icons.workspace_premium),
    'freemium': _BadgeStyle('Freemium', AgroColors.neutralBg, Color(0xFF334155), null, null),
    'destacado': _BadgeStyle('Destacado', AgroColors.warningBg, AgroColors.warningText, null, Icons.star),
  };

  @override
  Widget build(BuildContext context) {
    final key = status.toLowerCase().trim();
    final c = _styles[key] ?? _BadgeStyle(_capitalizar(status), AgroColors.neutralBg, AgroColors.textDark, null, null);
    return _pill(c, showIcon: c.icon != null, large: large);
  }

  static String _capitalizar(String v) {
    final t = v.trim().toLowerCase();
    return t.isEmpty ? '—' : t[0].toUpperCase() + t.substring(1);
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
        Flexible(
          child: Text(
            c.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.fg, fontSize: large ? 14 : 12, fontWeight: FontWeight.w800, height: 1),
          ),
        ),
      ],
    ),
  );
}

/// Barra de aviso de modo sin conexión.
class OfflineBanner extends StatelessWidget {
  final bool offline;
  final VoidCallback? onRetry;

  const OfflineBanner({super.key, required this.offline, this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (!offline) return const SizedBox.shrink();
    return Material(
      color: AgroColors.amber,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Row(
          children: [
            const Icon(Icons.wifi_off, size: 16, color: AgroColors.forestDeep),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Sin conexión: estás viendo los últimos datos guardados',
                style: TextStyle(color: AgroColors.forestDeep, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(foregroundColor: AgroColors.forestDeep),
                child: const Text('Reintentar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Header superior oscuro con nombre de finca y píldora de conexión.
class AgroHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool offline;
  final VoidCallback? onMenu;
  final VoidCallback? onStatus;
  final List<Widget> actions;

  const AgroHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.offline = false,
    this.onMenu,
    this.onStatus,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AgroColors.forest,
        border: Border(bottom: BorderSide(color: AgroColors.headerBorder)),
      ),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 4, left: 4, right: 8, bottom: 6),
      child: Row(
        children: [
          if (onMenu != null)
            IconButton(
              tooltip: 'Menú',
              onPressed: onMenu,
              icon: const Icon(Icons.menu, color: Colors.white),
            )
          else
            const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, height: 1.2),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AgroColors.mintSoft, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ),
          ...actions,
          if (onStatus != null) ...[
            const SizedBox(width: 4),
            _StatusPill(offline: offline, onTap: onStatus!),
          ],
        ],
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
    return Semantics(
      button: true,
      label: offline ? 'Sin conexión. Toca para reintentar' : 'Conectado. Toca para comprobar',
      child: Material(
        color: offline ? AgroColors.amber : AgroColors.forestTile,
        shape: StadiumBorder(side: BorderSide(color: offline ? Colors.transparent : AgroColors.forestTileBorder)),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(offline ? Icons.wifi_off : Icons.wifi, size: 14, color: offline ? AgroColors.forestDeep : AgroColors.mint),
                  const SizedBox(width: 5),
                  Text(
                    offline ? 'Sin red' : 'En línea',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: offline ? AgroColors.forestDeep : AgroColors.mintPale,
                    ),
                  ),
                ],
              ),
            ),
          ),
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

  const AgroBottomNav({super.key, required this.index, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AgroColors.navBg,
      child: Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AgroColors.navBorder))),
        padding: EdgeInsets.only(top: 6, bottom: MediaQuery.of(context).padding.bottom + 4, left: 4, right: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [for (var i = 0; i < items.length; i++) _tab(i)],
        ),
      ),
    );
  }

  Widget _tab(int i) {
    final item = items[i];
    final active = i == index;
    final badge = item.badge ?? 0;
    return Expanded(
      child: Semantics(
        selected: active,
        button: true,
        label: badge > 0 ? '${item.label}, $badge sin leer' : item.label,
        excludeSemantics: true,
        child: InkWell(
          onTap: () => onTap(i),
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: active ? AgroColors.surfaceGreen : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Badge(
                    isLabelVisible: badge > 0,
                    backgroundColor: AgroColors.amber,
                    textColor: AgroColors.forestDeep,
                    label: Text(badge > 99 ? '99+' : '$badge', style: const TextStyle(fontWeight: FontWeight.w800)),
                    child: Icon(item.icon, size: 22, color: active ? AgroColors.forest : AgroColors.navInactive),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: active ? AgroColors.surfaceGreen : AgroColors.navInactive,
                  ),
                ),
              ],
            ),
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
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AgroColors.slateBorder),
    );
    // Material + InkWell dentro: el ripple se pinta encima del fondo y se ve al tocar.
    return Material(
      color: color ?? Colors.white,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(width: double.infinity, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// Tarjeta destacada verde bosque (hero del dashboard y del perfil).
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
          colors: [AgroColors.forest, AgroColors.heroMid, AgroColors.heroEnd],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AgroColors.heroBorder),
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
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AgroColors.textDark)),
          ),
        ),
        if (action != null) TextButton(onPressed: onAction, child: Text(action!, style: const TextStyle(fontSize: 13))),
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
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
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
          if (trailing != null) ...[const SizedBox(width: 4), trailing!] else const SizedBox(width: 8),
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

/// Avatar circular con foto o iniciales.
class AgroAvatar extends StatelessWidget {
  final String? url;
  final String nombre;
  final double radius;
  final Color bg;
  final Color fg;
  const AgroAvatar({
    super.key,
    this.url,
    required this.nombre,
    this.radius = 22,
    this.bg = AgroColors.surfaceGreen,
    this.fg = AgroColors.forest,
  });

  String get _iniciales {
    final p = nombre.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2);
    return p.isEmpty ? '?' : p.map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final hasFoto = url != null && url!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      foregroundImage: hasFoto ? CachedNetworkImageProvider(url!) : null,
      onForegroundImageError: hasFoto ? (_, __) {} : null,
      child: Text(_iniciales, style: TextStyle(fontSize: radius * 0.7, fontWeight: FontWeight.w800, color: fg)),
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
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AgroIconTile(icon: icon, color: AgroColors.navInactive, bg: Colors.white, size: 64),
        const SizedBox(height: 14),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AgroColors.textMuted, fontWeight: FontWeight.w600, height: 1.4)),
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const AgroIconTile(icon: Icons.cloud_off, color: AgroColors.warning, bg: AgroColors.warningBg, size: 56),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AgroColors.textMuted, fontWeight: FontWeight.w600)),
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
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(children: [
          FittedBox(child: Text(value, style: TextStyle(color: valueColor, fontSize: 20, fontWeight: FontWeight.w800))),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(color: AgroColors.mintPale, fontSize: 11, fontWeight: FontWeight.w700)),
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
  final VoidCallback? onTap;

  const AgroStatCard({super.key, required this.label, required this.value, required this.icon, this.color = AgroColors.primary, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AgroCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(children: [
        AgroIconTile(icon: icon, color: color, bg: color.withValues(alpha: 0.12), size: 40),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AgroColors.textDark, height: 1.1)),
            ),
            const SizedBox(height: 2),
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AgroColors.textMuted, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
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
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: AgroColors.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AgroColors.warningBorder),
      ),
      child: Row(children: [
        Icon(icon, size: 20, color: AgroColors.warning),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AgroColors.warningText))),
        if (action != null)
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: AgroColors.amber,
              foregroundColor: AgroColors.forestDeep,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(0, 36),
              textStyle: const TextStyle(fontFamily: kAgroFont, fontSize: 12, fontWeight: FontWeight.w800),
            ),
            child: Text(action!),
          ),
      ]),
    );
  }
}

/// Aviso de función Premium con acceso directo al plan.
class PremiumNotice extends StatelessWidget {
  final String message;
  final VoidCallback? onVerPlanes;
  const PremiumNotice({super.key, required this.message, this.onVerPlanes});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const AgroIconTile(icon: Icons.workspace_premium, color: AgroColors.warning, bg: AgroColors.warningBg, size: 64),
          const SizedBox(height: 14),
          const Text('Función Premium', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AgroColors.textDark)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AgroColors.textMuted, fontWeight: FontWeight.w600, height: 1.4)),
          if (onVerPlanes != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onVerPlanes, icon: const Icon(Icons.workspace_premium), label: const Text('Ver planes')),
          ],
        ]),
      ),
    );
  }
}

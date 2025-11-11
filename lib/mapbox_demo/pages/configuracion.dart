// file: lib/configuracion.dart
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ConfiguracionPage extends StatefulWidget {
  const ConfiguracionPage({super.key});

  @override
  State<ConfiguracionPage> createState() => _ConfiguracionPageState();
}

class _ConfiguracionPageState extends State<ConfiguracionPage> {
  // Preferencias
  bool _modoOscuro = false;
  bool _rutasAccesibles = true;
  bool _sonidoIndicaciones = true;
  bool _arExperimental = false;
  bool _mostrarTodosPines = true;
  bool _vibracionAR = true;

  String _version = '';
  bool _checkingPerms = false;
  Map<String, String> _perms = {
    'Cámara': '—',
    'Ubicación': '—',
    'Micrófono': '—',
    'Bluetooth': '—',
  };

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadVersion();
    _checkPerms();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = '${info.version} (${info.buildNumber})';
    });
  }

  Future<void> _loadPrefs() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _modoOscuro = sp.getBool('cfg_modo_oscuro') ?? false;
      _rutasAccesibles = sp.getBool('cfg_rutas_accesibles') ?? true;
      _sonidoIndicaciones = sp.getBool('cfg_sonido_indicaciones') ?? true;
      _arExperimental = sp.getBool('cfg_ar_experimental') ?? false;
      _mostrarTodosPines = sp.getBool('cfg_mostrar_todos_pines') ?? true;
      _vibracionAR = sp.getBool('cfg_vibracion_ar') ?? true;
    });
  }

  Future<void> _savePref(String key, bool value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(key, value);
  }

  Future<void> _checkPerms() async {
    setState(() => _checkingPerms = true);
    final cam = await Permission.camera.status;
    final loc = await Permission.locationWhenInUse.status;
    final mic = await Permission.microphone.status;
    final bt = await Permission.bluetooth.status;

    String _fmt(PermissionStatus s) {
      if (s.isGranted) return 'Concedido';
      if (s.isDenied) return 'Denegado';
      if (s.isPermanentlyDenied) return 'Denegado (permanente)';
      if (s.isRestricted) return 'Restringido';
      if (s.isLimited) return 'Limitado';
      return s.toString();
    }

    setState(() {
      _perms = {
        'Cámara': _fmt(cam),
        'Ubicación': _fmt(loc),
        'Micrófono': _fmt(mic),
        'Bluetooth': _fmt(bt),
      };
      _checkingPerms = false;
    });
  }

  Future<void> _requestMissing() async {
    await Permission.camera.request();
    await Permission.locationWhenInUse.request();
    await Permission.microphone.request();
    await Permission.bluetooth.request();
    await _checkPerms();
  }

  Future<void> _openSettings() async {
    await openAppSettings();
  }

  Future<void> _borrarCacheMapas() async {
    // No hay API pública de Mapbox para cache en Flutter. Simulamos limpieza lógica si la añades luego.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cache de mapas limpiada (lógico).')),
    );
  }

  Future<void> _soporteEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'soporte@ubicatec.app',
      query: 'subject=Soporte%20UBICATEC&body=Hola,%20necesito%20ayuda%20con...',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final headerColor = Colors.redAccent;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: headerColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // === PERFIL/HEADER (estilo Yango) ===
          Card(
            elevation: 3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: headerColor.withOpacity(.15),
                    child: const Icon(Icons.person, size: 34, color: Colors.black87),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Moisex',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            )),
                        SizedBox(height: 4),
                        Text('+59170876013',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _soporteEmail,
                    icon: const Icon(Icons.support_agent),
                    tooltip: 'Soporte',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          _sectionTitle('Mapa y navegación'),
          _switchTile(
            title: 'Modo oscuro del mapa',
            subtitle: 'Cambia el estilo del mapa a oscuro',
            value: _modoOscuro,
            onChanged: (v) {
              setState(() => _modoOscuro = v);
              _savePref('cfg_modo_oscuro', v);
            },
            icon: Icons.dark_mode,
          ),
          _switchTile(
            title: 'Rutas accesibles',
            subtitle: 'Prioriza rampas y recorridos sin escaleras',
            value: _rutasAccesibles,
            onChanged: (v) {
              setState(() => _rutasAccesibles = v);
              _savePref('cfg_rutas_accesibles', v);
            },
            icon: Icons.accessible,
          ),
          _switchTile(
            title: 'Mostrar todos los pines',
            subtitle: 'No ocultar puntos al buscar un destino',
            value: _mostrarTodosPines,
            onChanged: (v) {
              setState(() => _mostrarTodosPines = v);
              _savePref('cfg_mostrar_todos_pines', v);
            },
            icon: Icons.location_on,
          ),

          const SizedBox(height: 8),

          _sectionTitle('Realidad aumentada'),
          _switchTile(
            title: 'Vibración en guías AR',
            subtitle: 'Vibra en giros y puntos críticos',
            value: _vibracionAR,
            onChanged: (v) {
              setState(() => _vibracionAR = v);
              _savePref('cfg_vibracion_ar', v);
            },
            icon: Icons.vibration,
          ),
          _switchTile(
            title: 'Sonido de indicaciones',
            subtitle: 'Reproduce indicaciones de voz al navegar',
            value: _sonidoIndicaciones,
            onChanged: (v) {
              setState(() => _sonidoIndicaciones = v);
              _savePref('cfg_sonido_indicaciones', v);
            },
            icon: Icons.volume_up,
          ),
          _switchTile(
            title: 'AR experimental',
            subtitle: 'Activa funciones AR en prueba (puede ser inestable)',
            value: _arExperimental,
            onChanged: (v) {
              setState(() => _arExperimental = v);
              _savePref('cfg_ar_experimental', v);
            },
            icon: Icons.science,
          ),

          const SizedBox(height: 8),

          _sectionTitle('Permisos y datos'),
          _permTile(
            title: 'Comprobar permisos',
            subtitle: _checkingPerms
                ? 'Comprobando...'
                : 'Cámara: ${_perms['Cámara']} • Ubicación: ${_perms['Ubicación']}',
            icon: Icons.verified_user,
            onTap: _checkPerms,
          ),
          _listTile(
            title: 'Solicitar permisos faltantes',
            subtitle: 'Pide al sistema los permisos denegados',
            icon: Icons.app_registration,
            onTap: _requestMissing,
          ),
          _listTile(
            title: 'Abrir ajustes del sistema',
            subtitle: 'Gestiona permisos manualmente',
            icon: Icons.settings_applications,
            onTap: _openSettings,
          ),
          _listTile(
            title: 'Borrar caché de mapas',
            subtitle: 'Libera espacio si el mapa va lento',
            icon: Icons.cleaning_services,
            onTap: _borrarCacheMapas,
          ),

          const SizedBox(height: 8),

          _sectionTitle('Acerca de'),
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.indigo),
              title: const Text('UBICATEC Unificado'),
              subtitle: Text('Versión: $_version'),
              trailing: TextButton(
                onPressed: _soporteEmail,
                child: const Text('Contacto'),
              ),
            ),
          ),

          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, {
              // Si necesitas leer cambios desde quien abrió esta pantalla
              'modoOscuro': _modoOscuro,
              'rutasAccesibles': _rutasAccesibles,
              'mostrarTodosPines': _mostrarTodosPines,
            }),
            icon: const Icon(Icons.check),
            label: const Text('Guardar y volver'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ===== Helpers UI =====
  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Colors.grey,
            letterSpacing: .2,
          ),
        ),
      );

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        secondary: Icon(icon, color: Colors.indigo),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _listTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: onTap,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        leading: Icon(icon, color: Colors.indigo),
        trailing: const Icon(Icons.chevron_right),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _permTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) =>
      _listTile(title: title, subtitle: subtitle, icon: icon, onTap: onTap);
}
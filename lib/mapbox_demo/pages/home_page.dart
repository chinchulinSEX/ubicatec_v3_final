// file: lib/mapbox_demo/pages/home_page.dart
import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:permission_handler/permission_handler.dart';

import 'filtracion.dart';
import 'lugares_ueb.dart';
import 'MapNavigationPage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  mp.MapboxMap? mapboxMapController;
  mp.PointAnnotationManager? _pinManager;
  final List<mp.PointAnnotation> _pinesCreados = [];

  gl.Position? currentPosition;
  StreamSubscription<gl.Position>? userPositionStream;

  bool showCamera = false;
  CameraController? _controller;
  bool _cameraReady = false;
  double _panelSize = 0.4;

  int _selectedIndex = 0;
  bool _modoOscuro = false;

  @override
  void initState() {
    super.initState();
    _setupPositionTracking();
    _initCamera();
  }

  @override
  void dispose() {
    userPositionStream?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ FIX: Calcular la altura total del BottomNavigationBar + padding del dispositivo
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final bottomNavHeight = kBottomNavigationBarHeight + bottomPadding;

    return Scaffold(
      body: Stack(
        children: [
          // 🗺️ MAPA BASE
          mp.MapWidget(
            onMapCreated: _onMapCreated,
            styleUri: _modoOscuro
                ? mp.MapboxStyles.DARK
                : mp.MapboxStyles.MAPBOX_STREETS,
          ),

          // 🎥 PANEL DE CÁMARA
          if (_cameraReady && showCamera)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * _panelSize,
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  setState(() {
                    _panelSize -= details.primaryDelta! /
                        MediaQuery.of(context).size.height;
                    _panelSize = _panelSize.clamp(0.3, 1.0);
                  });
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                      child: CameraPreview(_controller!),
                    ),

                    // 📏 Indicador de arrastre
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 70,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),

                    // ❌ Botón cerrar cámara
                    Positioned(
                      top: 40,
                      right: 20,
                      child: FloatingActionButton.small(
                        heroTag: "close_cam",
                        backgroundColor: Colors.redAccent,
                        onPressed: () => _toggleCamera(false),
                        child: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ✅ BOTONES FLOTANTES (POSICIONADOS ARRIBA DEL BOTTOMNAVIGATIONBAR)

          // 📸 BOTÓN ABRIR CÁMARA
          if (!showCamera)
            Positioned(
              bottom: bottomNavHeight + 10, // ✅ 10px arriba de la barra
              right: 20,
              child: FloatingActionButton(
                heroTag: "open_cam",
                backgroundColor: Colors.indigo,
                onPressed: () => _toggleCamera(true),
                tooltip: 'Abrir cámara',
                child:
                    const Icon(Icons.camera_alt, color: Colors.white, size: 28),
              ),
            ),

          // 📍 BOTÓN MI UBICACIÓN
          Positioned(
            bottom: bottomNavHeight + 80, // ✅ 80px arriba de la barra
            right: 20,
            child: FloatingActionButton(
              heroTag: "my_loc",
              backgroundColor: Colors.redAccent,
              onPressed: _goToMyLocation,
              tooltip: 'Mi ubicación',
              child:
                  const Icon(Icons.my_location, color: Colors.white, size: 28),
            ),
          ),

          // 🌗 BOTÓN MODO DÍA/NOCHE
          Positioned(
            bottom: bottomNavHeight + 150, // ✅ 150px arriba de la barra
            right: 20,
            child: FloatingActionButton(
              heroTag: "toggle_mode",
              backgroundColor: _modoOscuro ? Colors.black87 : Colors.blueAccent,
              tooltip: _modoOscuro ? 'Modo día' : 'Modo noche',
              onPressed: () async {
                setState(() => _modoOscuro = !_modoOscuro);
                await mapboxMapController?.loadStyleURI(
                  _modoOscuro
                      ? mp.MapboxStyles.DARK
                      : mp.MapboxStyles.MAPBOX_STREETS,
                );
              },
              child: Icon(
                _modoOscuro ? Icons.nightlight_round : Icons.wb_sunny,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ],
      ),

      // 🔻 BARRA DE NAVEGACIÓN INFERIOR
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.redAccent,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        onTap: (index) async {
          setState(() => _selectedIndex = index);

          if (index == 1) {
            final lugar = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FiltracionPage()),
            );

            if (lugar != null && lugar is Map) {
              if (lugar["mostrarTodos"] == true) {
                // Mostrar todos los pines
                for (final p in _pinesCreados) {
                  p.iconOpacity = 1.0;
                  await _pinManager!.update(p);
                }

                await mapboxMapController?.flyTo(
                  mp.CameraOptions(
                    center: mp.Point(
                      coordinates: mp.Position(-63.2043, -17.8345),
                    ),
                    zoom: 14.3,
                    pitch: 0,
                  ),
                  mp.MapAnimationOptions(duration: 1500),
                );
              } else if (lugar["modo"] == "mapa") {
                // Mostrar solo un lugar
                await _mostrarSoloLugar({
                  "nombre": lugar["nombre"],
                  "lat": lugar["lat"],
                  "lon": lugar["lon"],
                });
              } else if (lugar["modo"] == "navegacion") {
                // Iniciar navegación
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MapNavigationPage(
                        destLat: (lugar["lat"] as num).toDouble(),
                        destLon: (lugar["lon"] as num).toDouble(),
                        destName: lugar["nombre"].toString(),
                      ),
                    ),
                  );
                }
              }
            }
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: "Mapa",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: "Buscar",
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // 🗺️ MOSTRAR SOLO UN LUGAR EN EL MAPA
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _mostrarSoloLugar(Map<String, dynamic> lugar) async {
    if (_pinManager == null) return;

    // Ocultar todos los pines
    for (final p in _pinesCreados) {
      p.iconOpacity = 0.0;
      await _pinManager!.update(p);
    }

    // Buscar o crear el pin del lugar seleccionado
    mp.PointAnnotation? existente;
    for (final p in _pinesCreados) {
      if (p.textField == lugar['nombre']) {
        existente = p;
        break;
      }
    }

    if (existente == null) {
      final bytes = await rootBundle.load('assets/icons/punto_mapa_rojo_f.png');
      final imageData = bytes.buffer.asUint8List();
      existente = await _pinManager!.create(
        mp.PointAnnotationOptions(
          geometry: mp.Point(
            coordinates: mp.Position(
              lugar['lon'] as double,
              lugar['lat'] as double,
            ),
          ),
          image: imageData,
          iconSize: 0.45,
          textField: "",
        ),
      );
      _pinesCreados.add(existente);
    } else {
      existente.iconOpacity = 1.0;
      await _pinManager!.update(existente);
    }

    // Volar hacia el lugar
    await mapboxMapController?.flyTo(
      mp.CameraOptions(
        center: mp.Point(
          coordinates: mp.Position(
            lugar['lon'] as double,
            lugar['lat'] as double,
          ),
        ),
        zoom: 18.0,
        pitch: 45.0,
      ),
      mp.MapAnimationOptions(duration: 2000),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // 📸 INICIALIZAR CÁMARA
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _initCamera() async {
    try {
      await Permission.camera.request();
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('⚠️ No hay cámaras disponibles');
        return;
      }
      _controller = CameraController(cameras.first, ResolutionPreset.high);
      await _controller!.initialize();
      if (mounted) {
        setState(() => _cameraReady = true);
      }
    } catch (e) {
      debugPrint('❌ Error inicializando cámara: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 🔄 ALTERNAR PANEL DE CÁMARA
  // ════════════════════════════════════════════════════════════════════════
  void _toggleCamera(bool value) {
    setState(() {
      showCamera = value;
      if (!value) _panelSize = 0.4;
    });
  }

  // ════════════════════════════════════════════════════════════════════════
  // 🗺️ CONFIGURAR MAPA AL CREARSE
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _onMapCreated(mp.MapboxMap controller) async {
    mapboxMapController = controller;
    await _checkAndRequestLocationPermission();

    // Habilitar punto de ubicación del usuario
    await mapboxMapController?.location.updateSettings(
      mp.LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        showAccuracyRing: true,
      ),
    );

    // Crear manager de pines
    _pinManager ??=
        await mapboxMapController!.annotations.createPointAnnotationManager();

    // Cargar imagen de los pines
    final bytes = await rootBundle.load('assets/icons/punto_mapa_rojo_f.png');
    final imageData = bytes.buffer.asUint8List();
    final lugares = lugaresUeb;
    final puntos = <mp.Point>[];

    // Crear pines para todos los lugares
    for (final l in lugares) {
      final pin = await _pinManager!.create(
        mp.PointAnnotationOptions(
          geometry: mp.Point(
            coordinates: mp.Position(l['lon'] as double, l['lat'] as double),
          ),
          image: imageData,
          iconSize: 0.35,
          textField: "",
        ),
      );
      _pinesCreados.add(pin);
      puntos.add(mp.Point(
        coordinates: mp.Position(l['lon'] as double, l['lat'] as double),
      ));
    }

    // Evento tap en pines
    _pinManager?.tapEvents(
      onTap: (mp.PointAnnotation annotation) async {
        final lugar = lugares.firstWhere(
          (l) =>
              (l['lat'] as double) ==
                  annotation.geometry.coordinates.lat.toDouble() &&
              (l['lon'] as double) ==
                  annotation.geometry.coordinates.lng.toDouble(),
          orElse: () => {'nombre': 'Lugar sin nombre'},
        );

        if (context.mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Row(
                children: [
                  const Text("📍 ", style: TextStyle(fontSize: 22)),
                  Expanded(
                    child: Text(
                      lugar['nombre'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ],
              ),
              content: const Text(
                "¿Deseas iniciar la navegación hacia este lugar?",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MapNavigationPage(
                          destLat:
                              annotation.geometry.coordinates.lat.toDouble(),
                          destLon:
                              annotation.geometry.coordinates.lng.toDouble(),
                          destName: lugar['nombre'].toString(),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.navigation, color: Colors.white),
                  label: const Text("Ir"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );

    // Calcular bounds de todos los puntos y volar hacia ellos
    if (puntos.isNotEmpty) {
      double minLat = puntos.first.coordinates.lat.toDouble();
      double maxLat = puntos.first.coordinates.lat.toDouble();
      double minLon = puntos.first.coordinates.lng.toDouble();
      double maxLon = puntos.first.coordinates.lng.toDouble();

      for (var p in puntos) {
        final lat = p.coordinates.lat.toDouble();
        final lon = p.coordinates.lng.toDouble();
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lon < minLon) minLon = lon;
        if (lon > maxLon) maxLon = lon;
      }

      final centerLat = (minLat + maxLat) / 2;
      final centerLon = (minLon + maxLon) / 2;

      await mapboxMapController?.flyTo(
        mp.CameraOptions(
          center: mp.Point(coordinates: mp.Position(centerLon, centerLat)),
          zoom: 14.3,
          pitch: 0,
        ),
        mp.MapAnimationOptions(duration: 1500),
      );
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 📍 CONFIGURAR SEGUIMIENTO DE UBICACIÓN
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _setupPositionTracking() async {
    await _checkAndRequestLocationPermission();
    userPositionStream?.cancel();
    userPositionStream = gl.Geolocator.getPositionStream(
      locationSettings: const gl.LocationSettings(
        accuracy: gl.LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen((gl.Position? pos) {
      if (pos != null) currentPosition = pos;
    });
  }

  // ════════════════════════════════════════════════════════════════════════
  // 🎯 IR A MI UBICACIÓN ACTUAL
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _goToMyLocation() async {
    if (currentPosition == null || mapboxMapController == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Esperando ubicación GPS...'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    await mapboxMapController!.flyTo(
      mp.CameraOptions(
        center: mp.Point(
          coordinates: mp.Position(
            currentPosition!.longitude,
            currentPosition!.latitude,
          ),
        ),
        zoom: 17.5,
        pitch: 45.0,
      ),
      mp.MapAnimationOptions(duration: 2000),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // ✅ VERIFICAR Y SOLICITAR PERMISOS DE UBICACIÓN
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _checkAndRequestLocationPermission() async {
    bool enabled = await gl.Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      debugPrint('⚠️ Servicios de ubicación desactivados');
      return;
    }

    gl.LocationPermission perm = await gl.Geolocator.checkPermission();
    if (perm == gl.LocationPermission.denied) {
      perm = await gl.Geolocator.requestPermission();
      if (perm == gl.LocationPermission.denied) {
        debugPrint('❌ Permisos de ubicación denegados');
        return;
      }
    }

    if (perm == gl.LocationPermission.deniedForever) {
      debugPrint('🚫 Permisos de ubicación denegados permanentemente');
      return;
    }
  }
}

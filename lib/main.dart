// ✅ NUEVO: lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'mapbox_demo/pages/splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Cargar .env
  await dotenv.load(fileName: ".env");
  
  // Configurar Mapbox
  MapboxOptions.setAccessToken(dotenv.env["MAPBOX_ACCESS_TOKEN"]!);
  
  // Permisos iniciales
  await Permission.camera.request();
  await Permission.locationWhenInUse.request();
  
  runApp(const UbicatecApp());
}

class UbicatecApp extends StatelessWidget {
  const UbicatecApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UBICATEC AR',
      theme: ThemeData(
        colorSchemeSeed: Colors.red,
        useMaterial3: true,
      ),
      home: const SplashPage(),
    );
  }
}
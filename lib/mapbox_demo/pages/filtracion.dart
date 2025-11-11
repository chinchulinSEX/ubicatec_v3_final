import 'package:flutter/material.dart';

// 📄 Importaciones locales
import 'configuracion.dart'; // ⚙️ Panel de configuración
import 'indoor_navigation_page.dart'; // ✅ archivo de navegación indoor
import 'lugares_ueb.dart'; // ✅ Archivo de datos (lista de lugares)

class FiltracionPage extends StatefulWidget {
  const FiltracionPage({super.key});

  @override
  State<FiltracionPage> createState() => _FiltracionPageState();
}

class _FiltracionPageState extends State<FiltracionPage> {
  final TextEditingController _searchController = TextEditingController();
  String filtroSeleccionado = "Todos";

  final List<Map<String, dynamic>> lugares = lugaresUeb;

  final List<String> categorias = [
    "Todos",
    "💻 Tecnología e Ingeniería",
    "📘 Aulas Académicas",
    "🔬 Laboratorios",
    "🧬 Medicina y Ciencias de la Salud",
    "🚻 Baños",
    "☕ Comida y Cafeterías",
    "📖 Biblioteca y Cómputo",
    "🎵 Arte y Cultura",
    "🗣 Comunicación y Humanidades",
    "🚪 Entradas y Accesos",
    "🧾 Administración y Oficinas",
  ];

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.toLowerCase();

    final lugaresFiltrados = lugares.where((l) {
      final coincideTexto = l["nombre"].toLowerCase().contains(query);
      final coincideCategoria = filtroSeleccionado == "Todos"
          ? true
          : l["categoria"] == filtroSeleccionado;
      return coincideTexto && coincideCategoria;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        title: const Text(
          "Buscar Lugares - UBICATEC",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Configuración',
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ConfiguracionPage(),
                ),
              );
            },
          ),
        ],
      ),

      // 🧭 CUERPO PRINCIPAL
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔍 Barra de búsqueda
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: "Buscar aulas, laboratorios o servicios...",
                border: InputBorder.none,
                icon: Icon(Icons.search, color: Colors.redAccent),
              ),
            ),
          ),

          // 🏷️ Selector de categorías
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: categorias.map((cat) {
                final activo = filtroSeleccionado == cat;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: activo,
                    onSelected: (_) => setState(() => filtroSeleccionado = cat),
                    selectedColor: Colors.redAccent,
                    labelStyle: TextStyle(
                      color: activo ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: Colors.grey[200],
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 10),

          // 📋 Resultados filtrados
          Expanded(
            child: ListView.builder(
              itemCount: lugaresFiltrados.length,
              itemBuilder: (context, index) {
                final l = lugaresFiltrados[index];

                return Card(
                  elevation: 3,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on,
                                color: Colors.redAccent, size: 30),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l["nombre"],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${l["ubicacion"]} • ${l["categoria"]}",
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 🧭 Botones "Mapa" y "Navegar"
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.map,
                                    size: 18, color: Colors.white),
                                label: const Text(
                                  "Mapa",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(context, {
                                    "modo": "mapa",
                                    "nombre": l["nombre"],
                                    "lat": l["lat"],
                                    "lon": l["lon"],
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.directions_walk,
                                    size: 18, color: Colors.white),
                                label: const Text(
                                  "Navegar",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(context, {
                                    "modo": "navegacion",
                                    "nombre": l["nombre"],
                                    "lat": l["lat"],
                                    "lon": l["lon"],
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ✅ Botones inferiores
          SafeArea(
            minimum: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C1C1E),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                    shadowColor: Colors.black26,
                  ),
                  onPressed: () =>
                      Navigator.pop(context, {"mostrarTodos": true}),
                  icon: const Icon(Icons.map, size: 22, color: Colors.white),
                  label: const Text(
                    "Mostrar todos los lugares",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // 🧭 Botón de navegación interna
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B30),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 5,
                    shadowColor: Colors.redAccent.withOpacity(0.4),
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const IndoorNavigationPage(), // ✅ correcto
                      ),
                    );
                  },
                  icon: const Icon(Icons.directions_walk,
                      size: 22, color: Colors.white),
                  label: const Text(
                    "Navegación interna (UEB)",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

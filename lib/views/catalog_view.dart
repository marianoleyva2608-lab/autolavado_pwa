import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CatalogView extends StatefulWidget {
  const CatalogView({super.key});

  @override
  State<CatalogView> createState() => _CatalogViewState();
}

class _CatalogViewState extends State<CatalogView> {
  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();
  bool _isLoading = true;
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _snacks = [];

  @override
  void initState() {
    super.initState();
    _fetchCatalog();
  }

  Future<void> _fetchCatalog() async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase.from('cw_services').select().order('name');
      final all = List<Map<String, dynamic>>.from(res);
      
      if (mounted) {
        setState(() {
          _services = all.where((s) => s['category'] != 'tiendita').toList();
          _snacks = all.where((s) => s['category'] == 'tiendita').toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching catalog: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editService(Map<String, dynamic>? service, {bool isSnack = false}) async {
    final nameController = TextEditingController(text: service?['name'] ?? '');
    
    // Default 0 for prices if not existing
    final priceAuto = TextEditingController(text: (service?['price_auto'] ?? service?['price'] ?? 0).toString());
    final priceSuvCh = TextEditingController(text: (service?['price_suv_ch'] ?? 0).toString());
    final priceSuvM = TextEditingController(text: (service?['price_suv_m'] ?? 0).toString());
    final priceG = TextEditingController(text: (service?['price_g'] ?? 0).toString());
    final priceXl = TextEditingController(text: (service?['price_xl'] ?? 0).toString());
    
    // Controladores para Comisiones (Lo que se le paga al lavador)
    final commAuto = TextEditingController(text: (service?['comm_auto'] ?? 0).toString());
    final commSuvCh = TextEditingController(text: (service?['comm_suv_ch'] ?? 0).toString());
    final commSuvM = TextEditingController(text: (service?['comm_suv_m'] ?? 0).toString());
    final commG = TextEditingController(text: (service?['comm_g'] ?? 0).toString());
    final commXl = TextEditingController(text: (service?['comm_xl'] ?? 0).toString());
    
    String? currentImageUrl = service?['image_url'];
    XFile? pickedFile;
    bool isUploading = false;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Scaffold(
          backgroundColor: Colors.black54,
          body: Center(
            child: Container(
              width: 500,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      service == null ? 'Agregar ${isSnack ? 'Snack' : 'Servicio'}' : 'Editar ${service['name']}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Nombre del ${isSnack ? 'Producto' : 'Servicio'}',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.blueGrey[50],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (isSnack)
                      _priceField(priceAuto, 'Precio de Venta')
                    else ...[
                      const Text('Catálogo de Precios 2026:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                      const SizedBox(height: 12),
                      _priceField(priceAuto, 'AUTO'),
                      _priceField(priceSuvCh, 'SUV CH'),
                      _priceField(priceSuvM, 'SUV M'),
                      _priceField(priceG, 'GRANDE (G)'),
                      _priceField(priceXl, 'EXTRA GRANDE (XL)'),
                      const Divider(height: 32),
                      const Text('Comisión para Lavador:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 12),
                      _priceField(commAuto, 'Com. AUTO'),
                      _priceField(commSuvCh, 'Com. SUV CH'),
                      _priceField(commSuvM, 'Com. SUV M'),
                      _priceField(commG, 'Com. G'),
                      _priceField(commXl, 'Com. XL'),
                    ],
                    const SizedBox(height: 20),
                    const Text('Fotografía del Producto:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    const SizedBox(height: 8),
                    StatefulBuilder(
                      builder: (context, setDialogState) {
                        return Column(
                          children: [
                            Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Center(
                                child: pickedFile != null 
                                  ? (kIsWeb ? Image.network(pickedFile!.path) : const Icon(Icons.image, size: 50))
                                  : (currentImageUrl != null 
                                      ? Image.network(currentImageUrl) 
                                      : const Icon(Icons.add_a_photo, size: 50, color: Colors.grey)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: isUploading ? null : () async {
                                final file = await _picker.pickImage(source: ImageSource.gallery);
                                if (file != null) {
                                  setDialogState(() => pickedFile = file);
                                }
                              },
                              icon: const Icon(Icons.photo_library),
                              label: Text(pickedFile == null ? 'ELEGIR FOTO' : 'CAMBIAR FOTO'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], foregroundColor: Colors.black87),
                            ),
                          ],
                        );
                      }
                    ),
                    const SizedBox(height: 32),
                    StatefulBuilder(
                      builder: (context, setDialogState) {
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: isUploading ? null : () async {
                            setDialogState(() => isUploading = true);
                            
                            try {
                              String? imageUrl = currentImageUrl;
                              
                              if (pickedFile != null) {
                                final bytes = await pickedFile!.readAsBytes();
                                final fileExt = pickedFile!.name.split('.').last;
                                final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
                                final path = fileName;
                                
                                await _supabase.storage.from('service_images').uploadBinary(
                                  path,
                                  bytes,
                                  fileOptions: FileOptions(contentType: 'image/$fileExt'),
                                );
                                
                                imageUrl = _supabase.storage.from('service_images').getPublicUrl(path);
                              }

                              final rawPrice = priceAuto.text.replaceAll(RegExp(r'[^\d.]'), '');
                              final parsedPrice = double.tryParse(rawPrice) ?? 0.0;

                              final data = {
                                'name': nameController.text,
                                'category': isSnack ? 'tiendita' : 'lavado',
                                'price': parsedPrice,
                                'price_auto': parsedPrice,
                                'price_suv_ch': isSnack ? parsedPrice : (double.tryParse(priceSuvCh.text) ?? 0.0),
                                'price_suv_m': isSnack ? parsedPrice : (double.tryParse(priceSuvM.text) ?? 0.0),
                                'price_g': isSnack ? parsedPrice : (double.tryParse(priceG.text) ?? 0.0),
                                'price_xl': isSnack ? parsedPrice : (double.tryParse(priceXl.text) ?? 0.0),
                                'comm_auto': double.tryParse(commAuto.text) ?? 0.0,
                                'comm_suv_ch': double.tryParse(commSuvCh.text) ?? 0.0,
                                'comm_suv_m': double.tryParse(commSuvM.text) ?? 0.0,
                                'comm_g': double.tryParse(commG.text) ?? 0.0,
                                'comm_xl': double.tryParse(commXl.text) ?? 0.0,
                                'image_url': imageUrl,
                                'is_active': true,
                              };

                              if (service == null) {
                                await _supabase.from('cw_services').insert(data);
                              } else {
                                await _supabase.from('cw_services').update(data).eq('id', service['id']);
                              }
                              
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Guardado correctamente'), backgroundColor: Colors.green),
                                );
                                Navigator.pop(context);
                                _fetchCatalog();
                              }
                            } catch (e) {
                              print('Error saving: $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
                                );
                              }
                            } finally {
                              if (mounted) setDialogState(() => isUploading = false);
                            }
                          },
                          child: isUploading 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('GUARDAR CAMBIOS', style: TextStyle(fontWeight: FontWeight.bold)),
                        );
                      }
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _priceField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          prefixText: '\$ ',
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          title: const Text('Catálogo y Precios', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E3A8A),
          elevation: 0,
          bottom: const TabBar(
            labelColor: Color(0xFF1E3A8A),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFFE53935),
            tabs: [
              Tab(text: 'Lavado / Estética'),
              Tab(text: 'Snacks / Tienda'),
            ],
          ),
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              children: [
                _buildList(_services, false),
                _buildList(_snacks, true),
              ],
            ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            // Need a way to tell which tab is active. 
            // Simple approach: show a snack selection if needed, or just default to service.
            _showAddOption();
          },
          label: const Text('NUEVO ITEM'),
          icon: const Icon(Icons.add),
          backgroundColor: const Color(0xFFE53935),
        ),
      ),
    );
  }

  void _showAddOption() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.local_car_wash, color: Color(0xFF1E3A8A)),
            title: const Text('Nuevo Servicio de Lavado'),
            onTap: () {
              Navigator.pop(context);
              _editService(null, isSnack: false);
            },
          ),
          ListTile(
            leading: const Icon(Icons.fastfood, color: Colors.orange),
            title: const Text('Nuevo Snack / Bebida'),
            onTap: () {
              Navigator.pop(context);
              _editService(null, isSnack: true);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, bool isSnack) {
    if (items.isEmpty) return const Center(child: Text('No hay elementos en esta categoría.'));
    
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            leading: CircleAvatar(
              backgroundColor: isSnack ? Colors.orange[50] : Colors.blue[50],
              child: Icon(isSnack ? Icons.fastfood : Icons.local_car_wash, color: isSnack ? Colors.orange : const Color(0xFF1E3A8A)),
            ),
            title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            subtitle: isSnack 
              ? Text('Precio: \$${item['price_auto'] ?? item['price']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))
              : Text('Precios Catálogo: Auto(\$${item['price_auto']}) | SUV CH(\$${item['price_suv_ch']}) | XL(\$${item['price_xl']})', style: const TextStyle(fontSize: 12)),
            trailing: IconButton(
              icon: const Icon(Icons.edit, color: Colors.blueAccent),
              onPressed: () => _editService(item, isSnack: isSnack),
            ),
          ),
        );
      },
    );
  }
}

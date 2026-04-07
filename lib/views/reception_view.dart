import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReceptionView extends StatefulWidget {
  const ReceptionView({super.key});

  @override
  State<ReceptionView> createState() => _ReceptionViewState();
}

class _ReceptionViewState extends State<ReceptionView> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  
  String _paymentOption = 'postpago'; // 'prepago' o 'postpago'
  Map<String, dynamic>? _selectedService;
  String _vehicleType = 'AUTO';
  
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _snacks = [];
  Map<String, int> _selectedSnacks = {}; // ID -> quantity
  bool _isLoading = true;
  bool _isSubmitting = false;

  final List<String> _vehicleTypes = ['AUTO', 'SUV CH', 'SUV M', 'G', 'XL'];

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _plateController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _fetchServices() async {
    print('ReceptionView: Starting _fetchServices from ${_supabase.rest.url}');
    try {
      final response = await _supabase
          .from('cw_services')
          .select()
          .eq('is_active', true)
          .order('name');
          
      print('ReceptionView: response received. Items: ${response.length}');
      if (mounted) {
        setState(() {
          final all = List<Map<String, dynamic>>.from(response);
          _services = all.where((s) => s['category'] != 'tiendita').toList();
          _snacks = all.where((s) => s['category'] == 'tiendita').toList();
          
          if (_services.isNotEmpty) {
            // Buscar Paquete 1 para que sea la opción por defecto en "Primer Plano"
            final pkg1 = _services.firstWhere(
              (s) => s['name']?.toString().toUpperCase().contains('PAQUETE 1') ?? false,
              orElse: () => _services.first,
            );
            _selectedService = pkg1;
            _updatePrice();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('ReceptionView error fetching services: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updatePrice() {
    if (_selectedService == null || _selectedService!['id'] == null) return;
    
    double price = 0;
    try {
      String key = 'price_auto';
      if (_vehicleType == 'SUV CH') {
        key = 'price_suv_ch';
      } else if (_vehicleType == 'SUV M') key = 'price_suv_m';
      else if (_vehicleType == 'G') key = 'price_g';
      else if (_vehicleType == 'XL') key = 'price_xl';
      
      final val = _selectedService![key];
      if (val != null) {
        if (val is num) {
          price = val.toDouble();
        } else {
          price = double.tryParse(val.toString()) ?? 0.0;
        }
      }
    } catch (e) {
      print('Error parsing price in _updatePrice: $e');
    }
    
    setState(() {
      _priceController.text = price.toStringAsFixed(0);
    });
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate() || _selectedService == null) return;
    _formKey.currentState!.save();
    
    setState(() => _isSubmitting = true);

    try {
      // Validar si el cliente ya tiene otra placa registrada
      final name = _customerNameController.text.trim();
      final plates = _plateController.text.trim().toUpperCase();
      
      if (name.isNotEmpty) {
        final existing = await _supabase
            .from('cw_tickets')
            .select('vehicle_plate, vehicle_model')
            .eq('customer_name', name)
            .order('created_at', ascending: false)
            .limit(1);
            
        if (existing.isNotEmpty) {
          final lastPlate = existing.first['vehicle_plate'].toString().toUpperCase();
          if (lastPlate != plates) {
             final bool? proceed = await showDialog<bool>(
               context: context,
               builder: (context) => AlertDialog(
                 title: const Text('¿Vehículo Nuevo?'),
                 content: Text('El cliente "$name" tiene registrada la placa "$lastPlate" (${existing.first['vehicle_model']}).\n\n¿Deseas registrar este como un NUEVO vehículo para este cliente?'),
                 actions: [
                   TextButton(
                     onPressed: () => Navigator.pop(context, false),
                     child: const Text('CANCELAR / CORREGIR'),
                   ),
                   ElevatedButton(
                     onPressed: () => Navigator.pop(context, true),
                     style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                     child: const Text('SÍ, ES NUEVO REGISTRO'),
                   ),
                 ],
               ),
             );
             if (proceed != true) {
               setState(() => _isSubmitting = false);
               return;
             }
          }
        }
      }

      final paymentStatus = _paymentOption == 'prepago' ? 'paid' : 'pending';
      final basePrice = double.tryParse(_priceController.text) ?? 0.0;
      
      double grandTotal = basePrice;
      _selectedSnacks.forEach((id, qty) {
        if (qty > 0) {
          final snack = _snacks.firstWhere((s) => s['id'] == id);
          final p = snack['price_auto'] ?? snack['price'] ?? 0.0;
          grandTotal += (p is num ? p.toDouble() : double.tryParse(p.toString()) ?? 0.0) * qty;
        }
      });
      
      // 1. Insert Ticket
      final ticketResponse = await _supabase.from('cw_tickets').insert({
        'customer_name': _customerNameController.text.trim(),
        'customer_phone': _customerPhoneController.text.trim(),
        'vehicle_plate': _plateController.text.trim().toUpperCase(),
        'vehicle_model': _modelController.text.trim(),
        'vehicle_color': _colorController.text.trim(),
        'vehicle_type': _vehicleType,
        'status': 'queue',
        'payment_status': paymentStatus,
        'total_amount': grandTotal,
      }).select().single();

      final ticketId = ticketResponse['id'];

      // 2. Insert Service Item
      List<Map<String, dynamic>> itemsToInsert = [];
      itemsToInsert.add({
        'ticket_id': ticketId,
        'service_id': _selectedService!['id'],
        'price_at_time': basePrice,
        'quantity': 1,
      });

      // 3. Insert Snacks
      _selectedSnacks.forEach((id, qty) {
        if (qty > 0) {
          final snack = _snacks.firstWhere((s) => s['id'] == id);
          itemsToInsert.add({
            'ticket_id': ticketId,
            'service_id': id,
            'price_at_time': snack['price_auto'] ?? snack['price'],
            'quantity': qty,
          });
        }
      });

      await _supabase.from('cw_ticket_items').insert(itemsToInsert);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🚗 Registro completado con éxito.'), backgroundColor: Colors.green),
        );
        _formKey.currentState!.reset();
        _customerNameController.clear();
        _customerPhoneController.clear();
        _plateController.clear();
        _modelController.clear();
        _colorController.clear();
        setState(() {
          _paymentOption = 'postpago';
          _selectedSnacks = {};
          _updatePrice();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Recepción - Station Car Wash', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Datos del Vehículo', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                      const Text('Datos del Cliente y Vehículo', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _buildAutocompleteField(
                              'Nombre del Cliente', 
                              Icons.person, 
                              _customerNameController,
                              'customer_name'
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField('Teléfono', Icons.phone, _customerPhoneController, isPhone: true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildAutocompleteField(
                        'Placas', 
                        Icons.pin, 
                        _plateController,
                        'vehicle_plate',
                        onSelected: (val) => _plateController.text = val.toUpperCase(),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField('Modelo / Marca', Icons.directions_car, _modelController),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField('Color', Icons.palette, _colorController),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const Text('Tipo de Auto y Servicio', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                      const SizedBox(height: 20),
                      
                      // Vehículo Type Selector (GRID)
                      const Text('Tamaño del Auto:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                      const SizedBox(height: 8),
                      // Usar un SingleChildScrollView horizontal para evitar desbordes en chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Wrap(
                          spacing: 4,
                          children: _vehicleTypes.map((type) {
                          final isSelected = _vehicleType == type;
                          return ChoiceChip(
                            label: Text(type, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
                            selected: isSelected,
                            selectedColor: const Color(0xFFE53935),
                            backgroundColor: Colors.grey[200],
                            onSelected: (val) {
                              if (val) {
                                setState(() => _vehicleType = type);
                                _updatePrice();
                              }
                            },
                          );
                        }).toList(),
                      ),),
                      
                      const SizedBox(height: 24),
                      DropdownButtonFormField<Map<String, dynamic>>(
                        isExpanded: true,
                        value: _selectedService,
                        decoration: InputDecoration(
                          labelText: 'Servicio / Paquete',
                          prefixIcon: const Icon(Icons.local_car_wash),
                          filled: true,
                          fillColor: Colors.blueGrey[50],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        items: _services.map((svc) {
                          return DropdownMenuItem(
                            value: svc,
                            child: Text(svc['name']),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedService = val);
                          _updatePrice();
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Precio Final (Ajustable)',
                          prefixText: '\$ ',
                          // El icono ya no es necesario con el prefijo de texto
                          filled: true,
                          fillColor: Colors.green[50],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      const Text('¿Desea agregar Snacks o Bebidas?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: _snacks.isEmpty 
                          ? const Center(child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text('No hay snacks registrados', style: TextStyle(color: Colors.grey)),
                            ))
                          : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _snacks.length,
                        itemBuilder: (context, index) {
                          final snack = _snacks[index];
                          final qty = _selectedSnacks[snack['id']] ?? 0;
                          final imageUrl = snack['image_url'];
                          
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: qty > 0 ? Colors.orange : Colors.grey[200]!, width: 2),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: imageUrl != null && imageUrl.toString().isNotEmpty
                                      ? Image.network(imageUrl, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.fastfood, size: 20, color: Colors.orange))
                                      : const Icon(Icons.fastfood, size: 20, color: Colors.orange),
                                  ),
                                ),
                                Text(snack['name'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text('\$${snack['price_auto'] ?? snack['price']}', style: const TextStyle(fontSize: 10, color: Colors.orange)),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle, size: 18, color: Colors.orange),
                                      onPressed: qty > 0 ? () => setState(() => _selectedSnacks[snack['id']] = qty - 1) : null,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 4),
                                    Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle, size: 18, color: Colors.orange),
                                      onPressed: () => setState(() => _selectedSnacks[snack['id']] = qty + 1),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      ),
                      
                      const SizedBox(height: 32),
                      const Text('Método de Pago', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Postpago'),
                              subtitle: const Text('Paga al salir'),
                              value: 'postpago',
                              groupValue: _paymentOption,
                              onChanged: (val) => setState(() => _paymentOption = val!),
                              activeColor: const Color(0xFF1E3A8A),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Prepago'),
                              subtitle: const Text('Pagado ya'),
                              value: 'prepago',
                              groupValue: _paymentOption,
                              onChanged: (val) => setState(() => _paymentOption = val!),
                              activeColor: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),
                      SizedBox(
                        width: double.infinity,
                        height: 70,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitTicket,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isSubmitting
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('REGISTRAR EN COLA', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
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
  Widget _buildTextField(String label, IconData icon, TextEditingController controller, {bool isPhone = false}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.grey[200],
      ),
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
    );
  }

  Widget _buildAutocompleteField(String label, IconData icon, TextEditingController controller, String fieldName, {Function(String)? onSelected}) {
    return Autocomplete<Map<String, dynamic>>(
      displayStringForOption: (option) => option[fieldName] ?? '',
      optionsBuilder: (TextEditingValue textEditingValue) async {
        if (textEditingValue.text.length < 2) return const Iterable.empty();
        
        try {
          final res = await _supabase
              .from('cw_tickets')
              .select('customer_name, customer_phone, vehicle_plate, vehicle_model, vehicle_color, vehicle_type')
              .ilike(fieldName, '%${textEditingValue.text}%')
              .limit(5);
          
          final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(res);
          // Eliminar duplicados básicos por el campo que estamos buscando
          final seen = <String>{};
          return items.where((i) => seen.add(i[fieldName].toString().toUpperCase())).toList();
        } catch (e) {
          return const Iterable.empty();
        }
      },
      onSelected: (Map<String, dynamic> selection) {
        setState(() {
          _customerNameController.text = selection['customer_name'] ?? '';
          _customerPhoneController.text = selection['customer_phone'] ?? '';
          _plateController.text = selection['vehicle_plate'] ?? '';
          _modelController.text = selection['vehicle_model'] ?? '';
          _colorController.text = selection['vehicle_color'] ?? '';
          
          if (selection['vehicle_type'] != null) {
            _vehicleType = selection['vehicle_type'];
            _updatePrice();
          }
        });
        if (onSelected != null) onSelected(selection[fieldName]);
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        // Sincronizar el controlador del Autocomplete con el de nuestra clase
        textController.text = controller.text;
        textController.addListener(() {
          controller.text = textController.text;
        });

        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            filled: true,
            fillColor: Colors.grey[200],
          ),
          onFieldSubmitted: (v) => onFieldSubmitted(),
        );
      },
    );
  }
}

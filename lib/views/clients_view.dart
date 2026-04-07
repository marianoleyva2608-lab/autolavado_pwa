import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClientsView extends StatefulWidget {
  const ClientsView({super.key});

  @override
  State<ClientsView> createState() => _ClientsViewState();
}

class _ClientsViewState extends State<ClientsView> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _clients = [];
  String _searchQuery = "";

  final _nameController = TextEditingController();
  final _rfcController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedRegimen = "612";
  String _selectedPersonType = "FÍSICA";
  String _selectedClientType = "FACTURA";
  bool _hasCredit = false;
  final _creditLimitController = TextEditingController();

  final Map<String, String> _regimenesFisica = {
    "605": "605 - Sueldos y salarios",
    "606": "606 - Arrendamiento",
    "610": "610 - Residentes en el Extranjero",
    "611": "611 - Dividendos",
    "612": "612 - P. Físicas con Actividad Empresarial",
    "614": "614 - Intereses",
    "616": "616 - Sin obligaciones fiscales",
    "621": "621 - Incorporación Fiscal",
    "625": "625 - Actividades Agrícolas/Ganaderas (P. Físicas)",
    "626": "626 - RESICO (Confianza)",
  };

  final Map<String, String> _regimenesMoral = {
    "601": "601 - General de Ley Personas Morales",
    "603": "603 - Personas Morales con Fines no Lucrativos",
    "610": "610 - Residentes en el Extranjero",
    "620": "620 - Sociedades Cooperativas",
    "622": "622 - Actividades Agrícolas/Ganaderas (P. Morales)",
    "623": "623 - Opcional para Grupos de Sociedades",
    "624": "624 - Coordinados",
    "626": "626 - RESICO (Confianza)",
  };

  Map<String, String> get _currentRegimenes =>
      _selectedPersonType == "FÍSICA" ? _regimenesFisica : _regimenesMoral;

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  Future<void> _fetchClients() async {
    try {
      final res = await _supabase.from('cw_clients').select().order('name');
      
      // Obtener todos los tickets para contar vehículos únicos por cliente
      final ticketsRes = await _supabase.from('cw_tickets').select('customer_name, vehicle_plate');
      
      // Mapa para contar vehículos únicos (placas) por nombre de cliente normalizado
      Map<String, Set<String>> clientVehicles = {};
      for (var t in ticketsRes) {
        final rawName = t['customer_name']?.toString().toUpperCase().trim() ?? '';
        final plate = t['vehicle_plate']?.toString().toUpperCase().trim() ?? '';
        if (rawName.isNotEmpty && plate.isNotEmpty) {
          clientVehicles.putIfAbsent(rawName, () => {}).add(plate);
        }
      }

      if (mounted) {
        setState(() {
          _clients = List<Map<String, dynamic>>.from(res).map((c) {
            final name = (c['name'] ?? '').toString().toUpperCase().trim();
            c['vehicle_count'] = clientVehicles[name]?.length ?? 0;
            return c;
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error en _fetchClients: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addOrEditClient({Map<String, dynamic>? client}) async {
    if (client != null) {
      _nameController.text = client['name'] ?? '';
      _rfcController.text = client['rfc'] ?? '';
      _emailController.text = client['email'] ?? '';
      _phoneController.text = client['phone'] ?? '';
      _selectedPersonType = client['person_type'] ?? 'FÍSICA';
      _selectedRegimen =
          client['regimen_code'] ??
          (_selectedPersonType == 'FÍSICA' ? '612' : '601');
      _selectedClientType = client['client_type'] ?? 'FACTURA';
      _hasCredit = client['has_credit'] ?? false;
      _creditLimitController.text = (client['credit_limit'] ?? 0.0).toString();
    } else {
      _nameController.clear();
      _rfcController.clear();
      _emailController.clear();
      _phoneController.clear();
      _selectedPersonType = "FÍSICA";
      _selectedRegimen = "612";
      _selectedClientType = "FACTURA";
      _hasCredit = false;
      _creditLimitController.text = "0.0";
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(client == null ? 'Nuevo Cliente' : 'Editar Cliente'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedClientType,
                  decoration: const InputDecoration(
                    labelText: 'TIPO DE CLIENTE',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'FACTURA', child: Text('FACTURACIÓN (Oficial)')),
                    DropdownMenuItem(value: 'NOTA', child: Text('SOLO NOTA (Interno)')),
                  ],
                  onChanged: (val) => setDialogState(() => _selectedClientType = val!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre o Razón Social',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 12),
                if (_selectedClientType == 'FACTURA') ...[
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPersonType,
                    decoration: const InputDecoration(
                      labelText: 'TIPO DE PERSONA',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'FÍSICA',
                        child: Text('Persona Física (RFC 13 carac.)'),
                      ),
                      DropdownMenuItem(
                        value: 'MORAL',
                        child: Text('Persona Moral (RFC 12 carac.)'),
                      ),
                    ],
                    onChanged: (val) {
                      setDialogState(() {
                        _selectedPersonType = val!;
                        _selectedRegimen = _selectedPersonType == "FÍSICA"
                            ? "612"
                            : "601";
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _rfcController,
                    maxLength: _selectedPersonType == "FÍSICA" ? 13 : 12,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'RFC',
                      hintText: _selectedPersonType == "FÍSICA"
                          ? 'ABCD123456XYZ'
                          : 'ABC123456XYZ',
                    ),
                    onChanged: (val) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRegimen,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Régimen Fiscal',
                    ),
                    items: _currentRegimenes.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(
                              e.value,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setDialogState(() => _selectedRegimen = val!),
                  ),
                ],
                const Divider(),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Habilitar Crédito'),
                  subtitle: const Text('Permitir compras a cuenta'),
                  value: _hasCredit,
                  onChanged: (val) => setDialogState(() => _hasCredit = val),
                  activeColor: Colors.blueAccent,
                ),
                if (_hasCredit)
                  TextField(
                    controller: _creditLimitController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Límite de Crédito',
                      prefixIcon: Icon(Icons.account_balance_wallet),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final clientData = {
                  'name': _nameController.text.trim(),
                  'phone': _phoneController.text.trim(),
                  'rfc': _selectedClientType == 'FACTURA' ? _rfcController.text.toUpperCase().trim() : null,
                  'email': _selectedClientType == 'FACTURA' ? _emailController.text.trim() : null,
                  'regimen_code': _selectedClientType == 'FACTURA' ? _selectedRegimen : null,
                  'person_type': _selectedClientType == 'FACTURA' ? _selectedPersonType : null,
                  'client_type': _selectedClientType,
                  'has_credit': _hasCredit,
                  'credit_limit': double.tryParse(_creditLimitController.text) ?? 0.0,
                };

                try {
                  if (client == null) {
                    await _supabase.from('cw_clients').insert(clientData);
                  } else {
                    await _supabase
                        .from('cw_clients')
                        .update(clientData)
                        .eq('id', client['id']);
                  }
                  Navigator.pop(context);
                  _fetchClients();
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: TextField(
            onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
            decoration: InputDecoration(
              hintText: 'Buscar cliente...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF1E3A8A)),
              border: InputBorder.none,
            ),
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E3A8A),
          elevation: 0,
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: const TabBar(
                labelColor: Color(0xFF1E3A8A),
                unselectedLabelColor: Colors.grey,
                indicatorColor: Color(0xFF1E3A8A),
                indicatorWeight: 3,
                tabs: [
                  Tab(text: 'FACTURACIÓN'),
                  Tab(text: 'SOLO NOTA'),
                ],
              ),
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildClientList('FACTURA'),
                  _buildClientList('NOTA'),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _addOrEditClient(),
          backgroundColor: const Color(0xFF1E3A8A),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'NUEVO CLIENTE',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildClientList(String type) {
    final filtered = _clients.where((c) {
      final matchesType = (c['client_type'] ?? 'FACTURA') == type;
      final matchesSearch = c['name'].toString().toLowerCase().contains(_searchQuery);
      return matchesType && matchesSearch;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No hay clientes en esta categoría',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final c = filtered[index];
        final bool isNote = type == 'NOTA';
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isNote ? Colors.orange : const Color(0xFF1E3A8A)).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isNote ? Icons.person_outline : Icons.business_outlined,
                  color: isNote ? Colors.orange : const Color(0xFF1E3A8A),
                ),
              ),
              title: Text(
                c['name'].toString().toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const SizedBox(height: 4),
                   if (!isNote) ...[
                     Text(
                       'RFC: ${c['rfc']?.toString().isNotEmpty == true ? c['rfc'] : 'SIN RFC'}',
                       style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                     ),
                     Text(
                       'Regimen: ${_currentRegimenes[c['regimen_code']] ?? c['regimen_code'] ?? 'N/A'}',
                       style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                     ),
                   ] else ...[
                     Row(
                       children: [
                         const Icon(Icons.phone_android, size: 14, color: Colors.grey),
                         const SizedBox(width: 4),
                         Text(
                           c['phone']?.toString().isNotEmpty == true ? c['phone'] : 'Sin teléfono',
                           style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                         ),
                       ],
                     ),
                   ],
                   const SizedBox(height: 8),
                   Row(
                     children: [
                       _buildBadge(isNote ? 'NOTA' : 'FACTURA', isNote ? Colors.orange : Colors.blue),
                        if (c['has_credit'] == true) ...[
                          const SizedBox(width: 8),
                          _buildBadge('CON CRÉDITO (\$${c['credit_limit']})', Colors.green),
                        ],
                        const SizedBox(width: 8),
                        _buildBadge('${c['vehicle_count'] ?? 0} VEHÍCULOS', Colors.purple),
                      ],
                    ),
                ],
              ),
              trailing: Container(
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                  onPressed: () => _addOrEditClient(client: c),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

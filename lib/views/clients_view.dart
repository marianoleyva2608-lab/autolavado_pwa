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
      setState(() {
        _clients = List<Map<String, dynamic>>.from(res);
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching clients: $e');
      setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Gestión de Clientes',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
          bottom: const TabBar(
            labelColor: Color(0xFF1E3A8A),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF1E3A8A),
            tabs: [
              Tab(icon: Icon(Icons.receipt_long), text: 'FACTURACIÓN'),
              Tab(icon: Icon(Icons.note_alt), text: 'SOLO NOTA'),
            ],
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
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildClientList(String type) {
    final filtered = _clients.where((c) => (c['client_type'] ?? 'FACTURA') == type).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No hay clientes en esta categoría',
                style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final c = filtered[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.withOpacity(0.1)),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  type == 'FACTURA' ? const Color(0xFF1E3A8A) : Colors.orange,
              child: Icon(type == 'FACTURA' ? Icons.business : Icons.person,
                  color: Colors.white),
            ),
            title: Text(
              c['name'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (type == 'FACTURA')
                  Text('RFC: ${c['rfc'] ?? 'N/A'} | Regimen: ${c['regimen_code']}')
                else
                  Text('Tel: ${c['phone'] ?? 'Sin teléfono'}'),
                if (c['has_credit'] == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'CRÉDITO: \$${c['credit_limit']}',
                      style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 11),
                    ),
                  ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _addOrEditClient(client: c),
            ),
          ),
        );
      },
    );
  }
}

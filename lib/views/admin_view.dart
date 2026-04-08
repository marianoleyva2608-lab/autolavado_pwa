import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'washers_view.dart';
import 'billing_view.dart';
import 'clients_view.dart';
import 'reports_view.dart';
import 'payroll_view.dart';
import 'catalog_view.dart';
import 'weekly_invoicing_view.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class AdminView extends StatefulWidget {
  const AdminView({super.key});

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  int _selectedIndex = 0; 

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 1000;

    return Scaffold(
      appBar: isMobile ? AppBar(
        title: const Text('STATION ADMIN'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
      ) : null,
      drawer: isMobile ? Drawer(child: _buildSidebar(isDrawer: true)) : null,
      body: Row(
        children: [
          if (!isMobile) _buildSidebar(),
          // Main Content
          Expanded(
            child: Container(
              color: const Color(0xFFF1F5F9),
              child: _buildMainContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar({bool isDrawer = false}) {
    return Container(
      width: 260,
      color: const Color(0xFF1E3A8A), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isDrawer) ...[
            const SizedBox(height: 48),
            const Icon(Icons.local_car_wash, size: 64, color: Colors.white),
            const SizedBox(height: 16),
            const Text(
              'STATION ADMIN',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
            const SizedBox(height: 48),
          ] else ...[
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1E3A8A)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_car_wash, size: 48, color: Colors.white),
                  const SizedBox(height: 12),
                  const Text('STATION ADMIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
          _SidebarItem(
            icon: Icons.point_of_sale,
            title: 'Caja / Control',
            isSelected: _selectedIndex == 0,
            onTap: () {
              setState(() => _selectedIndex = 0);
              if (isDrawer) Navigator.pop(context);
            },
          ),
          _SidebarItem(
            icon: Icons.receipt_long,
            title: 'Facturación CFDI',
            isSelected: _selectedIndex == 4,
            onTap: () {
              setState(() => _selectedIndex = 4);
              if (isDrawer) Navigator.pop(context);
            },
          ),
          _SidebarItem(
            icon: Icons.payments_outlined,
            title: 'Nómina de Lavadores',
            isSelected: _selectedIndex == 7,
            onTap: () {
              setState(() => _selectedIndex = 7);
              if (isDrawer) Navigator.pop(context);
            },
          ),
          _SidebarItem(
            icon: Icons.calendar_view_week,
            title: 'Reportes Semanales',
            isSelected: _selectedIndex == 8,
            onTap: () {
              setState(() => _selectedIndex = 8);
              if (isDrawer) Navigator.pop(context);
            },
          ),
          _SidebarItem(
            icon: Icons.history,
            title: 'Historial / Ventas',
            isSelected: _selectedIndex == 1,
            onTap: () {
              setState(() => _selectedIndex = 1);
              if (isDrawer) Navigator.pop(context);
            },
          ),
          _SidebarItem(
            icon: Icons.people_outline,
            title: 'Equipo Lavadores',
            isSelected: _selectedIndex == 2,
            onTap: () {
              setState(() => _selectedIndex = 2);
              if (isDrawer) Navigator.pop(context);
            },
          ),
          _SidebarItem(
            icon: Icons.inventory_2_outlined,
            title: 'Catálogo y Precios',
            isSelected: _selectedIndex == 5,
            onTap: () {
              setState(() => _selectedIndex = 5);
              if (isDrawer) Navigator.pop(context);
            },
          ),
          _SidebarItem(
            icon: Icons.people,
            title: 'Clientes',
            isSelected: _selectedIndex == 3,
            onTap: () {
              setState(() => _selectedIndex = 3);
              if (isDrawer) Navigator.pop(context);
            },
          ),
          const Spacer(),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.refresh, color: Colors.white70),
            title: const Text('Limpiar Cache', style: TextStyle(color: Colors.white70, fontSize: 13)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reiniciar Aplicación'),
                  content: const Text('Se recargará la página para limpiar el cache. ¿Continuar?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                    ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, Reiniciar')),
                  ],
                ),
              );
              if (confirm == true) {
                html.window.location.reload();
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white70),
            title: const Text('Salir', style: TextStyle(color: Colors.white70)),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0: return CajaView(onNavigate: (i) => setState(() => _selectedIndex = i));
      case 1: return const ReportsView();
      case 2: return const WashersView();
      case 3: return const ClientsView();
      case 4: return const BillingView();
      case 5: return const CatalogView();
      case 7: return const PayrollView(); 
      case 8: return const WeeklyInvoicingView();
      default: return CajaView(onNavigate: (i) => setState(() => _selectedIndex = i));
    }
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.white : Colors.white70),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: onTap,
      selected: isSelected,
      selectedTileColor: Colors.white.withValues(alpha: 0.1),
    );
  }
}

class CajaView extends StatefulWidget {
  final Function(int)? onNavigate;
  const CajaView({super.key, this.onNavigate});

  @override
  State<CajaView> createState() => _CajaViewState();
}

class _CajaViewState extends State<CajaView> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _snacks = [];
  List<Map<String, dynamic>> _workers = [];
  final List<Map<String, dynamic>> _cart = [];
  bool _requiresInvoice = false;
  bool _isProcessing = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final sRes = await _supabase.from('cw_services').select().eq('category', 'tiendita').eq('is_active', true);
      final wRes = await _supabase.from('cw_workers').select().eq('role', 'washer').eq('is_active', true);
      if (mounted) {
        setState(() {
          _snacks = List<Map<String, dynamic>>.from(sRes);
          _workers = List<Map<String, dynamic>>.from(wRes);
        });
      }
    } catch (e) {
      print('Error en _fetchData: $e');
    }
  }

  double _calculateTotal() {
    double total = 0;
    for (var c in _cart) {
      if (c['type'] == 'vehicle') {
        total += (c['item']['total_amount'] ?? 0.0);
      } else {
        final p = c['item']['price_auto'] ?? c['item']['price'] ?? 0.0;
        total += (p is num ? p.toDouble() : double.tryParse(p.toString()) ?? 0.0) * c['qty'];
      }
    }
    return total;
  }

  void _addToCart(String type, Map<String, dynamic> item) {
    setState(() {
      if (type == 'snack') {
        final existing = _cart.indexWhere((c) => c['type'] == 'snack' && c['item']['id'] == item['id']);
        if (existing >= 0) {
          _cart[existing]['qty']++;
        } else {
          _cart.add({'type': 'snack', 'item': item, 'qty': 1});
        }
        // Limpiar búsqueda al agregar (solicitud del usuario para que se borren)
        _searchQuery = "";
        _searchController.clear();
      } else if (type == 'vehicle') {
        final existing = _cart.indexWhere((c) => c['type'] == 'vehicle' && c['item']['id'] == item['id']);
        if (existing < 0) {
          _cart.add({'type': 'vehicle', 'item': item, 'qty': 1});
        }
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() => _cart.removeAt(index));
  }

  Widget _buildStatusBadge(String status) {
    String label = status.toUpperCase();
    Color color = Colors.grey;
    switch (status.toLowerCase()) {
      case 'queue':
        label = 'EN ESPERA';
        color = Colors.orange;
        break;
      case 'washing':
        label = 'LAVANDO';
        color = Colors.blue;
        break;
      case 'ready':
        label = 'LISTO';
        color = Colors.green;
        break;
      case 'delivered':
        label = 'ENTREGADO';
        color = Colors.grey;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildElapsedTime(String startTime) {
    final start = DateTime.parse(startTime).toLocal();
    final diff = DateTime.now().difference(start);
    final minutes = diff.inMinutes;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 14, color: Colors.blueGrey),
          const SizedBox(width: 4),
          Text(
            '$minutes min',
            style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _checkClientCredit(List<dynamic> vehiclesInCart) async {
    if (vehiclesInCart.isEmpty) return null;
    final firstVehicle = vehiclesInCart.first['item'];
    final name = firstVehicle['customer_name']?.toString() ?? '';
    if (name.isEmpty) return null;

    final res = await _supabase.from('cw_clients').select().eq('name', name).maybeSingle();
    if (res != null && res['has_credit'] == true) {
      return res;
    }
    return null;
  }

  Future<void> _processCart() async {
    if (_cart.isEmpty) return;

    // 1. Seleccionar Método de Pago
    final String? method = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar Método de Pago', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.payments, color: Colors.green),
              ),
              title: const Text('Pago en Efectivo / Tarjeta', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Venta cobrada al momento'),
              onTap: () => Navigator.pop(context, 'cash'),
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.person, color: Colors.blue),
              ),
              title: const Text('Crédito Lavador (Vale)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Deducir de nómina'),
              onTap: () => Navigator.pop(context, 'vale'),
            ),
          ],
        ),
      ),
    );

    if (method == null) return;

    setState(() => _isProcessing = true);
    try {
      final vehicles = _cart.where((c) => c['type'] == 'vehicle').toList();
      final snacks = _cart.where((c) => c['type'] == 'snack').toList();
      final totalAmount = _calculateTotal();

      String paymentStatus = 'paid';
      String? workerId;

      if (method == 'vale') {
        // Seleccionar Trabajador
        if (!context.mounted) return;
        final Map<String, dynamic>? selectedWorker = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Seleccionar Lavador'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _workers.length,
                itemBuilder: (context, i) => ListTile(
                  title: Text(_workers[i]['name']),
                  onTap: () => Navigator.pop(context, _workers[i]),
                ),
              ),
            ),
          ),
        );

        if (selectedWorker == null) {
          setState(() => _isProcessing = false);
          return;
        }
        workerId = selectedWorker['id'];
        paymentStatus = 'paid'; // Marcamos como pagado porque ya se registró la deuda en el ledger
      } else {
        // Pago normal: Verificar crédito de cliente si hay vehículo
        if (!context.mounted) return;
        final clientCredit = await _checkClientCredit(vehicles);
        if (clientCredit != null) {
          if (!context.mounted) return;
          final useCredit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Cliente con Crédito Detectado'),
              content: Text('${clientCredit['name']} tiene línea de crédito activa.\n¿Desea mandar esta venta a CRÉDITO o cobrar en EFECTIVO/TARJETA?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('COBRAR AHORA')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true), 
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('MANDAR A CRÉDITO')
                ),
              ],
            )
          );
          if (useCredit == true) {
            paymentStatus = 'credit';
          }
        }
      }

      String? billingTicketId;

      // 2. Procesar Venta
      if (vehicles.isEmpty && snacks.isNotEmpty) {
        // Venta solo de snacks
        final ticketResponse = await _supabase.from('cw_tickets').insert({
          'vehicle_plate': method == 'vale' ? 'VALE TIENDA' : 'TIENDA',
          'vehicle_model': 'Venta Directa',
          'vehicle_color': '-',
          'vehicle_type': 'AUTO',
          'status': 'delivered',
          'payment_status': paymentStatus,
          'total_amount': totalAmount,
          'requires_invoice': _requiresInvoice,
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        }).select().single();
        billingTicketId = ticketResponse['id'];

        List<Map<String, dynamic>> itemsToInsert = [];
        for (var s in snacks) {
          final snackItem = s['item'];
          itemsToInsert.add({
            'ticket_id': billingTicketId,
            'service_id': snackItem['id'],
            'price_at_time': snackItem['price_auto'] ?? snackItem['price'] ?? 0.0,
            'quantity': s['qty'],
          });
        }
        await _supabase.from('cw_ticket_items').insert(itemsToInsert);
      } else {
        // Venta con vehículos (y snacks opcionales)
        for (var i = 0; i < vehicles.length; i++) {
          final v = vehicles[i];
          final t = v['item'];
          billingTicketId ??= t['id'];
          final isReady = t['status'] == 'ready';
          await _supabase.from('cw_tickets').update({
            'payment_status': paymentStatus,
            if (isReady) 'status': 'delivered',
            if (isReady) 'completed_at': DateTime.now().toUtc().toIso8601String(),
            'requires_invoice': _requiresInvoice && i == 0,
          }).eq('id', t['id']);
        }
        
        if (snacks.isNotEmpty && billingTicketId != null) {
          List<Map<String, dynamic>> itemsToInsert = [];
          double snacksTotal = 0;
          for (var s in snacks) {
            final snackItem = s['item'];
            final p = snackItem['price_auto'] ?? snackItem['price'] ?? 0.0;
            final price = p is num ? p.toDouble() : double.tryParse(p.toString()) ?? 0.0;
            snacksTotal += price * s['qty'];
            itemsToInsert.add({
              'ticket_id': billingTicketId,
              'service_id': snackItem['id'],
              'price_at_time': price,
              'quantity': s['qty'],
            });
          }
          await _supabase.from('cw_ticket_items').insert(itemsToInsert);
          
          final firstTicket = vehicles.first['item'];
          final newTotal = (firstTicket['total_amount'] ?? 0.0) + snacksTotal;
          await _supabase.from('cw_tickets').update({'total_amount': newTotal}).eq('id', billingTicketId);
        }
      }

      // 3. Si es Vale, registrar en el Ledger
      if (method == 'vale' && workerId != null) {
        String description = "Compra Tienda: ";
        description += snacks.map((s) => "${s['qty']}x ${s['item']['name']}").join(", ");
        if (vehicles.isNotEmpty) {
          description += " + Lavado ${vehicles.first['item']['vehicle_plate']}";
        }

        await _supabase.from('cw_worker_ledger').insert({
          'worker_id': workerId,
          'amount': -totalAmount, // Monto negativo para el vale
          'type': 'purchase',
          'description': description,
          'ticket_id': billingTicketId,
        });
      }

      if (mounted) {
        setState(() {
          _cart.clear();
          _requiresInvoice = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta procesada con éxito.'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 1100;

    return Column(
      children: [
        if (!isMobile)
          AppBar(
            title: const Text('Caja - Centro de Control / POS', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1E3A8A),
            elevation: 0,
          ),
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: isMobile 
              ? Column(
                  children: [
                    const TabBar(
                      labelColor: Color(0xFF1E3A8A),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Color(0xFF1E3A8A),
                      tabs: [
                        Tab(text: 'Autos', icon: Icon(Icons.directions_car)),
                        Tab(text: 'Tienda', icon: Icon(Icons.fastfood)),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildVehiclesTab(),
                          _buildSnacksTab(),
                        ],
                      ),
                    ),
                    Container(
                      height: 200,
                      color: Colors.white,
                      child: _buildCartSection(isMobile: true),
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            const TabBar(
                              labelColor: Color(0xFF1E3A8A),
                              unselectedLabelColor: Colors.grey,
                              indicatorColor: Color(0xFF1E3A8A),
                              tabs: [
                                Tab(text: 'Autos en Curso', icon: Icon(Icons.directions_car)),
                                Tab(text: 'La Tiendita', icon: Icon(Icons.fastfood)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  _buildVehiclesTab(),
                                  _buildSnacksTab(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 380,
                      color: Colors.white,
                      child: _buildCartSection(isMobile: false),
                    ),
                  ],
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildCartSection({required bool isMobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(isMobile ? 12 : 24),
          color: const Color(0xFF1E3A8A),
          child: Text(
            'PUNTO DE VENTA', 
            style: TextStyle(
              fontSize: isMobile ? 14 : 18, 
              fontWeight: FontWeight.bold, 
              color: Colors.white, 
              letterSpacing: 1.2
            )
          ),
        ),
        Expanded(
          child: _cart.isEmpty 
            ? const Center(child: Text('Carrito vacío', style: TextStyle(color: Colors.grey)))
            : ListView.builder(
                itemCount: _cart.length,
                itemBuilder: (context, i) {
                  final c = _cart[i];
                  final isVehicle = c['type'] == 'vehicle';
                  final item = c['item'];
                  final title = isVehicle ? '${item['vehicle_plate']} (${item['vehicle_model']})' : item['name'];
                  return ListTile(
                    dense: isMobile,
                    leading: Icon(isVehicle ? Icons.directions_car : Icons.fastfood, color: Colors.indigo, size: isMobile ? 20 : 28),
                    title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 13 : 15)),
                    subtitle: Text(isVehicle ? 'Lavado de Auto' : 'Cantidad: ${c['qty']}', style: TextStyle(fontSize: isMobile ? 11 : 13)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () => _removeFromCart(i),
                    ),
                  );
                },
              ),
        ),
        const Divider(height: 1),
        Container(
          padding: EdgeInsets.all(isMobile ? 12 : 24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('SUBTOTAL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text('\$${_calculateTotal().toStringAsFixed(2)}', style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.w600)),
                ],
              ),
              if (!isMobile) const SizedBox(height: 8),
              if (!isMobile)
                SwitchListTile(
                  title: const Text('Requiere Factura', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  value: _requiresInvoice,
                  onChanged: (val) => setState(() => _requiresInvoice = val),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: Colors.indigo,
                ),
              SizedBox(height: isMobile ? 8 : 16),
              SizedBox(
                width: double.infinity,
                height: isMobile ? 45 : 60,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processCart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isProcessing 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'COBRAR AHORA', 
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.white
                        )
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVehiclesTab() {
    return StreamBuilder(
      stream: _supabase.from('cw_tickets').stream(primaryKey: ['id']).order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final all = snapshot.data as List<Map<String, dynamic>>;
        final filtered = all.where((t) => t['status'] != 'delivered' && t['payment_status'] != 'paid').toList();
        if (filtered.isEmpty) return const Center(child: Text('No hay autos pendientes de pago'));
        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final t = filtered[i];
            final isInCart = _cart.any((c) => c['type'] == 'vehicle' && c['item']['id'] == t['id']);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: isInCart ? Colors.indigo : Colors.grey.shade200, width: isInCart ? 2 : 1),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isInCart ? Colors.indigo : Colors.blue).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.drive_eta, color: isInCart ? Colors.indigo : Colors.blueAccent),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${t['vehicle_plate']} - ${t['vehicle_model']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20, color: Colors.blueGrey),
                      onPressed: () => _showEditVehicleDialog(t),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      _buildStatusBadge(t['status']),
                      const SizedBox(width: 8),
                      _buildElapsedTime(t['created_at']),
                    ],
                  ),
                ),
                trailing: Text(
                  '\$${t['total_amount']}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                onTap: isInCart ? null : () => _addToCart('vehicle', t),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSnacksTab() {
    if (_snacks.isEmpty) return const Center(child: Text('No hay productos registrados'));
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 700;

    final filteredSnacks = _snacks.where((s) => s['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar producto...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                setState(() {
                  _searchQuery = "";
                  _searchController.clear();
                });
              }) : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.all(isMobile ? 8 : 16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMobile ? 3 : 4, 
              childAspectRatio: isMobile ? 0.8 : 1.0, 
              crossAxisSpacing: isMobile ? 8 : 16, 
              mainAxisSpacing: isMobile ? 8 : 16
            ),
            itemCount: filteredSnacks.length,
            itemBuilder: (context, i) {
              final s = filteredSnacks[i];
              final p = s['price_auto'] ?? s['price'] ?? 0.0;
              final price = p is num ? p.toDouble() : double.tryParse(p.toString()) ?? 0.0;
              return InkWell(
                onTap: () => _addToCart('snack', s),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    borderRadius: BorderRadius.circular(16), 
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: Icon(Icons.fastfood, color: Colors.orange, size: isMobile ? 24 : 32),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          s['name'], 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 11 : 13), 
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('\$${price.toStringAsFixed(0)}', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: isMobile ? 12 : 14)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showEditVehicleDialog(Map<String, dynamic> ticket) {
    final plateCtrl = TextEditingController(text: ticket['vehicle_plate']);
    final modelCtrl = TextEditingController(text: ticket['vehicle_model']);
    final colorCtrl = TextEditingController(text: ticket['vehicle_color']);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Vehículo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: plateCtrl, decoration: const InputDecoration(labelText: 'Placas')),
            const SizedBox(height: 8),
            TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: 'Modelo / Marca')),
            const SizedBox(height: 8),
            TextField(controller: colorCtrl, decoration: const InputDecoration(labelText: 'Color')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await _supabase.from('cw_tickets').update({
                'vehicle_plate': plateCtrl.text.toUpperCase(),
                'vehicle_model': modelCtrl.text,
                'vehicle_color': colorCtrl.text,
              }).eq('id', ticket['id']);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Guardar Cambios'),
          ),
        ],
      ),
    );
  }
}


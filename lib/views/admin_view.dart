import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'washers_view.dart';
import 'billing_view.dart';
import 'clients_view.dart';
import 'reports_view.dart';
import 'payroll_view.dart';
import 'catalog_view.dart';
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
    return Scaffold(
      body: Row(
        children: [
          // Left Sidebar
          Container(
            width: 260,
            color: const Color(0xFF1E3A8A), 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                const Icon(Icons.local_car_wash, size: 64, color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  'STATION ADMIN',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
                const SizedBox(height: 48),
                _SidebarItem(
                  icon: Icons.point_of_sale,
                  title: 'Caja / Control',
                  isSelected: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                _SidebarItem(
                  icon: Icons.receipt_long,
                  title: 'Facturación CFDI',
                  isSelected: _selectedIndex == 4,
                  onTap: () => setState(() => _selectedIndex = 4),
                ),
                _SidebarItem(
                  icon: Icons.payments_outlined,
                  title: 'Nómina de Lavadores',
                  isSelected: _selectedIndex == 7,
                  onTap: () => setState(() => _selectedIndex = 7),
                ),
                _SidebarItem(
                  icon: Icons.history,
                  title: 'Historial / Ventas',
                  isSelected: _selectedIndex == 1,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
                _SidebarItem(
                  icon: Icons.people_outline,
                  title: 'Equipo Lavadores',
                  isSelected: _selectedIndex == 2,
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
                _SidebarItem(
                  icon: Icons.inventory_2_outlined,
                  title: 'Catálogo y Precios',
                  isSelected: _selectedIndex == 5,
                  onTap: () => setState(() => _selectedIndex = 5),
                ),
                _SidebarItem(
                  icon: Icons.people,
                  title: 'Clientes',
                  isSelected: _selectedIndex == 3,
                  onTap: () => setState(() => _selectedIndex = 3),
                ),
                const Spacer(),
                const Divider(color: Colors.white24),
                // Botón Limpiar Cache
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
          ),
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

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0: return CajaView(onNavigate: (i) => setState(() => _selectedIndex = i));
      case 1: return const ReportsView();
      case 2: return const WashersView();
      case 3: return const ClientsView();
      case 4: return const BillingView();
      case 5: return const CatalogView();
      case 7: return const PayrollView(); 
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
  final List<Map<String, dynamic>> _cart = [];
  bool _requiresInvoice = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final sRes = await _supabase.from('cw_services').select().eq('category', 'tiendita').eq('is_active', true);
    if (mounted) {
      setState(() {
        _snacks = List<Map<String, dynamic>>.from(sRes);
      });
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
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
      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
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

  Future<void> _processCart() async {
    if (_cart.isEmpty) return;
    setState(() => _isProcessing = true);
    try {
      final vehicles = _cart.where((c) => c['type'] == 'vehicle').toList();
      final snacks = _cart.where((c) => c['type'] == 'snack').toList();
      String? billingTicketId;

      if (vehicles.isEmpty && snacks.isNotEmpty) {
        final totalStr = _calculateTotal();
        final ticketResponse = await _supabase.from('cw_tickets').insert({
          'vehicle_plate': 'TIENDA',
          'vehicle_model': 'Venta Directa',
          'vehicle_color': '-',
          'vehicle_type': 'AUTO',
          'status': 'delivered',
          'payment_status': 'paid',
          'total_amount': totalStr,
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
        for (var i = 0; i < vehicles.length; i++) {
          final v = vehicles[i];
          final t = v['item'];
          billingTicketId ??= t['id'];
          final isReady = t['status'] == 'ready';
          await _supabase.from('cw_tickets').update({
            'payment_status': 'paid',
            if (isReady) 'status': 'delivered',
            if (isReady) 'completed_at': DateTime.now().toUtc().toIso8601String(),
            'requires_invoice': _requiresInvoice && i == 0,
          }).eq('id', t['id']);
        }
        if (snacks.isNotEmpty && billingTicketId != null) {
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
          final additionalAmount = snacks.fold<double>(0, (prev, s) {
             final t = s['item']['price_auto'] ?? s['item']['price'] ?? 0.0;
             return prev + (t is num ? t.toDouble() : double.tryParse(t.toString()) ?? 0.0) * s['qty'];
          });
          final firstTicket = vehicles.first['item'];
          final newTotal = (firstTicket['total_amount'] ?? 0.0) + additionalAmount;
          await _supabase.from('cw_tickets').update({'total_amount': newTotal}).eq('id', billingTicketId);
        }
      }

      if (mounted) {
        setState(() {
          _cart.clear();
          _requiresInvoice = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta cobrada correctamente.'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(
          title: const Text('Caja - Centro de Control / POS', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E3A8A),
          elevation: 0,
        ),
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Row(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        color: const Color(0xFF1E3A8A),
                        child: const Text('PUNTO DE VENTA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
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
                                  leading: Icon(isVehicle ? Icons.directions_car : Icons.fastfood, color: Colors.indigo, size: 28),
                                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(isVehicle ? 'Lavado de Auto' : 'Cantidad: ${c['qty']}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _removeFromCart(i),
                                  ),
                                );
                              },
                            ),
                      ),
                      const Divider(height: 1),
                      Container(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('SUBTOTAL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                                Text('\$${_calculateTotal().toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              title: const Text('Requiere Factura', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              value: _requiresInvoice,
                              onChanged: (val) => setState(() => _requiresInvoice = val),
                              contentPadding: EdgeInsets.zero,
                              activeColor: Colors.indigo,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: ElevatedButton(
                                onPressed: _isProcessing ? null : _processCart,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE53935),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: _isProcessing 
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text('COBRAR AHORA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.drive_eta, color: Colors.blueAccent),
                ),
                title: Text(
                  '${t['vehicle_plate']} - ${t['vehicle_model']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                enabled: !isInCart,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSnacksTab() {
    if (_snacks.isEmpty) return const Center(child: Text('No hay productos registrados'));
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.2, crossAxisSpacing: 16, mainAxisSpacing: 16),
      itemCount: _snacks.length,
      itemBuilder: (context, i) {
        final s = _snacks[i];
        final price = (s['price_auto'] ?? s['price'] ?? 0.0);
        return InkWell(
          onTap: () => _addToCart('snack', s),
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.fastfood, color: Colors.orange, size: 32),
                const SizedBox(height: 8),
                Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                Text('\$$price', style: const TextStyle(color: Colors.orange)),
              ],
            ),
          ),
        );
      },
    );
  }
}


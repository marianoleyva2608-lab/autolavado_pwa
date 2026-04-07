import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'washers_view.dart';
import 'billing_view.dart';
import 'clients_view.dart';
import 'reports_view.dart';

class AdminView extends StatefulWidget {
  const AdminView({super.key});

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  int _selectedIndex = 0; // 0 for Caja, 1 for Reports, 2 for Washers

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Left Sidebar
          Container(
            width: 260,
            color: const Color(0xFF1E3A8A), // Station Dark Blue
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
                  icon: Icons.history,
                  title: 'Historial / Ventas',
                  isSelected: _selectedIndex == 1,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
                _SidebarItem(
                  icon: Icons.people_outline,
                  title: 'Gestión de Lavadores',
                  isSelected: _selectedIndex == 2,
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
                _SidebarItem(
                  icon: Icons.people,
                  title: 'Clientes',
                  isSelected: _selectedIndex == 3,
                  onTap: () => setState(() => _selectedIndex = 3),
                ),
                _SidebarItem(
                  icon: Icons.receipt_long,
                  title: 'Facturación CFDI',
                  isSelected: _selectedIndex == 4,
                  onTap: () => setState(() => _selectedIndex = 4),
                ),
                _SidebarItem(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Gestión de Administración',
                  isSelected: _selectedIndex == 7,
                  onTap: () => setState(() => _selectedIndex = 7),
                ),
                const Spacer(),
                const Divider(color: Colors.white24),
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
      case 7: return const WashersView(); 
      default: return CajaView(onNavigate: (i) => setState(() => _selectedIndex = i));
    }
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
  List<Map<String, dynamic>> _workers = [];
  List<Map<String, dynamic>> _snacks = [];
  
  // Cart items structure: { type: 'vehicle' | 'snack', item: Map, qty: 1 }
  final List<Map<String, dynamic>> _cart = [];
  bool _requiresInvoice = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final wRes = await _supabase.from('cw_workers').select('id, name').eq('role', 'washer');
    final sRes = await _supabase.from('cw_services').select().eq('category', 'tiendita').eq('is_active', true);
    if (mounted) {
      setState(() {
        _workers = List<Map<String, dynamic>>.from(wRes);
        _snacks = List<Map<String, dynamic>>.from(sRes);
      });
    }
  }

  Future<void> _deliverVehicle(String ticketId) async {
    try {
      await _supabase.from('cw_tickets').update({
        'status': 'delivered',
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', ticketId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
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
    setState(() {
      _cart.removeAt(index);
    });
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

  Future<void> _processCart() async {
    if (_cart.isEmpty) return;
    setState(() => _isProcessing = true);
    
    try {
      final vehicles = _cart.where((c) => c['type'] == 'vehicle').toList();
      final snacks = _cart.where((c) => c['type'] == 'snack').toList();
      String? billingTicketId;

      // Unificar en el primer ticket o crear uno dummy si son puros snacks
      if (vehicles.isEmpty && snacks.isNotEmpty) {
        // Direct Tiendita Sales without a vehicle attached
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
        // Procesar todos los vehiculos en el carrito
        for (var i = 0; i < vehicles.length; i++) {
          final v = vehicles[i];
          final t = v['item'];
          
          billingTicketId ??= t['id']; // Al primer auto por si quieren facturar
          
          final isReady = t['status'] == 'ready';
          
          await _supabase.from('cw_tickets').update({
            'payment_status': 'paid',
            if (isReady) 'status': 'delivered',
            if (isReady) 'completed_at': DateTime.now().toUtc().toIso8601String(),
            'requires_invoice': _requiresInvoice && i == 0,
          }).eq('id', t['id']);
        }
        
        // Asignar los snacks al primer vehiculo de la lista si hay snacks
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
          
          // Actualizar el total_amount del ticket sumando los snacks (el auto ya trae el precio del servicio)
          final additionalAmount = snacks.fold<double>(0, (prev, s) {
             final t = s['item']['price_auto'] ?? s['item']['price'] ?? 0.0;
             return prev + (t is num ? t.toDouble() : double.tryParse(t.toString()) ?? 0.0) * s['qty'];
          });
          final firstTicket = vehicles.first['item'];
          final newTotal = (firstTicket['total_amount'] ?? 0.0) + additionalAmount;
          
          await _supabase.from('cw_tickets').update({'total_amount': newTotal}).eq('id', billingTicketId);
          firstTicket['total_amount'] = newTotal; // Local update
        }
      }

      if (mounted) {
        setState(() {
          _cart.clear();
          _requiresInvoice = false;
        });

        // Venta procesada exitosamente

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Venta cobrada correctamente.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error en POS checkout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
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
        if (widget.onNavigate != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
            child: Row(
              children: [
                _QuickActionCard(
                  title: 'FACTURACIÓN CFDI',
                  icon: Icons.receipt_long,
                  color: Colors.indigo,
                  onTap: () => widget.onNavigate!(4),
                ),
                const SizedBox(width: 16),
                _QuickActionCard(
                  title: 'ADMINISTRACIÓN',
                  icon: Icons.admin_panel_settings,
                  color: Colors.redAccent,
                  onTap: () => widget.onNavigate!(7),
                ),
              ],
            ),
          ),
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Panel: Tabs for Items
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
                
                // Right Panel: Point of Sale Checkout
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
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                Text('\$${_calculateTotal().toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1E3A8A))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Checkbox(
                                  value: _requiresInvoice,
                                  onChanged: (v) => setState(() => _requiresInvoice = v ?? false),
                                  activeColor: const Color(0xFF1E3A8A),
                                ),
                                const Text('Requiere Factura CFDI', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: ElevatedButton(
                                onPressed: _cart.isEmpty || _isProcessing ? null : _processCart,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669), // Emerald
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: _isProcessing 
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text('COBRAR IMPORTE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            )
                          ],
                        ),
                      )
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
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from('cw_tickets')
          .stream(primaryKey: ['id'])
          .inFilter('status', ['queue', 'washing', 'ready'])
          .order('created_at', ascending: true),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final tickets = snapshot.data!;
        if (tickets.isEmpty) return const Center(child: Text('No hay autos en curso', style: TextStyle(fontSize: 18, color: Colors.black45)));

        return ListView.builder(
          itemCount: tickets.length,
          itemBuilder: (context, index) {
            final t = tickets[index];
            String washerName = 'Sin asignar';
            if (t['worker_assigned_id'] != null && _workers.isNotEmpty) {
              try {
                washerName = _workers.firstWhere((w) => w['id'] == t['worker_assigned_id'])['name'];
              } catch (_) {}
            }

            final isReady = t['status'] == 'ready';
            final isPaid = t['payment_status'] == 'paid';
            final inCart = _cart.any((c) => c['type'] == 'vehicle' && c['item']['id'] == t['id']);
            
            Widget trailingWidget;
            if (isPaid) {
              if (isReady) {
                trailingWidget = ElevatedButton.icon(
                  onPressed: () => _deliverVehicle(t['id']),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('ENTREGAR'),
                );
              } else {
                trailingWidget = const Chip(
                  label: Text('LAVANDO • PAGADO', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 11)),
                  backgroundColor: Color(0xFFE8F5E9),
                  side: BorderSide(color: Colors.green, width: 1.5),
                  padding: EdgeInsets.only(left: 4, right: 4),
                  visualDensity: VisualDensity.compact,
                );
              }
            } else {
              trailingWidget = ElevatedButton(
                onPressed: inCart ? null : () => _addToCart('vehicle', t),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
                child: Text(inCart ? 'EN CAJA' : 'AÑADIR A CAJA'),
              );
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: inCart ? const Color(0xFF1E3A8A) : Colors.black12, width: inCart ? 2 : 1)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(color: inCart ? const Color(0xFF1E3A8A).withOpacity(0.1) : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.directions_car, color: inCart ? const Color(0xFF1E3A8A) : Colors.grey[600]),
                ),
                title: Row(
                  children: [
                    Text(t['vehicle_plate'] ?? 'S/N', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(width: 8),
                    if (isReady && !isPaid)
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(4)), child: const Text('Listo', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold))),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('${t['vehicle_model']} • \$${t['total_amount']}', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Lavador: $washerName', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                  ],
                ),
                trailing: trailingWidget,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSnacksTab() {
    if (_snacks.isEmpty) return const Center(child: Text('No hay productos en la tiendita.'));
    
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _snacks.length,
      itemBuilder: (context, index) {
        final s = _snacks[index];
        final priceRaw = s['price_auto'] ?? s['price'] ?? 0.0;
        final price = priceRaw is num ? priceRaw.toDouble() : double.tryParse(priceRaw.toString()) ?? 0.0;

        return InkWell(
          onTap: () => _addToCart('snack', s),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withOpacity(0.3), width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.fastfood, size: 48, color: Colors.orange),
                const SizedBox(height: 12),
                Text(s['name'] ?? '', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Text('\$${price.toStringAsFixed(2)}', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w900, fontSize: 16)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TicketCard extends StatefulWidget {
  final Map<String, dynamic> ticket;
  final String washerName;
  final Function(bool) onProcess;

  const _TicketCard({required this.ticket, required this.washerName, required this.onProcess});

  @override
  State<_TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends State<_TicketCard> {
  bool _requiresInvoice = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    final isReady = t['status'] == 'ready';
    final isPaid = t['payment_status'] == 'paid';
    
    Color statusColor = Colors.orange;
    String statusLabel = 'En Cola';

    final createdAt = DateTime.parse(t['created_at']).toLocal();
    final timeStr = '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    final dateStr = '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}';
    final entryDateTime = '$dateStr - $timeStr';
    
    if (t['status'] == 'washing') {
      statusColor = Colors.blue;
      statusLabel = 'Lavando';
    } else if (t['status'] == 'ready') {
      statusColor = Colors.green;
      statusLabel = 'Listo';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.black12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 60,
              decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(6)),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(t['vehicle_plate'] ?? 'S/N', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      if (t['vehicle_type'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(4)),
                          child: Text(t['vehicle_type'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                        ),
                    ],
                  ),
                  Text('${t['vehicle_model']} • ${t['vehicle_color']}', style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(entryDateTime, style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                      const SizedBox(width: 8),
                      if (t['worker_assigned_id'] != null)
                         Text('Lava: ${widget.washerName}', style: const TextStyle(fontSize: 11, color: Colors.purple, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            // Factura Option
            if (isReady) ...[
              Column(
                children: [
                  const Text('Factura?', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  Checkbox(
                    value: _requiresInvoice,
                    onChanged: (val) => setState(() => _requiresInvoice = val ?? false),
                    activeColor: const Color(0xFF1E3A8A),
                  ),
                ],
              ),
              const SizedBox(width: 20),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('\$${t['total_amount']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1E3A8A))),
                Text(isPaid ? 'PAGADO' : 'PENDIENTE', style: TextStyle(color: isPaid ? Colors.green : Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
            const SizedBox(width: 32),
            if (isReady)
              ElevatedButton(
                onPressed: () => widget.onProcess(_requiresInvoice),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(isPaid ? 'ENTREGAR' : 'COBRAR Y ENTREGAR'),
              )
            else
              const Icon(Icons.access_time, color: Colors.black26, size: 32),
          ],
        ),
      ),
    );
  }
}

class _ElapsedTimeDisplay extends StatefulWidget {
  final String startTime;
  const _ElapsedTimeDisplay({required this.startTime});

  @override
  State<_ElapsedTimeDisplay> createState() => _ElapsedTimeDisplayState();
}

class _ElapsedTimeDisplayState extends State<_ElapsedTimeDisplay> {
  Timer? _timer;
  late DateTime _start;

  @override
  void initState() {
    super.initState();
    _start = DateTime.parse(widget.startTime).toLocal();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diff = DateTime.now().difference(_start);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    
    String timeStr = '';
    if (hours > 0) {
      timeStr = '$hours h $minutes m';
    } else {
      timeStr = '$minutes min';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          const Icon(Icons.timer, size: 14, color: Colors.deepOrange),
          const SizedBox(width: 4),
          Text(
            timeStr,
            style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
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
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: isSelected ? Colors.white : Colors.white70),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        tileColor: isSelected ? Colors.white.withValues(alpha: 0.1) : null,
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}


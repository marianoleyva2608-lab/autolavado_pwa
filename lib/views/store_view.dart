import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoreView extends StatefulWidget {
  const StoreView({super.key});

  @override
  State<StoreView> createState() => _StoreViewState();
}

class _StoreViewState extends State<StoreView> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _products = [];
  Map<String, int> _cart = {}; // ID -> quantity
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final response = await _supabase
          .from('cw_services')
          .select()
          .eq('category', 'tiendita')
          .eq('is_active', true)
          .order('name');
      
      if (mounted) {
        setState(() {
          _products = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching products: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _total {
    double total = 0;
    _cart.forEach((id, qty) {
      final p = _products.firstWhere((element) => element['id'] == id);
      total += (p['price'] as num) * qty;
    });
    return total;
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) return;
    
    setState(() => _isSubmitting = true);
    
    try {
      // 1. Create a "Tienda" ticket
      final ticketResponse = await _supabase.from('cw_tickets').insert({
        'customer_name': 'Venta Directa',
        'vehicle_plate': 'TIENDA',
        'status': 'delivered',
        'payment_status': 'paid',
        'total_amount': _total,
        'completed_at': DateTime.now().toIso8601String(),
      }).select().single();

      final ticketId = ticketResponse['id'];

      // 2. Create ticket items
      List<Map<String, dynamic>> items = [];
      _cart.forEach((id, qty) {
        final p = _products.firstWhere((element) => element['id'] == id);
        items.add({
          'ticket_id': ticketId,
          'service_id': id,
          'quantity': qty,
          'price_at_time': p['price'],
        });
      });

      await _supabase.from('cw_ticket_items').insert(items);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Venta completada con éxito')),
        );
        setState(() {
          _cart = {};
          _isSubmitting = false;
        });
      }
    } catch (e) {
      print('Error in checkout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar venta: $e')),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tiendita / Snacks'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final p = _products[index];
                    final qty = _cart[p['id']] ?? 0;
                    final imageUrl = p['image_url'];
                    
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: imageUrl != null && imageUrl.toString().isNotEmpty
                                ? Image.network(imageUrl, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.fastfood, size: 30, color: Colors.orange))
                                : const Icon(Icons.fastfood, size: 30, color: Colors.orange),
                            ),
                          ),
                          Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('\$${p['price']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 20),
                                onPressed: qty > 0 ? () => setState(() => _cart[p['id']] = qty - 1) : null,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: Text('$qty', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 20),
                                onPressed: () => setState(() => _cart[p['id']] = qty + 1),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total a pagar:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('\$${_total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _cart.isEmpty || _isSubmitting ? null : _checkout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSubmitting 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('COBRAR AHORA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
    );
  }
}

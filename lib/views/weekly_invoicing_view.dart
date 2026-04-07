import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'billing_view.dart';

class WeeklyInvoicingView extends StatefulWidget {
  const WeeklyInvoicingView({super.key});

  @override
  State<WeeklyInvoicingView> createState() => _WeeklyInvoicingViewState();
}

class _WeeklyInvoicingViewState extends State<WeeklyInvoicingView> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _tickets = [];
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchWeeklyTickets();
  }

  Future<void> _fetchWeeklyTickets() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final lastWeek = now.subtract(const Duration(days: 7)).toUtc().toIso8601String();
      
      final res = await _supabase
          .from('cw_tickets')
          .select()
          .eq('status', 'delivered')
          .gte('completed_at', lastWeek)
          .order('completed_at', ascending: false);

      if (mounted) {
        setState(() {
          _tickets = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching weekly tickets: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _tickets.where((t) {
      final matchesSearch = (t['customer_name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                            (t['vehicle_plate'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: TextField(
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: const InputDecoration(
            hintText: 'Buscar por cliente o placa...',
            prefixIcon: Icon(Icons.search),
            border: InputBorder.none,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchWeeklyTickets,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : filtered.isEmpty
              ? const Center(child: Text('No hay vehículos lavados esta semana pendientes de facturar.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final t = filtered[i];
                    final date = DateTime.parse(t['completed_at']).toLocal();
                    final isCredit = t['payment_status'] == 'credit';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCredit ? Colors.orange.shade100 : Colors.blue.shade100,
                          child: Icon(Icons.directions_car, color: isCredit ? Colors.orange : Colors.blue),
                        ),
                        title: Text('${t['vehicle_plate']} - ${t['vehicle_model']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Cliente: ${t['customer_name'] ?? "S/N"}\nLavadura: ${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('\$${t['total_amount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                            if (isCredit)
                              const Text('CRÉDITO', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => BillingView(ticket: t))
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

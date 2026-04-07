import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PayrollView extends StatefulWidget {
  const PayrollView({super.key});

  @override
  State<PayrollView> createState() => _PayrollViewState();
}

class _PayrollViewState extends State<PayrollView> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _payrollData = [];

  // Date filter
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _fetchPayroll();
  }

  Future<void> _fetchPayroll() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch all workers
      final workersRes = await _supabase
          .from('cw_workers')
          .select()
          .eq('role', 'washer')
          .eq('is_active', true);
      final workers = List<Map<String, dynamic>>.from(workersRes);

      // 2. Fetch all paid tickets in date range WITH their items and service names
      final ticketsRes = await _supabase
          .from('cw_tickets')
          .select(
            '*, cw_ticket_items(service_id, cw_services(name, comm_auto, comm_suv_ch, comm_suv_m, comm_g, comm_xl))',
          )
          .eq('status', 'delivered')
          .eq('payment_status', 'paid')
          .gte('created_at', _dateRange.start.toUtc().toIso8601String())
          .lte(
            'created_at',
            _dateRange.end
                .add(const Duration(days: 1))
                .toUtc()
                .toIso8601String(),
          );

      final tickets = List<Map<String, dynamic>>.from(ticketsRes);

      // 3. Fetch all worker transactions (loans, tips, items, etc)
      final transactionsRes = await _supabase
          .from('cw_worker_ledger')
          .select()
          .gte('created_at', _dateRange.start.toUtc().toIso8601String())
          .lte(
            'created_at',
            _dateRange.end
                .add(const Duration(days: 1))
                .toUtc()
                .toIso8601String(),
          );
      final transactions = List<Map<String, dynamic>>.from(transactionsRes);

      // 4. Process data
      List<Map<String, dynamic>> processed = [];
      for (var w in workers) {
        final workerTickets = tickets
            .where((t) => t['worker_assigned_id'] == w['id'])
            .toList();
        double totalRevenue = 0;
        double totalCommission = 0;

        List<Map<String, dynamic>> ticketDetails = [];
        for (var t in workerTickets) {
          totalRevenue += (t['total_amount'] as num?)?.toDouble() ?? 0.0;

          String serviceName = 'Desconocido';
          double ticketCommissionValue = 0;

          if (t['cw_ticket_items'] != null &&
              (t['cw_ticket_items'] as List).isNotEmpty) {
            final firstItem = t['cw_ticket_items'][0];
            final svc = firstItem['cw_services'];
            serviceName = svc['name'] ?? 'Servicio';

            final vType = t['vehicle_type'] ?? 'AUTO';
            String commKey = 'comm_auto';
            if (vType == 'SUV CH') {
              commKey = 'comm_suv_ch';
            } else if (vType == 'SUV M') {
              commKey = 'comm_suv_m';
            } else if (vType == 'G') {
              commKey = 'comm_g';
            } else if (vType == 'XL') {
              commKey = 'comm_xl';
            }

            ticketCommissionValue = (svc[commKey] as num?)?.toDouble() ?? 0.0;
          }

          ticketDetails.add({
            'date': t['created_at'],
            'plate': t['vehicle_plate'],
            'type': t['vehicle_type'],
            'service': serviceName,
            'amount': t['total_amount'],
            'comm': ticketCommissionValue,
          });
          totalCommission += ticketCommissionValue;
        }

        // Add transactions (loans, tips, etc)
        final workerTrans = transactions.where((tr) => tr['worker_id'] == w['id']).toList();
        double totalLoans = 0;
        double totalTips = 0;
        double totalStore = 0;
        double totalBonus = 0;

        for (var tr in workerTrans) {
          final amt = (tr['amount'] as num?)?.toDouble() ?? 0.0;
          final type = tr['type'];
          if (type == 'loan') totalLoans += amt;
          else if (type == 'tip') totalTips += amt;
          else if (type == 'purchase') totalStore += amt;
          else if (type == 'bonus') totalBonus += amt;
        }

        double netToPay = totalCommission + totalTips + totalBonus - totalLoans - totalStore;

        processed.add({
          'worker_id': w['id'],
          'worker_name': w['name'],
          'car_count': workerTickets.length,
          'total_revenue': totalRevenue,
          'total_commission': totalCommission,
          'total_loans': totalLoans,
          'total_tips': totalTips,
          'total_store': totalStore,
          'total_bonus': totalBonus,
          'to_pay': netToPay,
          'tickets': ticketDetails,
          'transactions': workerTrans,
        });
      }

      if (mounted) {
        setState(() {
          _payrollData = processed;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching payroll: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showAddAdjustmentDialog(String workerId, String workerName) async {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    String type = 'loan';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Nuevo Ajuste: $workerName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: type,
                isExpanded: true,
                items: const [
                   DropdownMenuItem(value: 'loan', child: Text('Préstamo (Deducción)')),
                   DropdownMenuItem(value: 'purchase', child: Text('Tiendita (Deducción)')),
                   DropdownMenuItem(value: 'tip', child: Text('Propina (Extra)')),
                   DropdownMenuItem(value: 'bonus', child: Text('Bono (Extra)')),
                ],
                onChanged: (val) => setDialogState(() => type = val!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Monto \$', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Motivo / Descripción', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountController.text);
                if (amt == null) return;
                
                await _supabase.from('cw_worker_ledger').insert({
                  'worker_id': workerId,
                  'amount': amt,
                  'type': type,
                  'description': descController.text,
                });
                
                if (mounted) {
                  Navigator.pop(context);
                  _fetchPayroll();
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Nómina - Detalle por Lavador', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                initialDateRange: _dateRange,
                firstDate: DateTime(2023),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (picked != null) {
                setState(() => _dateRange = picked);
                _fetchPayroll();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF1E3A8A)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Cálculo de comisiones fijas + ajustes (propinas, préstamos, tiendita).',
                    style: TextStyle(fontWeight: FontWeight.w500, color: Colors.blueGrey),
                  ),
                ),
                Text(
                  '${_dateRange.start.day}/${_dateRange.start.month} - ${_dateRange.end.day}/${_dateRange.end.month}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                ),
              ],
            ),
          ),
          _isLoading
              ? const Expanded(child: Center(child: CircularProgressIndicator()))
              : Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _payrollData.length,
                    itemBuilder: (context, index) {
                      final p = _payrollData[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[50],
                            child: const Icon(Icons.person, color: Color(0xFF1E3A8A)),
                          ),
                          title: Text(p['worker_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          subtitle: Text(
                            '\$${p['total_commission'].toStringAsFixed(0)} com. | \$${p['total_tips'].toStringAsFixed(0)} prop. | -\$${(p['total_loans'] + p['total_store']).toStringAsFixed(0)} deduc.',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '\$${p['to_pay'].toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.green),
                                  ),
                                  const Text('A PAGAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                                onPressed: () => _showAddAdjustmentDialog(p['worker_id'], p['worker_name']),
                              ),
                            ],
                          ),
                          children: [
                            const Divider(),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(flex: 2, child: Text('Detalle / Servicio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  Expanded(child: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  Text('Monto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ),
                            // List services as additions
                            ...((p['tickets'] as List).map((t) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(flex: 2, child: Text(t['service'], style: const TextStyle(fontSize: 12))),
                                    Expanded(child: Text(t['type'], style: const TextStyle(fontSize: 12, color: Colors.blueGrey))),
                                    Text('+\$${t['comm']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                                  ],
                                ),
                              );
                            }).toList()),
                            // List Ledger items (loans, tips, items)
                            ...((p['transactions'] as List).map((tr) {
                              final isCredit = tr['type'] == 'tip' || tr['type'] == 'bonus';
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(flex: 2, child: Text(tr['description'] ?? tr['type'], style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic))),
                                    Expanded(child: Text(tr['type'].toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                                    Text(
                                      '${isCredit ? "+" : "-"}\$${tr['amount']}',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isCredit ? Colors.green : Colors.red),
                                    ),
                                  ],
                                ),
                              );
                            }).toList()),
                            const SizedBox(height: 16),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }
}

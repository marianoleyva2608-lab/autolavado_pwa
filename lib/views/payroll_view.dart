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

  double _globalCommissionPercent = 30.0; // Default 30%

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

      // 3. Process data
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

          // Extraer nombre del servicio y calcular comisión específica
          String serviceName = 'Desconocido';
          double ticketCommissionValue = 0;

          if (t['cw_ticket_items'] != null &&
              (t['cw_ticket_items'] as List).isNotEmpty) {
            final firstItem = t['cw_ticket_items'][0];
            final svc = firstItem['cw_services'];
            serviceName = svc['name'] ?? 'Servicio';

            // Determinar comisión basado en el tipo de vehículo
            final vType = t['vehicle_type'] ?? 'AUTO';
            String commKey = 'comm_auto';
            if (vType == 'SUV CH') {
              commKey = 'comm_suv_ch';
            } else if (vType == 'SUV M')
              commKey = 'comm_suv_m';
            else if (vType == 'G')
              commKey = 'comm_g';
            else if (vType == 'XL')
              commKey = 'comm_xl';

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

        processed.add({
          'worker_id': w['id'],
          'worker_name': w['name'],
          'car_count': workerTickets.length,
          'total_revenue': totalRevenue,
          'to_pay': totalCommission,
          'tickets': ticketDetails,
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'Nómina - Detalle por Lavador',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
          // Header / Global Commission
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.percent, color: Color(0xFF1E3A8A)),
                const SizedBox(width: 12),
                const Text(
                  'Comisión %:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 80,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (val) {
                      final p = double.tryParse(val);
                      if (p != null) {
                        setState(() {
                          _globalCommissionPercent = p;
                          for (var item in _payrollData) {
                            item['commission_percent'] = p;
                            item['to_pay'] = item['total_revenue'] * (p / 100);
                          }
                        });
                      }
                    },
                    controller: TextEditingController(
                      text: _globalCommissionPercent.toStringAsFixed(0),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Del ${_dateRange.start.day}/${_dateRange.start.month} al ${_dateRange.end.day}/${_dateRange.end.month}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.blueGrey,
                  ),
                ),
              ],
            ),
          ),

          _isLoading
              ? const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              : Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _payrollData.length,
                    itemBuilder: (context, index) {
                      final p = _payrollData[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[50],
                            child: const Icon(
                              Icons.person,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          title: Text(
                            p['worker_name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Text(
                            '${p['car_count']} autos | Generado: \$${p['total_revenue'].toStringAsFixed(0)}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${p['to_pay'].toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.green,
                                ),
                              ),
                              const Text(
                                'A PAGAR',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          children: [
                            const Divider(),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Servicio',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Tipo',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Placa',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Precio',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...((p['tickets'] as List).map((t) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        t['service'],
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        t['type'],
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        t['plate'],
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    Text(
                                      '\$${t['comm']}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
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

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PayrollView extends StatefulWidget {
  const PayrollView({super.key});

  @override
  State<PayrollView> createState() => _PayrollViewState();
}

class _PayrollViewState extends State<PayrollView> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _payrollData = [];
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now().add(const Duration(days: 1)),
  );
  bool _showTable = false;

  @override
  void initState() {
    super.initState();
    _fetchPayroll();
  }

  Future<void> _fetchPayroll() async {
    setState(() => _isLoading = true);
    try {
      final start = _dateRange.start.toUtc().toIso8601String();
      final end = _dateRange.end.toUtc().toIso8601String();

      // 1. Fetch Workers
      final workersRes = await _supabase.from('cw_workers').select('id, name').eq('role', 'washer');
      final workers = List<Map<String, dynamic>>.from(workersRes);

      // 2. Fetch Tickets with items in range
      final ticketsRes = await _supabase.from('cw_tickets')
          .select('*, cw_ticket_items(*, cw_services(*))')
          .gte('created_at', start)
          .lte('created_at', end)
          .eq('status', 'delivered');
      
      final tickets = List<Map<String, dynamic>>.from(ticketsRes);

      // 3. Fetch Ledger transactions
      final transactionsRes = await _supabase.from('cw_worker_ledger')
          .select('*, cw_tickets(cw_ticket_items(quantity, cw_services(name)))')
          .gte('created_at', start)
          .lte('created_at', end);
      final transactions = List<Map<String, dynamic>>.from(transactionsRes);

      // 4. Fetch Global Balances for everything (Debt)
      final allLedger = await _supabase.from('cw_worker_ledger').select('worker_id, amount');
      Map<String, double> globalBalances = {};
      for (var b in allLedger) {
        final wId = b['worker_id'] as String;
        final amt = (b['amount'] as num?)?.toDouble() ?? 0.0;
        globalBalances[wId] = (globalBalances[wId] ?? 0.0) + amt;
      }

      // 4. Process data
      List<Map<String, dynamic>> processed = [];
      for (var w in workers) {
        final workerTickets = tickets.where((t) => t['worker_assigned_id'] == w['id']).toList();
        double totalRevenue = 0;
        double totalCommission = 0;

        List<Map<String, dynamic>> ticketDetails = [];
        for (var t in workerTickets) {
          totalRevenue += (t['total_amount'] as num?)?.toDouble() ?? 0.0;
          String serviceName = 'Desconocido';
          double ticketCommissionValue = 0;

          if (t['cw_ticket_items'] != null && (t['cw_ticket_items'] as List).isNotEmpty) {
            final firstItem = t['cw_ticket_items'][0];
            final svc = firstItem['cw_services'];
            serviceName = svc['name'] ?? 'Servicio';

            final vType = t['vehicle_type'] ?? 'AUTO';
            String commKey = 'comm_auto';
            if (vType == 'SUV CH') commKey = 'comm_suv_ch';
            else if (vType == 'SUV M') commKey = 'comm_suv_m';
            else if (vType == 'G') commKey = 'comm_g';
            else if (vType == 'XL') commKey = 'comm_xl';

            // Si tiene comisión especial manual, usar esa. Si no, usar la del catálogo.
            if (t['special_commission'] != null) {
              ticketCommissionValue = (t['special_commission'] as num).toDouble();
            } else {
              ticketCommissionValue = (svc[commKey] as num?)?.toDouble() ?? 0.0;
            }
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

        final workerTrans = transactions.where((tr) => tr['worker_id'] == w['id']).toList();
        double totalLoans = 0;
        double totalTips = 0;
        double totalStore = 0;
        double totalBonus = 0;

        for (var tr in workerTrans) {
          final amt = (tr['amount'] as num?)?.toDouble() ?? 0.0;
          final type = tr['type'];

          if (type == 'purchase' && tr['cw_tickets'] != null) {
            try {
              final items = tr['cw_tickets']['cw_ticket_items'] as List;
              if (items.isNotEmpty) {
                final detail = items.map((i) => "${i['quantity']}x ${i['cw_services']['name']}").join(", ");
                tr['description'] = "Tienda: $detail";
              }
            } catch (e) {}
          }

          // Usamos valores absolutos para las variables de visualización
          if (type == 'loan') totalLoans += amt.abs();
          else if (type == 'tip') totalTips += amt.abs();
          else if (type == 'purchase') totalStore += amt.abs();
          else if (type == 'bonus') totalBonus += amt.abs();
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
          'global_balance': globalBalances[w['id']] ?? 0.0,
        });
      }

      if (mounted) {
        setState(() {
          _payrollData = processed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _printWeeklySummary() async {
    final pdf = pw.Document();
    final dateStr = '${DateFormat('dd/MM/yy').format(_dateRange.start)} - ${DateFormat('dd/MM/yy').format(_dateRange.end)}';
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 0, child: pw.Text('RESUMEN SEMANAL DE NOMINA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18))),
              pw.Text('Periodo: $dateStr'),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headers: ['LAVADOR', 'AUTOS', 'COMIS.', 'PROP./BONO', 'PREST.', 'TIENDA', 'TOTAL', 'DEUDA TOT.'],
                data: _payrollData.map((w) => [
                  w['worker_name'],
                  w['car_count'],
                  '\$${w['total_commission'].toStringAsFixed(0)}',
                  '\$${(w['total_tips'] + w['total_bonus']).toStringAsFixed(0)}',
                  '\$${w['total_loans'].toStringAsFixed(0)}',
                  '\$${w['total_store'].toStringAsFixed(0)}',
                  '\$${w['to_pay'].toStringAsFixed(2)}',
                  '\$${(w['global_balance'] as double).toStringAsFixed(2)}',
                ]).toList(),
              ),
              pw.SizedBox(height: 20),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('TOTAL GENERAL: \$${_calculateGrandTotal().toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> _printIndividualReport(Map<String, dynamic> w) async {
    final pdf = pw.Document();
    final dateStr = '${DateFormat('dd/MM/yy').format(_dateRange.start)} - ${DateFormat('dd/MM/yy').format(_dateRange.end)}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 0, child: pw.Text('COMPROBANTE DE PAGO INDIVIDUAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18))),
              pw.Text('Lavador: ${w['worker_name']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.Text('Periodo: $dateStr'),
              pw.SizedBox(height: 20),
              
              pw.Text('DETALLE DE SERVICIOS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.TableHelper.fromTextArray(
                headers: ['FECHA', 'PLACA', 'SERVICIO', 'TIPO', 'COMIS.'],
                data: (w['tickets'] as List).map((t) => [
                  DateFormat('dd/MM HH:mm').format(DateTime.parse(t['date'])),
                  t['plate'],
                  t['service'],
                  t['type'],
                  '\$${t['comm'].toStringAsFixed(0)}',
                ]).toList(),
              ),
              pw.SizedBox(height: 15),

              pw.Text('AJUSTES Y DEDUCCIONES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.TableHelper.fromTextArray(
                headers: ['FECHA', 'TIPO', 'DESCRIPCION', 'MONTO'],
                data: (w['transactions'] as List).map((tr) => [
                  DateFormat('dd/MM').format(DateTime.parse(tr['created_at'])),
                  tr['type'].toString().toUpperCase(),
                  tr['description'] ?? '-',
                  '${(tr['type'] == 'loan' || tr['type'] == 'purchase') ? '-' : '+'}\$${(tr['amount'] as num).abs().toStringAsFixed(0)}',
                ]).toList(),
              ),
              
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                child: pw.Column(
                  children: [
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('Subtotal Comisiones:'), pw.Text('\$${w['total_commission'].toStringAsFixed(2)}')
                    ]),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('Total Propinas/Bonos:'), pw.Text('\$${(w['total_tips'] + w['total_bonus']).toStringAsFixed(2)}')
                    ]),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('Total Deducciones:'), pw.Text('-\$${(w['total_loans'] + w['total_store']).toStringAsFixed(2)}')
                    ]),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('TOTAL NETO A PAGAR EN LA SEMANA:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), 
                      pw.Text('\$${w['to_pay'].toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14))
                    ]),
                    pw.SizedBox(height: 5),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('Saldo Histórico (Deuda Total Restante):', style: pw.TextStyle(color: PdfColors.grey700)), 
                      pw.Text('\$${(w['global_balance'] as double).toStringAsFixed(2)}', style: pw.TextStyle(color: w['global_balance'] < 0 ? PdfColors.red : PdfColors.green))
                    ]),
                  ],
                ),
              ),
              pw.SizedBox(height: 40),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(children: [pw.SizedBox(width: 150, child: pw.Divider()), pw.Text('Firma del Lavador')]),
                  pw.Column(children: [pw.SizedBox(width: 150, child: pw.Divider()), pw.Text('Firma de Administracion')]),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
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
            icon: Icon(_showTable ? Icons.list : Icons.table_chart),
            tooltip: _showTable ? 'Vista de Tarjetas' : 'Vista de Tabla Semanal',
            onPressed: () => setState(() => _showTable = !_showTable),
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Imprimir Resumen Semanal',
            onPressed: () => _printWeeklySummary(),
          ),
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
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Periodo: ${DateFormat('dd MMM').format(_dateRange.start)} al ${DateFormat('dd MMM yyyy').format(_dateRange.end)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text('Total General a Pagar: \$${_calculateGrandTotal().toStringAsFixed(2)}', style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              Expanded(
                child: _showTable ? _buildSummaryTable() : _buildCardsList(),
              ),
            ],
          ),
    );
  }

  double _calculateGrandTotal() {
    return _payrollData.fold(0, (sum, item) => sum + item['to_pay']);
  }

  Widget _buildSummaryTable() {
    if (_payrollData.isEmpty) return const Center(child: Text('No hay datos para este periodo'));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFF1E3A8A).withValues(alpha: 0.1)),
              columns: const [
                DataColumn(label: Text('LAVADOR')),
                DataColumn(label: Text('AUTOS')),
                DataColumn(label: Text('COMISIÓN \$')),
                DataColumn(label: Text('PROPINAS \$')),
                DataColumn(label: Text('PRESTAMOS \$')),
                DataColumn(label: Text('TIENDITA \$')),
                DataColumn(label: Text('TOTAL A PAGAR', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: _payrollData.map((w) => DataRow(cells: [
                DataCell(Text(w['worker_name'], style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(w['car_count'].toString())),
                DataCell(Text('\$${w['total_commission'].toStringAsFixed(0)}')),
                DataCell(Text('\$${(w['total_tips'] + w['total_bonus']).toStringAsFixed(0)}', style: const TextStyle(color: Colors.green))),
                DataCell(Text('\$${w['total_loans'].toStringAsFixed(0)}', style: const TextStyle(color: Colors.red))),
                DataCell(Text('\$${w['total_store'].toStringAsFixed(0)}', style: const TextStyle(color: Colors.red))),
                DataCell(Text('\$${w['to_pay'].toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo))),
              ])).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardsList() {
    if (_payrollData.isEmpty) return const Center(child: Text('No hay registros en este periodo'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _payrollData.length,
      itemBuilder: (context, i) {
        final w = _payrollData[i];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            title: Text(w['worker_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            subtitle: Text('Autos: ${w['car_count']}  |  Total a Pagar: \$${w['to_pay'].toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
            trailing: SizedBox(
              width: 96,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.print, color: Colors.blue),
                    onPressed: () => _printIndividualReport(w),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.indigo),
                    onPressed: () => _showAddAdjustmentDialog(w['worker_id'], w['worker_name']),
                  ),
                ],
              ),
            ),
            children: [
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Desglose de Servicios:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    ... (w['tickets'] as List).map((t) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${t['plate']} - ${t['service']} (${t['type']})', style: const TextStyle(fontSize: 13)),
                          Text('\$${t['comm'].toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )),
                    const SizedBox(height: 16),
                    const Text('Ajustes y Tiendita:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    ... (w['transactions'] as List).map((tr) {
                      final type = tr['type'];
                      final isDeduction = type == 'loan' || type == 'purchase';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${tr['description'] ?? type.toString().toUpperCase()} (${DateFormat('dd/MM').format(DateTime.parse(tr['created_at']))})', style: const TextStyle(fontSize: 13)),
                            Text('${isDeduction ? '-' : '+'}\$${tr['amount']}', style: TextStyle(color: isDeduction ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }),
                    if ((w['transactions'] as List).isEmpty) const Text('Sin ajustes en el periodo', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Saldo Histórico (Deuda Total):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('\$${(w['global_balance'] as double).toStringAsFixed(2)}', style: TextStyle(color: w['global_balance'] < 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

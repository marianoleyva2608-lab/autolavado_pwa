import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'billing_view.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _filteredTickets = [];
  String _searchQuery = '';
  double _totalSales = 0.0;
  int _totalCars = 0;

  // Filtros
  String _timeFilter = 'all'; // all, day, week, month
  String _workerFilter = 'all'; 
  List<Map<String, dynamic>> _workers = [];

  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _fetchWorkers();
    _fetchReports();
    
    // Suscripción a cambios en tiempo real
    _subscription = _supabase.channel('public:cw_tickets').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'cw_tickets',
      callback: (payload) {
        if (mounted) {
          _fetchReports();
        }
      },
    ).subscribe();
  }

  @override
  void dispose() {
    if (_subscription != null) {
      _supabase.removeChannel(_subscription!);
    }
    super.dispose();
  }

  Future<void> _fetchWorkers() async {
    final response = await _supabase.from('cw_workers').select('id, name').eq('role', 'washer');
    if (mounted) {
      setState(() {
        _workers = List<Map<String, dynamic>>.from(response);
      });
    }
  }

  void _applyFilter() {
    setState(() {
      if (_searchQuery.trim().isEmpty) {
        _filteredTickets = List.from(_tickets);
      } else {
        final q = _searchQuery.toLowerCase();
        _filteredTickets = _tickets.where((t) {
          final placa = (t['vehicle_plate'] ?? '').toString().toLowerCase();
          final modelo = (t['vehicle_model'] ?? '').toString().toLowerCase();
          final client = (t['client_name'] ?? t['customer_name'] ?? '').toString().toLowerCase();
          final worker = (t['worker_name_ui'] ?? '').toString().toLowerCase();
          final idStr = t['id'].toString().toLowerCase();
          return placa.contains(q) || modelo.contains(q) || client.contains(q) || worker.contains(q) || idStr.contains(q);
        }).toList();
      }

      double total = 0.0;
      for (var t in _filteredTickets) {
        total += (t['total_amount'] as num?)?.toDouble() ?? 0.0;
      }
      _totalSales = total;
      _totalCars = _filteredTickets.length;
    });
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      var query = _supabase
          .from('cw_tickets')
          .select()
          .eq('status', 'delivered')
          .eq('payment_status', 'paid');
          
      // Filtros de fecha
      final now = DateTime.now();
      if (_timeFilter == 'day') {
        final startOfDay = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
        query = query.gte('created_at', startOfDay);
      } else if (_timeFilter == 'week') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startOfWeekMidnight = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day).toUtc().toIso8601String();
        query = query.gte('created_at', startOfWeekMidnight);
      } else if (_timeFilter == 'month') {
        final startOfMonth = DateTime(now.year, now.month, 1).toUtc().toIso8601String();
        query = query.gte('created_at', startOfMonth);
      }
      
      if (_workerFilter != 'all') {
        query = query.eq('worker_assigned_id', _workerFilter);
      }
          
      final response = await query.order('created_at', ascending: false);
          
      final tickets = List<Map<String, dynamic>>.from(response);
      for (var t in tickets) {
        String lavador = t['worker_name'] ?? 'N/A';
        if (t['worker_assigned_id'] != null) {
          try { lavador = _workers.firstWhere((w) => w['id'] == t['worker_assigned_id'])['name']; } catch (_) {}
        }
        t['worker_name_ui'] = lavador;
      }

      if (mounted) {
        _tickets = tickets;
        _applyFilter();
        setState(() {
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

  void _downloadCsv() {
    if (_tickets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay datos para exportar')));
      return;
    }

    final StringBuffer csv = StringBuffer();
    // Headers
    csv.writeln('ID,Fecha,Placa,Modelo,Lavador,Total');

    for (var t in _filteredTickets) {
      final date = DateTime.parse(t['created_at']).toLocal().toString().split('.').first;
      final placa = t['vehicle_plate'] ?? 'S/N';
      final modelo = t['vehicle_model'] ?? '';
      String lavador = t['worker_name_ui'] ?? 'Sin asignar';
      final total = t['total_amount']?.toString() ?? '0.0';
      
      csv.writeln('${t['id']},$date,$placa,$modelo,$lavador,$total');
    }

    if (kIsWeb) {
      final bytes = utf8.encode(csv.toString());
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'reporte_ventas_autolavado.csv')
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  Future<void> _downloadPdf() async {
    if (_tickets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay datos para exportar')));
      return;
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Reporte de Ventas - Car Wash', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text('Filtro: ${_timeFilter == 'day' ? 'Hoy' : (_timeFilter == 'week' ? 'Esta Semana' : (_timeFilter == 'month' ? 'Este Mes' : 'Histórico'))}', style: const pw.TextStyle(fontSize: 16)),
              pw.Text('Autos Lavados: $_totalCars', style: const pw.TextStyle(fontSize: 16)),
              pw.Text('Ingresos Totales: \$${_totalSales.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['Fecha', 'Placa', 'Modelo', 'Lavador', 'Total'],
                data: _filteredTickets.map((t) {
                  final date = DateTime.parse(t['created_at']).toLocal().toString().split('.').first;
                  String lavador = t['worker_name_ui'] ?? 'N/A';
                  return [date, t['vehicle_plate'] ?? 'S/N', t['vehicle_model'] ?? '', lavador, '\$${t['total_amount']}'];
                }).toList(),
              ),
            ]
          );
        }
      )
    );

    if (kIsWeb) {
      final bytes = await pdf.save();
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'reporte_ventas_autolavado.pdf')
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Dashboard de Ventas', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: isMobile ? null : [
          if (_workers.isNotEmpty)
            _buildDropdownFilter(
              value: _workerFilter,
              iconData: Icons.person,
              items: [
                const DropdownMenuItem(value: 'all', child: Text('Todos los lavadores')),
                ..._workers.map((w) => DropdownMenuItem(value: w['id'].toString(), child: Text(w['name']))),
              ],
              onChanged: (val) {
                setState(() => _workerFilter = val!);
                _fetchReports();
              },
            ),
          _buildDropdownFilter(
            value: _timeFilter,
            iconData: Icons.calendar_month,
            items: const [
              DropdownMenuItem(value: 'day', child: Text('Hoy')),
              DropdownMenuItem(value: 'week', child: Text('Esta Semana')),
              DropdownMenuItem(value: 'month', child: Text('Este Mes')),
              DropdownMenuItem(value: 'all', child: Text('Histórico')),
            ],
            onChanged: (val) {
              setState(() => _timeFilter = val!);
              _fetchReports();
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 12 : 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isMobile) ...[
                    // Mobile Filters
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                         _buildDropdownFilter(
                          value: _timeFilter,
                          iconData: Icons.calendar_month,
                          items: const [
                            DropdownMenuItem(value: 'day', child: Text('Hoy')),
                            DropdownMenuItem(value: 'week', child: Text('Esta Sem.')),
                            DropdownMenuItem(value: 'month', child: Text('Este Mes')),
                            DropdownMenuItem(value: 'all', child: Text('Hist.')),
                          ],
                          onChanged: (val) {
                            setState(() => _timeFilter = val!);
                            _fetchReports();
                          },
                        ),
                        if (_workers.isNotEmpty)
                          _buildDropdownFilter(
                            value: _workerFilter,
                            iconData: Icons.person,
                            items: [
                              const DropdownMenuItem(value: 'all', child: Text('Todos')),
                              ..._workers.map((w) => DropdownMenuItem(value: w['id'].toString(), child: Text(w['name']))),
                            ],
                            onChanged: (val) {
                              setState(() => _workerFilter = val!);
                              _fetchReports();
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Stats Section
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildStatCard(
                        title: 'Ingresos',
                        value: '\$${_totalSales.toStringAsFixed(2)}',
                        icon: Icons.monetization_on,
                        color: Colors.greenAccent,
                        width: isMobile ? (width - 40) / 2 : 300,
                      ),
                      _buildStatCard(
                        title: 'Autos',
                        value: '$_totalCars',
                        icon: Icons.local_car_wash,
                        color: Colors.blueAccent,
                        width: isMobile ? (width - 40) / 2 : 200,
                      ),
                      // Export Buttons
                      SizedBox(
                        width: isMobile ? double.infinity : 150,
                        child: ElevatedButton.icon(
                          onPressed: _downloadCsv,
                          icon: const Icon(Icons.description),
                          label: const Text('Excel', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: isMobile ? double.infinity : 150,
                        child: ElevatedButton.icon(
                          onPressed: _downloadPdf,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Search and Details
                  Flex(
                    direction: isMobile ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Detalle de Ventas', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                      if (isMobile) const SizedBox(height: 12),
                      SizedBox(
                        width: isMobile ? double.infinity : 400,
                        child: TextField(
                          onChanged: (val) {
                            _searchQuery = val;
                            _applyFilter();
                          },
                          decoration: InputDecoration(
                            hintText: 'Buscar...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 500, // Fixed height for the list within scrollview
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _filteredTickets.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
                        itemBuilder: (context, index) {
                          final t = _filteredTickets[index];
                          final date = DateTime.parse(t['created_at']).toLocal();
                          final dateStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                          
                          return ListTile(
                            contentPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 8),
                            leading: isMobile ? null : Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle),
                              child: const Icon(Icons.check_circle_outline, color: Color(0xFF1E3A8A)),
                            ),
                            title: Text('${t['vehicle_plate']} - ${t['vehicle_model']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 15 : 17)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${t['worker_name_ui'] ?? 'N/A'} • $dateStr', style: const TextStyle(fontSize: 12)),
                                if (isMobile && t['requires_invoice'] == true)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.orange)),
                                    child: const Text('FACTURA', style: TextStyle(color: Colors.orange, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isMobile && t['requires_invoice'] == true)
                                  Container(
                                    margin: const EdgeInsets.only(right: 12),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.orange)),
                                    child: const Text('FACTURA', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('\$${t['total_amount']}', style: TextStyle(fontSize: isMobile ? 16 : 19, fontWeight: FontWeight.w900, color: Colors.greenAccent)),
                                    Text('PAGADO', style: TextStyle(fontSize: isMobile ? 8 : 10, fontWeight: FontWeight.bold, color: Colors.green)),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.receipt_long, color: Colors.indigo, size: 20),
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => BillingView(ticket: t)));
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDropdownFilter({required String value, required IconData iconData, required List<DropdownMenuItem<String>> items, required void Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: const Color(0xFF1E3A8A),
          icon: Icon(iconData, color: Colors.white),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color, double? width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E3A8A))),
              ],
            ),
          )
        ],
      ),
    );
  }
}

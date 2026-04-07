import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QueueView extends StatefulWidget {
  const QueueView({super.key});

  @override
  State<QueueView> createState() => _QueueViewState();
}

class _QueueViewState extends State<QueueView> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _workers = [];
  
  // Fallback Polling
  Timer? _pollingTimer;
  List<Map<String, dynamic>>? _latestTickets;
  bool _usePolling = false;

  @override
  void initState() {
    super.initState();
    print('QueueView initState: loading workers...');
    _loadWorkers();
    _setupStream();
  }

  void _setupStream() {
    // We'll use a listener to detect failures and switch to polling
    _supabase
        .from('cw_tickets')
        .stream(primaryKey: ['id'])
        .inFilter('status', ['queue', 'washing'])
        .listen(
          (data) {
            if (mounted) {
              setState(() {
                _latestTickets = data;
                _usePolling = false;
              });
            }
          },
          onError: (err) {
            print('Stream error, switching to polling: $err');
            if (mounted) {
              setState(() {
                _usePolling = true;
              });
              _startPolling();
            }
          },
        );
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _fetchTickets(); // Initial fetch
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchTickets());
  }

  Future<void> _fetchTickets() async {
    try {
      final res = await _supabase
          .from('cw_tickets')
          .select()
          .filter('status', 'in', '("queue","washing")')
          .order('created_at', ascending: true);
      
      if (mounted) {
        setState(() {
          _latestTickets = List<Map<String, dynamic>>.from(res);
        });
      }
    } catch (e) {
      print('Polling error: $e');
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadWorkers() async {
    try {
      final res = await _supabase.from('cw_workers').select().eq('role', 'washer');
      if (mounted) {
        setState(() {
          _workers = List<Map<String, dynamic>>.from(res);
          print('QueueView: Loaded ${_workers.length} workers');
        });
      }
    } catch (e) {
      print('QueueView error loading workers: $e');
    }
  }

  Future<void> _assignWorkerAndStart(String ticketId) async {
    await _loadWorkers();
    
    if (_workers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay lavadores disponibles. Registre uno primero.')),
        );
      }
      return;
    }

    String? selectedWorkerId;
    if (!mounted) return;
    
    bool? assigned = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Asignar Lavador'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _workers.length,
                  itemBuilder: (context, index) {
                    final w = _workers[index];
                    return RadioListTile<String>(
                      title: Text(w['name']),
                      value: w['id'],
                      groupValue: selectedWorkerId,
                      onChanged: (val) {
                        setStateDialog(() => selectedWorkerId = val);
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('CANCELAR'),
                ),
                ElevatedButton(
                  onPressed: selectedWorkerId == null
                      ? null
                      : () => Navigator.pop(context, true),
                  child: const Text('ASIGNAR Y EMPEZAR'),
                ),
              ],
            );
          },
        );
      },
    );

    if (assigned == true && selectedWorkerId != null) {
      try {
        await _supabase.from('cw_tickets').update({
          'status': 'washing',
          'worker_assigned_id': selectedWorkerId,
        }).eq('id', ticketId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    try {
      await _supabase.from('cw_tickets').update({'status': newStatus}).eq('id', id);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Cola de Autos', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      body: _usePolling 
        ? _buildTicketsList(_latestTickets)
        : StreamBuilder<List<Map<String, dynamic>>>(
            stream: _supabase
                .from('cw_tickets')
                .stream(primaryKey: ['id'])
                .inFilter('status', ['queue', 'washing'])
                .order('created_at', ascending: true),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                // If stream fails, we switch flag to use polling instead
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_usePolling) {
                    setState(() => _usePolling = true);
                    _startPolling();
                  }
                });
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData && _latestTickets == null) return const Center(child: CircularProgressIndicator());
              final tickets = snapshot.data ?? _latestTickets ?? [];
              return _buildTicketsList(tickets);
            },
          ),
    );
  }

  Widget _buildTicketsList(List<Map<String, dynamic>>? tickets) {
    if (tickets == null) return const Center(child: CircularProgressIndicator());
    if (tickets.isEmpty) {
      return const Center(child: Text('No hay autos en cola', style: TextStyle(fontSize: 18, color: Colors.black45)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(32),
      itemCount: tickets.length,
      itemBuilder: (context, index) {
        final t = tickets[index];
        final isWashing = t['status'] == 'washing';
        
        Color statusColor = isWashing ? Colors.blue : Colors.orange;
        String statusLabel = isWashing ? 'Lavando' : 'En Cola';

        final createdAt = DateTime.parse(t['created_at']).toLocal();
        final timeStr = '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
        final dateStr = '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}';
        final entryDateTime = '$dateStr - $timeStr';

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
                      Text(t['vehicle_plate'] ?? 'S/N', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, size: 14, color: Colors.blueGrey),
                                const SizedBox(width: 4),
                                Text(entryDateTime, style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _ElapsedTimeDisplay(startTime: t['created_at']),
                          if (t['worker_assigned_id'] != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                children: [
                                  const Icon(Icons.person, size: 14, color: Colors.purple),
                                  const SizedBox(width: 4),
                                  Text(
                                    _workers.isEmpty ? '...' : _workers.firstWhere((w) => w['id'] == t['worker_assigned_id'], orElse: () => {'name': 'Cargando...'})['name'],
                                    style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                if (t['status'] == 'queue')
                  ElevatedButton.icon(
                    onPressed: () => _assignWorkerAndStart(t['id']),
                    icon: const Icon(Icons.water_drop),
                    label: const Text('EMPEZAR LAVADO'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                else if (t['status'] == 'washing')
                  ElevatedButton.icon(
                    onPressed: () => _updateStatus(t['id'], 'ready'),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('MARCAR COMO LISTO'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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

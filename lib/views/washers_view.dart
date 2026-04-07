import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WashersView extends StatefulWidget {
  const WashersView({super.key});

  @override
  State<WashersView> createState() => _WashersViewState();
}

class _WashersViewState extends State<WashersView> {
  final _supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;

  Future<void> _addWorker() async {
    final name = _nameController.text.trim();
    final pin = _pinController.text.trim();
    if (name.isEmpty || pin.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _supabase.from('cw_workers').insert({'name': name, 'role': 'washer', 'pin': pin});
      _nameController.clear();
      _pinController.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lavador agregado con éxito'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteWorker(String id) async {
    try {
      await _supabase.from('cw_workers').delete().eq('id', id);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al borrar: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF1F5F9),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gestión de Lavadores',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A))),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                          labelText: 'Nombre del Lavador',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'PIN de Acceso',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _addWorker,
                    icon: const Icon(Icons.add),
                    label: const Text('AGREGAR',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('Lista de Personal Activo',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54)),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _supabase
                    .from('cw_workers')
                    .stream(primaryKey: ['id'])
                    .eq('role', 'washer')
                    .order('created_at', ascending: true),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final workers = snapshot.data!;
                  if (workers.isEmpty) {
                    return const Center(child: Text('No hay lavadores registrados.'));
                  }

                  return GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: workers.length,
                    itemBuilder: (context, index) {
                      final w = workers[index];
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Colors.black12)),
                        child: ListTile(
                          leading: const CircleAvatar(
                              backgroundColor: Color(0xFFE53935),
                              child: Icon(Icons.person, color: Colors.white)),
                          title: Text(w['name'],
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('PIN: ${w['pin'] ?? '####'}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent),
                            onPressed: () => _deleteWorker(w['id']),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

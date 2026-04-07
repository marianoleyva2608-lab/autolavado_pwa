import 'package:flutter/material.dart';
import 'reception_view.dart';
import 'queue_view.dart';
import 'admin_view.dart';
import 'store_view.dart';

class RoleSelectionView extends StatelessWidget {
  const RoleSelectionView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logo.png',
                height: 200,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.local_car_wash,
                  size: 150,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Station Car Wash',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFE53935), // Station Red
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Selecciona tu área de trabajo',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 48),
              _buildRoleCard(
                context: context,
                title: 'Recepción',
                subtitle: 'Registrar placas y solicitar lavado',
                icon: Icons.edit_document,
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ReceptionView()),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildRoleCard(
                context: context,
                title: 'Cola de autos',
                subtitle: 'Marcado de listos y entregas',
                icon: Icons.water_drop,
                color: Colors.blueAccent,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const QueueView()),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildRoleCard(
                context: context,
                title: 'Caja / Control',
                subtitle: 'Cobro, Facturación, Nómina y Reportes',
                icon: Icons.point_of_sale,
                color: Colors.indigo,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminView()),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildRoleCard(
                context: context,
                title: 'Tienda / Snacks',
                subtitle: 'Venta de refrescos, papas y botana',
                icon: Icons.storefront,
                color: Colors.orangeAccent,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const StoreView()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    const Color stationBlue = Color(0xFF1E3A8A);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: stationBlue.withOpacity(0.08), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: stationBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey.shade300, size: 14),
          ],
        ),
      ),
    );
  }
}

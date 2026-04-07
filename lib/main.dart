import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'views/role_selection_view.dart';
import 'views/reports_view.dart';
import 'views/washers_view.dart';
import 'views/queue_view.dart';
import 'views/reception_view.dart';
import 'views/admin_view.dart';
import 'views/catalog_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://thiwskglmdfoaysfbqld.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoaXdza2dsbWRmb2F5c2ZicWxkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQzMjg4NDcsImV4cCI6MjA4OTkwNDg0N30.jpNW91mD63JwYsFJYoHILddg7wMIv1irOmLeQqncmmM',
  );

  runApp(const CarWashApp());
}

class CarWashApp extends StatelessWidget {
  const CarWashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Autolavado PWA',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A), // Station Dark Blue
          primary: const Color(0xFFE53935),   // Station Red 
          secondary: const Color(0xFF00B0FF), // Bubble Cyan
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF0F4F8), // Light water grey/blue
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E3A8A), // Dark blue header
          elevation: 0,
          foregroundColor: Colors.white,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const RoleSelectionView(),
        '/ventas': (context) => const ReportsView(),
        '/lavadores': (context) => const WashersView(),
        '/cola': (context) => const QueueView(),
        '/recepcion': (context) => const ReceptionView(),
        '/admin': (context) => const AdminView(),
        '/catalogo': (context) => const CatalogView(),
      },
    );
  }
}

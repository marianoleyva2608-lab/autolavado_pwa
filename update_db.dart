import 'package:postgres/postgres.dart';

void main() async {
  final connection = await Connection.open(
    Endpoint(
      host: 'db.jcaqolmacqhhgtjdgvaz.supabase.co', // Restaurant DB
      database: 'postgres',
      username: 'postgres',
      password: 'M@ri27260881',
      port: 5432,
    ),
    settings: ConnectionSettings(sslMode: SslMode.require),
  );
  
  try {
    await connection.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS branch_name TEXT DEFAULT 'Matriz'");
    // Also notify pgrst to reload schema
    await connection.execute("NOTIFY pgrst, 'reload schema'");
    print('Added branch_name to orders array and reloaded schema.');
  } catch (e) {
    print('Error: $e');
  } finally {
    await connection.close();
  }
}

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
    print('Applying branches migration to Restaurant DB...');
    await connection.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS branch_name TEXT DEFAULT 'Sucursal 1'");
    await connection.execute("ALTER TABLE restaurant_tables ADD COLUMN IF NOT EXISTS branch_name TEXT DEFAULT 'Sucursal 1'");
    await connection.execute("ALTER TABLE waiters ADD COLUMN IF NOT EXISTS branch_name TEXT DEFAULT 'Sucursal 1'");
    await connection.execute("ALTER TABLE dishes ADD COLUMN IF NOT EXISTS branch_name TEXT DEFAULT 'Sucursal 1'");
    
    // Notify pgrst to reload schema so the REST API picks it up immediately
    await connection.execute("NOTIFY pgrst, 'reload schema'");
    print('Migration complete!');
  } catch (e) {
    print('Error: $e');
  } finally {
    await connection.close();
  }
}

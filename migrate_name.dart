import 'package:postgres/postgres.dart';

void main() async {
  final connection = await Connection.open(
    Endpoint(
      host: 'db.thiwskglmdfoaysfbqld.supabase.co',
      database: 'postgres',
      username: 'postgres',
      password: 'M@ri27260881',
      port: 5432,
    ),
    settings: ConnectionSettings(sslMode: SslMode.require),
  );
  
  try {
    await connection.execute("ALTER TABLE cw_tickets ADD COLUMN IF NOT EXISTS worker_name TEXT");
    print('Added worker_name to cw_tickets');
  } catch (e) {
    print('Error: $e');
  } finally {
    await connection.close();
  }
}

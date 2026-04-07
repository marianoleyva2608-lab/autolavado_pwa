import 'package:postgres/postgres.dart';

void main() async {
  print('Connecting to Supabase Postgres...');
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
    print('Applying migration...');
    await connection.execute("ALTER TABLE cw_workers ADD COLUMN IF NOT EXISTS pin TEXT DEFAULT '1234'");
    print('Migration successful!');
  } catch (e) {
    print('Error: $e');
  } finally {
    await connection.close();
  }
}

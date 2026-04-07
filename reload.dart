import 'package:postgres/postgres.dart';

void main() async {
  await connectionBlock();
}

Future<Connection> connectionBlock() async {
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
    await connection.execute("NOTIFY pgrst, 'reload schema'");
    print('Schema reloaded!');
  } finally {
    await connection.close();
  }
  return connection;
}

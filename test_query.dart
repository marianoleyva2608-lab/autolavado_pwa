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
    final res = await connection.execute(
      "SELECT id, status, is_paid, total_amount FROM cw_tickets",
    );
    print('${res.length} tickets found.');
    for (final row in res) {
      print(row);
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    await connection.close();
  }
}

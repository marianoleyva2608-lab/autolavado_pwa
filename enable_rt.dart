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
    print('Enabling realtime...');
    await connection.execute("ALTER PUBLICATION supabase_realtime ADD TABLE cw_tickets, cw_workers, cw_ticket_items, cw_services");
    print('Realtime enabled for all cw_ tables!');
  } catch (e) {
    if (e.toString().contains('already exists') || e.toString().contains('already in publication')) {
      print('Tables may already be in publication, trying individually.');
    } else {
      print('Error: $e');
    }
  } finally {
    await connection.close();
  }
}

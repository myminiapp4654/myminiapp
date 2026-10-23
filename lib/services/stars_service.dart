import '../net/server_client.dart';

/// Foydalanuvchining yulduzlari (serverdagi profil).
class StarsService {
  final _s = ServerClient.instance;

  Stream<int> starsStream() => _s
      .watch('me')
      .map((d) => (d.data()?['stars'] as int?) ?? 0);
}

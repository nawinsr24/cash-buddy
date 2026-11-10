import '../data/repo.dart';
import 'vault.dart';

/// Browsers have no app documents folder; the data already lives in IndexedDB.
Future<String?> createBackup(Repo repo, {Vault? vault}) async => null;

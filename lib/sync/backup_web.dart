import '../data/repo.dart';

/// Browsers have no app documents folder; the data already lives in IndexedDB.
Future<String?> createBackup(Repo repo) async => null;

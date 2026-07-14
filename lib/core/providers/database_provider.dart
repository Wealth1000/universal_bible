import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_bible/database/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());
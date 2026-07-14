import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_bible/core/services/storage_service.dart';
import 'app.dart';
//import 'database/app_database.dart';
//import 'services/sync_service.dart';
//import 'services/supabase/bible_repository.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_PUBLISHABLE_KEY']!,
  );
  await StorageService().init();
  //final db = AppDatabase();
  //final supabaseClient = Supabase.instance.client;
  //final remoteRepo = SupabaseBibleRepository(supabaseClient);
  //final syncService = SyncService(local: db, remote: remoteRepo);
  runApp(
    const ProviderScope(
      child: MyApp(),
    )
  );
}
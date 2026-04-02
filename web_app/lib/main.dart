import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.supabaseConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  runApp(const ProfSummaryApp());
}

class ProfSummaryApp extends StatelessWidget {
  const ProfSummaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HKU Professor Summary',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006938),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: AppConfig.supabaseConfigured
          ? const HomeScreen()
          : const _MissingConfigScreen(),
    );
  }
}

class _MissingConfigScreen extends StatelessWidget {
  const _MissingConfigScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuration')),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: SelectableText(
          'Set Supabase credentials when running or building for web:\n\n'
          'flutter run -d chrome '
          '--dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co '
          '--dart-define=SUPABASE_ANON_KEY=your_anon_key\n\n'
          'Use the anon key (not the service role). Ensure the professors '
          'table has a SELECT policy for anon, as in supabase/migrations.',
        ),
      ),
    );
  }
}

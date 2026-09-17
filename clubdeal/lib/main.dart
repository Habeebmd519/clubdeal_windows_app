import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'firebase_options.dart';
import 'core/repositories/restaurant_repository.dart';
import 'core/bloc/order_bloc.dart';
import 'core/bloc/menu_bloc.dart';
import 'core/bloc/settings_bloc.dart';
import 'core/bloc/app_bloc.dart';
import 'core/services/alert_sound_service.dart';
import 'core/services/printer_service.dart';
import 'features/app/desktop_shell.dart';
import 'features/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final repository = RestaurantRepository();

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: repository),
        RepositoryProvider(create: (_) => AlertSoundService()),
        RepositoryProvider(create: (_) => PrinterService()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => AppBloc()),
          BlocProvider(
            create: (_) => OrderBloc(repository)..add(const OrdersStarted()),
          ),
          BlocProvider(
            create: (_) => MenuBloc(repository)..add(const MenuStarted()),
          ),
          BlocProvider(
            create: (context) => SettingsBloc(
              context.read<AlertSoundService>(),
            )..add(const SettingsStarted()),
          ),
        ],
        child: const ClubDealDesktopApp(),
      ),
    ),
  );
}

class ClubDealDesktopApp extends StatelessWidget {
  const ClubDealDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Club Deal Desktop',
      theme: AppTheme.dark(),
      home: const DesktopShell(),
    );
  }
}

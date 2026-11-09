import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

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

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print('🔥 Firebase project: ${Firebase.app().options.projectId}');
  print('🔥 Firebase app ID: ${Firebase.app().options.appId}');

  final test = await FirebaseFirestore.instance.collection('orders').get();

  print('🔥 DIRECT FIRESTORE TEST');
  print('🔥 Orders found: ${test.docs.length}');

  for (final doc in test.docs) {
    print('🔥 ${doc.id}');
    print('🔥 ${doc.data()}');
  }
  final ordersTest = await FirebaseFirestore.instance
      .collection('orders')
      .get(const GetOptions(source: Source.server));

  print('🔥 SERVER FIRESTORE TEST');
  print('🔥 Project: ${Firebase.app().options.projectId}');
  print('🔥 Orders from SERVER: ${ordersTest.docs.length}');

  for (final doc in ordersTest.docs) {
    print('🔥 SERVER ORDER: ${doc.id}');
    print('🔥 DATA: ${doc.data()}');
  }
  final menuTest = await FirebaseFirestore.instance
      .collection('menu2')
      .get(const GetOptions(source: Source.server));

  print('🔥 SERVER MENU2 TEST');
  print('🔥 Menu2 documents: ${menuTest.docs.length}');

  for (final doc in menuTest.docs) {
    print('🔥 MENU2: ${doc.id}');
    print('🔥 DATA: ${doc.data()}');
  }
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
            create: (context) =>
                SettingsBloc(context.read<AlertSoundService>())
                  ..add(const SettingsStarted()),
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

# Documentacao para projetos em Flutter

## Estilo de codigo

```
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  // Configura todas as dependências do projeto usando o GetIt.
  dependencyInjector();

  // Inicializa dependências assíncronas, como a leitura de configurações salvas, tokens ou temas.
  await initDependencies();

  // Cria as rotas.
  final Routes appRoutes = Routes();

  runApp(
    MyApp(
      appRoutes: appRoutes,
      settingController: locator<SettingController>(),
    ),
  );
}

class MyApp extends StatelessWidget {
  final Routes appRoutes;
  final SettingController settingController;

  const MyApp({
    super.key,
    required this.appRoutes,
    required this.settingController,
  });

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SettingModel>(
      valueListenable: settingController,
      builder: (context, settingModel, child) {
        return MaterialApp(
          title: 'Counter Example',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(useMaterial3: true),
          darkTheme: ThemeData.dark(useMaterial3: true),
          themeMode: settingModel.isDarkTheme
              ? ThemeMode.dark
              : ThemeMode.light,
          routes: appRoutes.routes,
          initialRoute: Routes.home,
        );
      },
    );
  }
}

final locator = GetIt.instance;

void dependencyInjector() {
  _startStorageService();
  _startFeatureCounter();
  _startFeatureSetting();
}

void _startStorageService() {
  locator.registerLazySingleton<StorageService>(() => StorageServiceImpl());
}

void _startFeatureCounter() {
  locator.registerCachedFactory<CounterController>(
    () => CounterControllerImpl(),
  );
}

void _startFeatureSetting() {
  locator.registerCachedFactory<SettingRepository>(
    () => SettingRepositoryImpl(storageService: locator<StorageService>()),
  );
  locator.registerLazySingleton<SettingController>(
    () =>
        SettingControllerImpl(settingRepository: locator<SettingRepository>()),
  );
}

Future<void> initDependencies() async {
  await locator<StorageService>().initStorage();
  await Future.wait([locator<SettingController>().readTheme()]);
}

// A camada de services deve ser utilizada somente para encapsular bibliotecas externas.
abstract interface class StorageService {
  Future<void> initStorage();

  Future<bool> getBoolValue({required String key});
  Future<void> setBoolValue({required String key, required bool value});
}

class StorageServiceImpl implements StorageService {
  late final SharedPreferences _storage;

  @override
  Future<void> initStorage() async {
    try {
      _storage = await SharedPreferences.getInstance();
    } catch (error) {
      throw Exception(error);
    }
  }

  @override
  Future<bool> getBoolValue({required String key}) async {
    try {
      return _storage.getBool(key) ?? false;
    } catch (error) {
      throw Exception('StorageService: $error');
    }
  }

  @override
  Future<void> setBoolValue({required String key, required bool value}) async {
    try {
      await _storage.setBool(key, value);
    } catch (error) {
      throw Exception('StorageService: $error');
    }
  }
}

class Constants {
  static const String darkMode = 'DarkMode';
}

class Routes {
  static String get home => CounterRoutes.counter;

  final routes = <String, WidgetBuilder>{
    ...CounterRoutes().routes,
    ...SettingRoutes().routes,
  };
}

class CounterModel {
  final int count;

  CounterModel({this.count = 0});
}

// é obrigatorio o uso de interfaces nos repositories e controllers.
abstract interface class CounterController extends ValueNotifier<CounterModel> {
  CounterController(super.initialState);

  void increment();
  void decrement();
}

class CounterControllerImpl extends ValueNotifier<CounterModel>
    implements CounterController {
  CounterControllerImpl() : super(CounterModel());

  @override
  void increment() {
    final model = CounterModel(count: value.count + 1);
    _emit(model);
  }

  @override
  void decrement() {
    final model = CounterModel(count: value.count - 1);
    _emit(model);
  }

  // O uso da função interna "_emit()" é obrigatorio.
  void _emit(CounterModel newValue) {
    value = newValue;
    debugPrint('CounterController: ${value.count}');
  }
}

class CounterView extends StatelessWidget {
  final CounterController counterController;

  const CounterView({super.key, required this.counterController});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Counter'),
        actions: [
          IconButton(
            key: const Key('settings_navigation'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).pushNamed(SettingRoutes.setting);
            },
          ),
        ],
      ),
      body: Center(
        child: ValueListenableBuilder<CounterModel>(
          valueListenable: counterController,
          builder: (context, counterModel, child) {
            return Text(
              'Count: ${counterModel.count}',
              style: Theme.of(context).textTheme.headlineMedium,
            );
          },
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            key: const Key('increment_function'),
            child: const Icon(Icons.add),
            onPressed: () {
              counterController.increment();
            },
          ),
          const SizedBox(height: 8.0),
          FloatingActionButton(
            key: const Key('decrement_function'),
            child: const Icon(Icons.remove),
            onPressed: () {
              counterController.decrement();
            },
          ),
        ],
      ),
    );
  }
}

class CounterRoutes {
  static String get counter => '/counter';

  final routes = <String, WidgetBuilder>{
    counter: (BuildContext context) {
      // a view deve sempre receber a instancia do controller pelas rotas.
      return CounterView(counterController: locator<CounterController>());
    },
  };
}

class SettingModel {
  final bool isDarkTheme;

  SettingModel({this.isDarkTheme = false});
}

abstract interface class SettingRepository {
  Future<SettingModel> readTheme();
  Future<void> updateTheme({required bool isDarkTheme});
}

class SettingRepositoryImpl implements SettingRepository {
  final StorageService storageService;

  SettingRepositoryImpl({required this.storageService});

  @override
  Future<SettingModel> readTheme() async {
    try {
      final isDarkMode = await storageService.getBoolValue(
        key: Constants.darkMode,
      );
      return SettingModel(isDarkTheme: isDarkMode);
    } catch (error) {
      throw Exception('SettingRepository: $error');
    }
  }

  @override
  Future<void> updateTheme({required bool isDarkTheme}) async {
    try {
      await storageService.setBoolValue(
        key: Constants.darkMode,
        value: isDarkTheme,
      );
    } catch (error) {
      throw Exception('SettingRepository: $error');
    }
  }
}

abstract interface class SettingController extends ValueNotifier<SettingModel> {
  SettingController(super.initialState);

  Future<void> readTheme();
  Future<void> updateTheme({required bool isDarkTheme});
}

class SettingControllerImpl extends ValueNotifier<SettingModel>
    implements SettingController {
  final SettingRepository settingRepository;

  SettingControllerImpl({required this.settingRepository})
    : super(SettingModel());

  @override
  Future<void> readTheme() async {
    final settingModel = await settingRepository.readTheme();
    final model = SettingModel(isDarkTheme: settingModel.isDarkTheme);
    _emit(model);
  }

  @override
  Future<void> updateTheme({required bool isDarkTheme}) async {
    await settingRepository.updateTheme(isDarkTheme: isDarkTheme);
    final model = SettingModel(isDarkTheme: isDarkTheme);
    _emit(model);
  }

  // O uso da função interna "_emit()" é obrigatorio.
  void _emit(SettingModel newValue) {
    value = newValue;
    debugPrint('SettingController: ${value.isDarkTheme}');
  }
}

class SettingView extends StatelessWidget {
  final SettingController settingController;

  const SettingView({super.key, required this.settingController});

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationIcon: const FlutterLogo(),
      applicationName: 'Counter Example',
      applicationVersion: 'Version 1.0.0',
      applicationLegalese: '\u{a9} 2026 Eduardo Rosa',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: false, title: const Text('Settings')),
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Dark theme'),
            trailing: ValueListenableBuilder<SettingModel>(
              valueListenable: settingController,
              builder: (context, settingModel, child) {
                return Switch(
                  value: settingModel.isDarkTheme,
                  onChanged: (bool isDarkTheme) {
                    settingController.updateTheme(isDarkTheme: isDarkTheme);
                  },
                );
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () {
              _showAboutDialog(context);
            },
          ),
        ],
      ),
    );
  }
}

class SettingRoutes {
  static String get setting => '/settings';

  final routes = <String, WidgetBuilder>{
    setting: (BuildContext context) {
      // a view deve sempre receber a instancia do controller pelas rotas.
      return SettingView(settingController: locator<SettingController>());
    },
  };
}
```

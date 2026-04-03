import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  // Ensure that widget binding is initialized before using SharedPreferences
  WidgetsFlutterBinding.ensureInitialized();

  // Configures all project dependencies using GetIt (IoC container).
  dependencyInjector();

  // Initializes async dependencies, like storage and settings
  await initDependencies();

  final Routes appRoutes = Routes();

  runApp(
    MyApp(
      appRoutes: appRoutes,
      settingController: locator<SettingController>(),
    ),
  );
}

final locator = GetIt.instance;

void dependencyInjector() {
  _startStorageService();
  _startFeatureSetting();
  _startFeatureTransaction();
}

void _startStorageService() {
  locator.registerLazySingleton<StorageService>(() => StorageServiceImpl());
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

void _startFeatureTransaction() {
  locator.registerCachedFactory<TransactionRepository>(
    () => TransactionRepositoryImpl(storageService: locator<StorageService>()),
  );
  // TransactionController is a LazySingleton to keep its state active throughout the app lifecycle
  locator.registerLazySingleton<TransactionController>(
    () => TransactionControllerImpl(
      transactionRepository: locator<TransactionRepository>(),
    ),
  );
}

Future<void> initDependencies() async {
  await locator<StorageService>().initStorage();
  await Future.wait([
    locator<SettingController>().readTheme(),
    locator<TransactionController>().loadTransactions(),
  ]);
}

class MyApp extends StatelessWidget {
  final Routes appRoutes;
  final SettingController settingController;

  const MyApp({
    super.key,
    required this.appRoutes,
    required this.settingController,
  });

  @override
  Widget build(BuildContext context) {
    // Listens to setting changes to reconstruct MaterialApp with the new theme
    return ValueListenableBuilder<SettingModel>(
      valueListenable: settingController,
      builder: (context, settingModel, child) {
        return MaterialApp(
          title: 'App de Controle Financeiro',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(
            useMaterial3: true,
          ).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
          darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: Brightness.dark,
            ),
          ),
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

// -----------------------------------------------------------------------------------------
// COMMON RESOURCES / SERVICES
// -----------------------------------------------------------------------------------------

/// Service layer strictly abstracts external libraries such as shared_preferences
abstract interface class StorageService {
  Future<void> initStorage();
  Future<bool> getBoolValue({required String key});
  Future<void> setBoolValue({required String key, required bool value});
  Future<String?> getStringValue({required String key});
  Future<void> setStringValue({required String key, required String value});
}

class StorageServiceImpl implements StorageService {
  late final SharedPreferences _storage;

  @override
  Future<void> initStorage() async {
    _storage = await SharedPreferences.getInstance();
  }

  @override
  Future<bool> getBoolValue({required String key}) async {
    return _storage.getBool(key) ?? false;
  }

  @override
  Future<void> setBoolValue({required String key, required bool value}) async {
    await _storage.setBool(key, value);
  }

  @override
  Future<String?> getStringValue({required String key}) async {
    return _storage.getString(key);
  }

  @override
  Future<void> setStringValue({
    required String key,
    required String value,
  }) async {
    await _storage.setString(key, value);
  }
}

class Constants {
  static const String darkModeKey = 'DarkMode';
  static const String transactionsKey = 'Transactions';
}

class Routes {
  static String get home => TransactionRoutes.transactions;

  final routes = <String, WidgetBuilder>{
    ...SettingRoutes().routes,
    ...TransactionRoutes().routes,
  };
}

// -----------------------------------------------------------------------------------------
// FEATURE: SETTING
// -----------------------------------------------------------------------------------------

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
    final isDarkMode = await storageService.getBoolValue(
      key: Constants.darkModeKey,
    );
    return SettingModel(isDarkTheme: isDarkMode);
  }

  @override
  Future<void> updateTheme({required bool isDarkTheme}) async {
    await storageService.setBoolValue(
      key: Constants.darkModeKey,
      value: isDarkTheme,
    );
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
    final modelInfo = await settingRepository.readTheme();
    _emit(SettingModel(isDarkTheme: modelInfo.isDarkTheme));
  }

  @override
  Future<void> updateTheme({required bool isDarkTheme}) async {
    await settingRepository.updateTheme(isDarkTheme: isDarkTheme);
    _emit(SettingModel(isDarkTheme: isDarkTheme));
  }

  void _emit(SettingModel newValue) {
    value = newValue;
  }
}

class SettingView extends StatelessWidget {
  final SettingController settingController;
  const SettingView({super.key, required this.settingController});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        children: [
          ValueListenableBuilder<SettingModel>(
            valueListenable: settingController,
            builder: (context, model, child) {
              return SwitchListTile(
                title: const Text('Dark Theme'),
                value: model.isDarkTheme,
                onChanged: (val) =>
                    settingController.updateTheme(isDarkTheme: val),
                secondary: const Icon(Icons.brightness_6),
              );
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
    setting: (ctx) =>
        SettingView(settingController: locator<SettingController>()),
  };
}

// -----------------------------------------------------------------------------------------
// FEATURE: TRANSACTION
// -----------------------------------------------------------------------------------------

enum TransactionType { income, expense }

/// Core Model representing a single transaction
class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String category;
  final TransactionType type;

  TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'type': type.name,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    final mappedCategory = const {
      'Food': 'Alimentação',
      'Transport': 'Transporte',
      'Salary': 'Salário',
      'Leisure': 'Lazer',
      'Other': 'Outros',
    }[map['category']] ?? map['category'];

    return TransactionModel(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      date: DateTime.parse(map['date']),
      category: mappedCategory,
      type: TransactionType.values.byName(map['type']),
    );
  }
}

/// State Model representing the entire list of transactions, filters, and balances
class TransactionStateModel {
  final List<TransactionModel> transactions;
  final String searchQuery;
  final String? filterCategory;

  TransactionStateModel({
    this.transactions = const [],
    this.searchQuery = '',
    this.filterCategory,
  });

  /// Allows creating a new state copy while retaining previous unmodified values
  TransactionStateModel copyWith({
    List<TransactionModel>? transactions,
    String? searchQuery,
    String? filterCategory,
    bool clearFilterCategory = false,
  }) {
    return TransactionStateModel(
      transactions: transactions ?? this.transactions,
      searchQuery: searchQuery ?? this.searchQuery,
      filterCategory: clearFilterCategory
          ? null
          : (filterCategory ?? this.filterCategory),
    );
  }

  List<TransactionModel> get filteredTransactions {
    return transactions.where((t) {
      final matchesSearch = t.title.toLowerCase().contains(
        searchQuery.toLowerCase(),
      );
      final matchesCategory =
          filterCategory == null ||
          filterCategory!.isEmpty ||
          t.category == filterCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  double get totalBalance => totalIncome - totalExpenses;

  double get totalIncome => transactions
      .where((t) => t.type == TransactionType.income)
      .fold(0, (sum, t) => sum + t.amount);

  double get totalExpenses => transactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0, (sum, t) => sum + t.amount);
}

// -- REPOSITORY --

abstract interface class TransactionRepository {
  Future<List<TransactionModel>> getTransactions();
  Future<void> saveTransactions(List<TransactionModel> transactions);
}

class TransactionRepositoryImpl implements TransactionRepository {
  final StorageService storageService;
  TransactionRepositoryImpl({required this.storageService});

  @override
  Future<List<TransactionModel>> getTransactions() async {
    final data = await storageService.getStringValue(
      key: Constants.transactionsKey,
    );
    if (data == null || data.isEmpty) return [];
    try {
      final List decoded = jsonDecode(data);
      return decoded.map((e) => TransactionModel.fromMap(e)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveTransactions(List<TransactionModel> transactions) async {
    final serialized = jsonEncode(transactions.map((t) => t.toMap()).toList());
    await storageService.setStringValue(
      key: Constants.transactionsKey,
      value: serialized,
    );
  }
}

// -- CONTROLLER --

abstract interface class TransactionController
    extends ValueNotifier<TransactionStateModel> {
  TransactionController(super.initialState);

  Future<void> loadTransactions();
  Future<void> addTransaction(TransactionModel transaction);
  Future<void> updateTransaction(TransactionModel transaction);
  Future<void> deleteTransaction(String id);
  void setSearchQuery(String query);
  void setFilterCategory(String? category);
}

class TransactionControllerImpl extends ValueNotifier<TransactionStateModel>
    implements TransactionController {
  final TransactionRepository transactionRepository;

  TransactionControllerImpl({required this.transactionRepository})
    : super(TransactionStateModel());

  @override
  Future<void> loadTransactions() async {
    final data = await transactionRepository.getTransactions();
    // Sort transactions by date descending
    data.sort((a, b) => b.date.compareTo(a.date));
    _emit(value.copyWith(transactions: data));
  }

  @override
  Future<void> addTransaction(TransactionModel transaction) async {
    final newList = List<TransactionModel>.from(value.transactions)
      ..add(transaction);
    newList.sort((a, b) => b.date.compareTo(a.date));
    await transactionRepository.saveTransactions(newList);
    _emit(value.copyWith(transactions: newList));
  }

  @override
  Future<void> updateTransaction(TransactionModel updated) async {
    final newList = value.transactions
        .map((t) => t.id == updated.id ? updated : t)
        .toList();
    newList.sort((a, b) => b.date.compareTo(a.date));
    await transactionRepository.saveTransactions(newList);
    _emit(value.copyWith(transactions: newList));
  }

  @override
  Future<void> deleteTransaction(String id) async {
    final newList = value.transactions.where((t) => t.id != id).toList();
    await transactionRepository.saveTransactions(newList);
    _emit(value.copyWith(transactions: newList));
  }

  @override
  void setSearchQuery(String query) {
    _emit(value.copyWith(searchQuery: query));
  }

  @override
  void setFilterCategory(String? category) {
    _emit(
      value.copyWith(
        filterCategory: category,
        clearFilterCategory: category == null,
      ),
    );
  }

  /// Internal emit function used to update the Controller state
  /// Notifies the ValueListenableBuilder automatically
  void _emit(TransactionStateModel newValue) {
    value = newValue;
    debugPrint(
      'TransactionController: Updated ${value.transactions.length} items',
    );
  }
}

// -- VIEWS --

class TransactionRoutes {
  static String get transactions => '/transactions';
  static String get form => '/transaction_form';

  final routes = <String, WidgetBuilder>{
    transactions: (ctx) =>
        TransactionView(controller: locator<TransactionController>()),
    form: (ctx) =>
        TransactionFormView(controller: locator<TransactionController>()),
  };
}

class TransactionView extends StatelessWidget {
  final TransactionController controller;
  const TransactionView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Finanças'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () =>
                Navigator.of(context).pushNamed(SettingRoutes.setting),
          ),
        ],
      ),
      // Listens to Controller State changes, refreshing UI efficiently
      body: ValueListenableBuilder<TransactionStateModel>(
        valueListenable: controller,
        builder: (context, state, child) {
          return Column(
            children: [
              // Summary Cards
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Receitas',
                        amount: state.totalIncome,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Despesas',
                        amount: state.totalExpenses,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _SummaryCard(
                  title: 'Saldo Total',
                  amount: state.totalBalance,
                  color: state.totalBalance >= 0 ? Colors.teal : Colors.orange,
                  isWide: true,
                ),
              ),
              const SizedBox(height: 16),

              // Filter and Search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Buscar...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                          ),
                        ),
                        onChanged: controller.setSearchQuery,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          hint: const Text('Categoria'),
                          value: state.filterCategory,
                          items:
                              [
                                    'Alimentação',
                                    'Transporte',
                                    'Salário',
                                    'Lazer',
                                    'Outros',
                                  ]
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                          onChanged: controller.setFilterCategory,
                        ),
                      ),
                    ),
                    if (state.filterCategory != null)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.red),
                        onPressed: () => controller.setFilterCategory(null),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Transaction List
              Expanded(
                child: state.filteredTransactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Nenhuma transação encontrada.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: state.filteredTransactions.length,
                        itemBuilder: (context, index) {
                          final tx = state.filteredTransactions[index];
                          final isIncome = tx.type == TransactionType.income;

                          return Dismissible(
                            key: Key(tx.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              color: Colors.red,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            onDismissed: (_) {
                              controller.deleteTransaction(tx.id);
                            },
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 1,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isIncome
                                      ? Colors.green.withAlpha(50)
                                      : Colors.red.withAlpha(50),
                                  child: Icon(
                                    isIncome
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    color: isIncome ? Colors.green : Colors.red,
                                  ),
                                ),
                                title: Text(
                                  tx.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  '${tx.category} • ${tx.date.day.toString().padLeft(2, '0')}/${tx.date.month.toString().padLeft(2, '0')}/${tx.date.year}',
                                ),
                                trailing: Text(
                                  '${isIncome ? '+' : '-'}R\$ ${tx.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isIncome ? Colors.green : Colors.red,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.of(context).pushNamed(
                                    TransactionRoutes.form,
                                    arguments: tx,
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            Navigator.of(context).pushNamed(TransactionRoutes.form),
        label: const Text('Adicionar'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final bool isWide;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.color,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: 20.0,
          horizontal: isWide ? 24.0 : 12.0,
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'R\$ ${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: isWide ? 28 : 20,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TransactionFormView extends StatefulWidget {
  final TransactionController controller;
  const TransactionFormView({super.key, required this.controller});

  @override
  State<TransactionFormView> createState() => _TransactionFormViewState();
}

class _TransactionFormViewState extends State<TransactionFormView> {
  final _formKey = GlobalKey<FormState>();
  late String _id;
  late String _title;
  late double _amount;
  late TransactionType _type;
  late String _category;
  late DateTime _date;
  bool _isEditing = false;

  final _categories = ['Alimentação', 'Transporte', 'Salário', 'Lazer', 'Outros'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is TransactionModel && !_isEditing) {
      _isEditing = true;
      _id = args.id;
      _title = args.title;
      _amount = args.amount;
      _type = args.type;
      _category = args.category;
      _date = args.date;
    } else if (!_isEditing) {
      _id = DateTime.now().millisecondsSinceEpoch.toString();
      _title = '';
      _amount = 0.0;
      _type = TransactionType.expense;
      _category = _categories.first;
      _date = DateTime.now();
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final model = TransactionModel(
        id: _id,
        title: _title,
        amount: _amount,
        date: _date,
        category: _category,
        type: _type,
      );

      if (_isEditing) {
        widget.controller.updateTransaction(model);
      } else {
        widget.controller.addTransaction(model);
      }
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Transação' : 'Nova Transação'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                initialValue: _title,
                decoration: InputDecoration(
                  labelText: 'Título',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.title),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Obrigatório' : null,
                onSaved: (val) => _title = val!,
              ),
              const SizedBox(height: 20),
              TextFormField(
                initialValue: _amount == 0.0 ? '' : _amount.toString(),
                decoration: InputDecoration(
                  labelText: 'Valor',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.attach_money),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Obrigatório';
                  if (double.tryParse(val) == null) return 'Número inválido';
                  return null;
                },
                onSaved: (val) => _amount = double.parse(val!),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<TransactionType>(
                initialValue: _type,
                decoration: InputDecoration(
                  labelText: 'Tipo',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.swap_vert),
                ),
                items: TransactionType.values
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t == TransactionType.income ? 'RECEITA' : 'DESPESA'),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _type = val!),
                onSaved: (val) => _type = val!,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: InputDecoration(
                  labelText: 'Categoria',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.category),
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setState(() => _category = val!),
                onSaved: (val) => _category = val!,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _save,
                child: const Text(
                  'Salvar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

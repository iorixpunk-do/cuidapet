import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  await AdMobService.instance.init();
  runApp(const CuidaPetApp());
}

class CuidaPetApp extends StatelessWidget {
  const CuidaPetApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CuidaPet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// MODELOS DE DADOS
// -----------------------------------------------------------------------------
class PetModel {
  final String id;
  final String userId;
  final String name;
  final String species;
  final String? breed;
  final String? birthDate;

  PetModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.species,
    this.breed,
    this.birthDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'species': species,
      'breed': breed,
      'birth_date': birthDate,
    };
  }

  factory PetModel.fromMap(Map<String, dynamic> map) {
    return PetModel(
      id: map['id'],
      userId: map['user_id'],
      name: map['name'],
      species: map['species'],
      breed: map['breed'],
      birthDate: map['birth_date'],
    );
  }
}

class ReminderModel {
  final String id;
  final String petId;
  final String title;
  final String category;
  final String dueDate;
  final String repeatInterval;
  final bool isCompleted;

  ReminderModel({
    required this.id,
    required this.petId,
    required this.title,
    required this.category,
    required this.dueDate,
    required this.repeatInterval,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pet_id': petId,
      'title': title,
      'category': category,
      'due_date': dueDate,
      'repeat_interval': repeatInterval,
      'is_completed': isCompleted ? 1 : 0,
    };
  }

  factory ReminderModel.fromMap(Map<String, dynamic> map) {
    return ReminderModel(
      id: map['id'],
      petId: map['pet_id'],
      title: map['title'],
      category: map['category'],
      dueDate: map['due_date'],
      repeatInterval: map['repeat_interval'],
      isCompleted: map['is_completed'] == 1,
    );
  }
}

// -----------------------------------------------------------------------------
// BANCO DE DADOS LOCAL (SQLITE)
// -----------------------------------------------------------------------------
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('cuidapet.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE pets (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        species TEXT NOT NULL,
        breed TEXT,
        birth_date TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    await db.execute('''
      CREATE TABLE reminders (
        id TEXT PRIMARY KEY,
        pet_id TEXT NOT NULL,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        due_date TEXT NOT NULL,
        repeat_interval TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (pet_id) REFERENCES pets (id) ON DELETE CASCADE
      );
    ''');
  }

  Future<int> insertPet(PetModel pet) async {
    final db = await instance.database;
    return await db.insert('pets', pet.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<PetModel>> getAllPets() async {
    final db = await instance.database;
    final result = await db.query('pets', orderBy: 'created_at DESC');
    return result.map((map) => PetModel.fromMap(map)).toList();
  }

  Future<int> insertReminder(ReminderModel reminder) async {
    final db = await instance.database;
    return await db.insert('reminders', reminder.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ReminderModel>> getRemindersByPet(String petId) async {
    final db = await instance.database;
    final result = await db.query('reminders', where: 'pet_id = ?', whereArgs: [petId], orderBy: 'due_date ASC');
    return result.map((map) => ReminderModel.fromMap(map)).toList();
  }

  Future<int> toggleReminderCompleted(String id, bool isCompleted) async {
    final db = await instance.database;
    return await db.update('reminders', {'is_completed': isCompleted ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }
}

// -----------------------------------------------------------------------------
// NOTIFICAÇÕES LOCAIS
// -----------------------------------------------------------------------------
class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  NotificationService._init();

  Future<void> init() async {
    tz_data.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await _notificationsPlugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
  }

  Future<void> scheduleReminderNotification(ReminderModel reminder) async {
    final int notificationId = reminder.id.hashCode.abs() % 2147483647;
    final DateTime scheduledDate = DateTime.parse(reminder.dueDate);

    if (scheduledDate.isBefore(DateTime.now())) return;

    final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'cuidapet_reminders',
      'Lembretes do CuidaPet',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _notificationsPlugin.zonedSchedule(
      notificationId,
      'CuidaPet: ${reminder.title}',
      'Hora de cuidar do seu pet!',
      tzScheduledDate,
      const NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails()),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: reminder.id,
    );
  }
}

// -----------------------------------------------------------------------------
// ADMOB E REVENUECAT
// -----------------------------------------------------------------------------
class AdMobService {
  static final AdMobService instance = AdMobService._init();
  AdMobService._init();

  Future<void> init() async {
    await MobileAds.instance.initialize();
  }

  static String get bannerAdUnitId {
    return Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/6300978111'
        : 'ca-app-pub-3940256099942544/2934735716';
  }
}

class RevenueCatService {
  static final RevenueCatService instance = RevenueCatService._init();
  RevenueCatService._init();

  Future<bool> isProUser() async {
    try {
      final CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all['pro']?.isActive ?? false;
    } catch (_) {
      return false;
    }
  }
}

// -----------------------------------------------------------------------------
// INTERFACE DE USUÁRIO (TELA HOME)
// -----------------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<PetModel> _pets = [];
  PetModel? _selectedPet;
  List<ReminderModel> _reminders = [];
  bool _isPro = false;
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadBanner();
  }

  Future<void> _loadData() async {
    final isPro = await RevenueCatService.instance.isProUser();
    final pets = await DatabaseHelper.instance.getAllPets();
    
    setState(() {
      _isPro = isPro;
      _pets = pets;
      if (pets.isNotEmpty) {
        _selectedPet = pets.first;
      }
    });

    if (_selectedPet != null) {
      _loadReminders(_selectedPet!.id);
    }
  }

  Future<void> _loadReminders(String petId) async {
    final reminders = await DatabaseHelper.instance.getRemindersByPet(petId);
    setState(() {
      _reminders = reminders;
    });
  }

  void _loadBanner() {
    _bannerAd = BannerAd(
      adUnitId: AdMobService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() {}),
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    )..load();
  }

  void _addMockPet() async {
    final newPet = PetModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'local_user',
      name: 'Thor',
      species: 'Cão',
      breed: 'Golden Retriever',
    );
    await DatabaseHelper.instance.insertPet(newPet);
    _loadData();
  }

  void _addMockReminder() async {
    if (_selectedPet == null) return;
    final reminder = ReminderModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      petId: _selectedPet!.id,
      title: 'Aplicar Antipulgas',
      category: 'flea_tick',
      dueDate: DateTime.now().add(const Duration(minutes: 2)).toIso8601String(),
      repeatInterval: 'monthly',
    );
    await DatabaseHelper.instance.insertReminder(reminder);
    await NotificationService.instance.scheduleReminderNotification(reminder);
    _loadReminders(_selectedPet!.id);
  }

  void _generatePdf() async {
    if (_selectedPet == null) return;

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Center(
          child: pw.Text('Prontuario do Pet: ${_selectedPet!.name}'),
        ),
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Prontuario.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CuidaPet'),
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _generatePdf),
        ],
      ),
      body: Column(
        children: [
          if (_pets.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _addMockPet,
                child: const Text('Cadastrar Primeiro Pet (Thor)'),
              ),
            )
          else ...[
            ListTile(
              title: Text('Pet: ${_selectedPet?.name}'),
              subtitle: Text('Raça: ${_selectedPet?.breed}'),
              trailing: ElevatedButton(
                onPressed: _addMockReminder,
                child: const Text('+ Lembrete'),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _reminders.length,
                itemBuilder: (context, index) {
                  final reminder = _reminders[index];
                  return CheckboxListTile(
                    title: Text(reminder.title),
                    subtitle: Text('Horário: ${reminder.dueDate}'),
                    value: reminder.isCompleted,
                    onChanged: (val) async {
                      await DatabaseHelper.instance.toggleReminderCompleted(reminder.id, val ?? false);
                      _loadReminders(_selectedPet!.id);
                    },
                  );
                },
              ),
            ),
          ],
          if (!_isPro && _bannerAd != null)
            SizedBox(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }
}

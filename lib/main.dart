import 'package:flutter/material.dart';

void main() {
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF009688),
          primary: const Color(0xFF009688),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      ),
      home: const HomeScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// MODELOS SIMPLES
// -----------------------------------------------------------------------------
class Pet {
  final String name;
  final String breed;
  final String age;
  final IconData icon;

  Pet({required this.name, required this.breed, required this.age, required this.icon});
}

class Reminder {
  final String title;
  final String time;
  final String category;
  bool isCompleted;

  Reminder({
    required this.title,
    required this.time,
    required this.category,
    this.isCompleted = false,
  });
}

// -----------------------------------------------------------------------------
// TELA PRINCIPAL (HOME)
// -----------------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isPro = false;

  final List<Pet> pets = [
    Pet(name: 'Thor', breed: 'Golden Retriever', age: '2 anos', icon: Icons.pets),
    Pet(name: 'Yumi', breed: 'Gato Saimês', age: '1 ano', icon: Icons.catching_pokemon),
  ];

  late Pet selectedPet;

  final Map<String, List<Reminder>> remindersMap = {
    'Thor': [
      Reminder(title: 'Aplicar Antipulgas', time: 'Hoje às 20:00', category: 'flea'),
      Reminder(title: 'Vacina V10 (Reforço)', time: '15 de Nov às 09:00', category: 'vaccine'),
      Reminder(title: 'Banho e Tosa', time: 'Sábado às 14:00', category: 'bath'),
    ],
    'Yumi': [
      Reminder(title: 'Remédio para Verme', time: 'Amanhã às 10:00', category: 'medicine'),
    ],
  };

  @override
  void initState() {
    super.initState();
    selectedPet = pets.first;
  }

  void _addReminderDialog() {
    final titleController = TextEditingController();
    final timeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Novo Lembrete para ${selectedPet.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Título (ex: Dar Ração)'),
              ),
              TextField(
                controller: timeController,
                decoration: const InputDecoration(labelText: 'Horário (ex: Hoje às 19:00)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  setState(() {
                    remindersMap[selectedPet.name]?.add(
                      Reminder(
                        title: titleController.text,
                        time: timeController.text.isEmpty ? 'Hoje' : timeController.text,
                        category: 'general',
                      ),
                    );
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentReminders = remindersMap[selectedPet.name] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('CuidaPet', style: TextStyle(fontWeight: FontWeight.bold)),
            if (isPro) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('PRO', style: TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ]
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(isPro ? Icons.star : Icons.star_border, color: Colors.amber),
            tooltip: 'Alternar PRO',
            onPressed: () {
              setState(() {
                isPro = !isPro;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Carrossel/Seletor de Pets
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: pets.length,
              itemBuilder: (context, index) {
                final pet = pets[index];
                final isSelected = pet.name == selectedPet.name;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedPet = pet;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF009688) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF009688)),
                    ),
                    child: Row(
                      children: [
                        Icon(pet.icon, color: isSelected ? Colors.white : const Color(0xFF009688), size: 18),
                        const SizedBox(width: 6),
                        Text(
                          pet.name,
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF009688),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Card do Pet Ativo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFFE0F2F1),
                      child: Icon(selectedPet.icon, size: 30, color: const Color(0xFF009688)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(selectedPet.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('${selectedPet.breed} • ${selectedPet.age}', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _addReminderDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Lembrete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF009688),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Lista de Lembretes
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Lembretes da Rotina',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: currentReminders.isEmpty
                ? const Center(child: Text('Nenhum lembrete cadastrado para este pet.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: currentReminders.length,
                    itemBuilder: (context, index) {
                      final reminder = currentReminders[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: CheckboxListTile(
                          value: reminder.isCompleted,
                          title: Text(
                            reminder.title,
                            style: TextStyle(
                              decoration: reminder.isCompleted ? TextDecoration.lineThrough : null,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(reminder.time),
                          activeColor: const Color(0xFF009688),
                          onChanged: (val) {
                            setState(() {
                              reminder.isCompleted = val ?? false;
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),

          // Banner do Rodapé (Simulando o AdMob no modo Free)
          if (!isPro)
            Container(
              width: double.infinity,
              height: 50,
              color: Colors.grey[300],
              child: const Center(
                child: Text(
                  '📢 Anúncio AdMob (Modo Gratuito)',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// --- 1. FUNKCJA DO POBIERANIA DANYCH Z OPEN FOOD FACTS ---
Future fetchProductFromApi(String barcode) async {  final url = Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json');
  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 1) {
        final product = data['product'];
        final String name = product['product_name'] ?? 'Brak nazwy';
        final List<dynamic>? categories = product['categories_tags'];

        return {
          'name': name,
          'brand': product['brands'] ?? '',
          'image': product['image_front_url'] ?? '',
          'emoji': getEmojiForProduct(categories, name),
        };
      }
    }
  } catch (e) {
    debugPrint('Błąd połączenia: $e');
  }
  return null;
}

// --- 2. MAPOWANIE PRODUKTU NA EMOJI ---
String getEmojiForProduct(List<dynamic>? categoriesTags, String? productName) {
  final tags = (categoriesTags ?? []).join(' ').toLowerCase();
  final name = (productName ?? '').toLowerCase();
  final text = '$tags $name';

  if (text.contains('cheese') || text.contains('ser') || text.contains('mozzarella') || text.contains('twaróg') || text.contains('feta')) return '🧀';
  if (text.contains('butter') || text.contains('masło') || text.contains('margaryn')) return '🧈';
  if (text.contains('egg') || text.contains('jaj')) return '🥚';
  if (text.contains('milk') || text.contains('mlek') || text.contains('yogurt') || text.contains('jogurt') || text.contains('kefir') || text.contains('śmietan')) return '🥛';

  if (text.contains('chicken') || text.contains('poultry') || text.contains('kurczak') || text.contains('indyk')) return '🍗';
  if (text.contains('fish') || text.contains('salmon') || text.contains('tuna') || text.contains('ryb') || text.contains('łosoś')) return '🐟';
  if (text.contains('meat') || text.contains('ham') || text.contains('sausage') || text.contains('mięs') || text.contains('szynk') || text.contains('kiełbas') || text.contains('parówk') || text.contains('boczek')) return '🥩';

  if (text.contains('tomato') || text.contains('pomidor')) return '🍅';
  if (text.contains('carrot') || text.contains('marchew')) return '🥕';
  if (text.contains('potato') || text.contains('ziemniak')) return '🥔';
  if (text.contains('apple') || text.contains('jabłk')) return '🍎';
  if (text.contains('banana') || text.contains('banan')) return '🍌';
  if (text.contains('broccoli') || text.contains('brokuł') || text.contains('vegetable') || text.contains('salad') || text.contains('warzyw') || text.contains('sałat')) return '🥦';
  if (text.contains('fruit') || text.contains('owoc')) return '🍓';

  if (text.contains('bread') || text.contains('bakery') || text.contains('chleb') || text.contains('bułk')) return '🍞';
  if (text.contains('pasta') || text.contains('makaron')) return '🍝';
  if (text.contains('rice') || text.contains('ryż')) return '🍚';

  if (text.contains('water') || text.contains('woda')) return '💧';
  if (text.contains('juice') || text.contains('sok')) return '🧃';
  if (text.contains('beverage') || text.contains('soda') || text.contains('napój')) return '🥤';

  if (text.contains('chocolate') || text.contains('czekolad')) return '🍫';
  if (text.contains('sweet') || text.contains('candy') || text.contains('słodycz') || text.contains('ciastk') || text.contains('lody')) return '🍬';

  return '🛒';
}

// --- 3. FORMATOWANIE DATY WAŻNOŚCI ---
Map<String, dynamic> formatExpirationDate(Timestamp? timestamp) {
  if (timestamp == null) {
    return {'text': 'Brak daty', 'color': Colors.grey};
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final expDate = timestamp.toDate();
  final expDay = DateTime(expDate.year, expDate.month, expDate.day);

  final diff = expDay.difference(today).inDays;

  if (diff < 0) {
    return {'text': 'Przeterminowane!', 'color': Colors.red};
  } else if (diff == 0) {
    return {'text': 'Mija dzisiaj!', 'color': Colors.red};
  } else if (diff == 1) {
    return {'text': 'Za 1 dzień', 'color': Colors.deepOrange};
  } else if (diff >= 2 && diff <= 6) {
    return {'text': 'Za $diff dni', 'color': Colors.orange[800]};
  } else if (diff >= 7 && diff <= 13) {
    return {'text': 'Za tydzień', 'color': Colors.green[700]};
  } else {
    final day = expDate.day.toString().padLeft(2, '0');
    final month = expDate.month.toString().padLeft(2, '0');
    final year = expDate.year;
    return {'text': '$day.$month.$year', 'color': Colors.grey[700]};
  }
}

// --- 4. START APLIKACJI ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moja Lodówka',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 119, 1, 103),
        ),
      ),
      home: const FridgeScreen(),
    );
  }
}

// --- 5. EKRAN GŁÓWNY Z KAFELKAMI PRODUKTÓW ---
class FridgeScreen extends StatelessWidget {
  const FridgeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Moja lodówka'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('lodowka').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Błąd pobierania danych z bazy.'));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Lodówka jest pusta.\nKliknij przycisk poniżej, aby dodać produkt.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.95, // Nieco wyższe kafelki, żeby zmieściła się data
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final String nazwa = data['nazwa'] ?? 'Bez nazwy';
              final String ikona = data['ikona'] ?? getEmojiForProduct(null, nazwa);
              final Timestamp? dataWaznosci = data['data_waznosci'] as Timestamp?;
              final expInfo = formatExpirationDate(dataWaznosci);

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    // Główna zawartość kafelka
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              ikona,
                              style: const TextStyle(fontSize: 42),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              nazwa,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              expInfo['text'],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: expInfo['color'],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Przycisk usuwania w prawym górnym rogu kafelka
                    Positioned(
                      top: 2,
                      right: 2,
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                        tooltip: 'Usuń z lodówki',
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection('lodowka')
                              .doc(doc.id)
                              .delete();

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Usunięto: $nazwa')),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddProductPage(title: 'Dodaj produkt'),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Dodaj produkt', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }
}

// --- 6. EKRAN DODAWANIA PRODUKTU ---
class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key, required this.title});
  final String title;

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _gramsController = TextEditingController();

  final List<String> _productTypes = [
    'Nabiał',
    'Warzywa',
    'Owoce',
    'Mięso i ryby',
    'Pieczywo',
    'Napoje',
    'Inne',
  ];
  String _selectedType = 'Nabiał';

  String? productImage;
  String? productEmoji;
  bool isScanned = false;

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _gramsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (productImage != null && productImage!.isNotEmpty)
              Image.network(productImage!, height: 150)
            else if (productEmoji != null)
              Text(productEmoji!, style: const TextStyle(fontSize: 80))
            else
              const Icon(Icons.kitchen, size: 100, color: Colors.grey),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: () async {
                String? res = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(
                        title: const Text('Zeskanuj kod'),
                        leading: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context, '-1'),
                        ),
                      ),
                      body: const SimpleBarcodeScannerPage(),
                    ),
                  ),
                );

                if (res != null && res != '-1' && res.isNotEmpty) {
                  var productData = await fetchProductFromApi(res);
                  if (productData != null) {
                    setState(() {
                      _nameController.text = productData['name'];
                      _brandController.text = productData['brand'];
                      productImage = productData['image'];
                      productEmoji = productData['emoji'];
                      isScanned = true;
                    });
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Nie znaleziono w bazie – wpisz dane ręcznie.'),
                        ),
                      );
                    }
                  }
                }
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Zeskanuj kod kreskowy'),
            ),

            const SizedBox(height: 24),
            const Text('— lub wpisz dane ręcznie —', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nazwa produktu',
                hintText: 'np. Jogurt naturalny',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _brandController,
              decoration: const InputDecoration(
                labelText: 'Marka',
                hintText: 'np. Piątnica, Mlekovita',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Typ produktu',
                border: OutlineInputBorder(),
              ),
              items: _productTypes.map((String typ) {
                return DropdownMenuItem<String>(
                  value: typ,
                  child: Text(typ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedType = newValue;
                  });
                }
              },
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _gramsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Ilość (g/ml/kg)',
                hintText: 'np. 150',
                suffixText: 'g',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            if (_nameController.text.trim().isNotEmpty)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () async {
                  DateTime? wybranaData = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );

                  if (wybranaData != null) {
                    final nazwa = _nameController.text.trim();
                    final marka = _brandController.text.trim();
                    final gramy = int.tryParse(_gramsController.text.trim()) ?? 0;
                    final ikona = productEmoji ?? getEmojiForProduct(null, nazwa);

                    await FirebaseFirestore.instance.collection('lodowka').add({
                      'nazwa': nazwa,
                      'marka': marka.isEmpty ? 'Brak' : marka,
                      'typ': _selectedType,
                      'ilosc_gram': gramy,
                      'data_waznosci': wybranaData,
                      'zdjecie': productImage ?? '',
                      'ikona': ikona,
                      'kto_dodal': isScanned ? 'Skaner' : 'Ręcznie',
                    });

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Dodano $nazwa do lodówki!')),
                      );
                      Navigator.pop(context);
                    }
                  }
                },
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text(
                  'Wybierz datę ważności i zapisz',
                  style: TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
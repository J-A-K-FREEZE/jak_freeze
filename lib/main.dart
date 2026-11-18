import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
 
// --- 1. FUNKCJA DO POBIERANIA DANYCH Z INTERNETU ---
Future fetchProductFromApi(String barcode) async {
  final url = Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json');
  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 1) {
        final product = data['product'];
        return {
          'name': product['product_name'] ?? 'Brak nazwy',
          'brand': product['brands'] ?? '',
          'image': product['image_front_url'] ?? '',
        };
      }
    }
  } catch (e) {
    print('Błąd połączenia: $e');
  }
  return null;
}
 
// --- 2. START APLIKACJI I BAZY DANYCH ---
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 119, 1, 103),
        ),
      ),
      home: const MyHomePage(title: 'Dodaj produkt'),
    );
  }
}
 
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
 
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}
 
class _MyHomePageState extends State<MyHomePage> {
  // Kontrolery pól tekstowych
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _gramsController = TextEditingController();
 
  // Lista typów produktów
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
            // Zdjęcie produktu (ze skanera) lub ikona lodówki
            if (productImage != null && productImage!.isNotEmpty)
              Image.network(productImage!, height: 150)
            else
              const Icon(Icons.kitchen, size: 100, color: Colors.grey),
 
            const SizedBox(height: 20),
 
            // --- PRZYCISK 1: Skanowanie kodem kreskowym (z obsługą wyjścia) ---
            ElevatedButton.icon(
              onPressed: () async {
                // Otwieramy skaner w nowym oknie/ekranie
                String? res = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(
                        title: const Text('Zeskanuj kod'),
                        leading: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            // Zamyka aparat i zwraca '-1' (anulowanie)
                            Navigator.pop(context, '-1');
                          },
                        ),
                      ),
                      body: const SimpleBarcodeScannerPage(),
                    ),
                  ),
                );
 
                // Sprawdzamy czy użytkownik coś zeskanował (res != null, nie jest puste i nie jest '-1')
                if (res != null && res != '-1' && res.isNotEmpty) {
                  var productData = await fetchProductFromApi(res);
                  if (productData != null) {
                    setState(() {
                      _nameController.text = productData['name'];
                      _brandController.text = productData['brand'];
                      productImage = productData['image'];
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
 
            // --- POLE 1: Nazwa produktu ---
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
 
            // --- POLE 2: Marka ---
            TextField(
              controller: _brandController,
              decoration: const InputDecoration(
                labelText: 'Marka',
                hintText: 'np. Piątnica, Mlekovita',
                border: OutlineInputBorder(),
              ),
            ),
 
            const SizedBox(height: 12),
 
            // --- POLE 3: Typ produktu (lista rozwijana) ---
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
 
            // --- POLE 4: Ilość w gramach ---
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
 
            // --- PRZYCISK 2: Wybór daty ważności i zapis do Firebase ---
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
 
                    await FirebaseFirestore.instance.collection('lodowka').add({
                      'nazwa': nazwa,
                      'marka': marka.isEmpty ? 'Brak' : marka,
                      'typ': _selectedType,
                      'ilosc_gram': gramy,
                      'data_waznosci': wybranaData,
                      'zdjecie': productImage ?? '',
                      'kto_dodal': isScanned ? 'Skaner' : 'Ręcznie',
                    });
 
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Dodano $nazwa do lodówki!')),
                      );
                    }
 
                    // Czyszczenie formularza
                    setState(() {
                      _nameController.clear();
                      _brandController.clear();
                      _gramsController.clear();
                      _selectedType = 'Nabiał';
                      productImage = null;
                      isScanned = false;
                    });
                  }
                },
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text(
                  'Wybierz datę ważności i zapisz',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 40),
            const Divider(thickness: 2),
            const Text(
              'TESTOWA ZAWARTOŚĆ BAZY (do usuwania):', 
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)
            ),
            const SizedBox(height: 10),

            // --- 3. ROBOCZA LISTA Z CHMURY (StreamBuilder) ---
            StreamBuilder<QuerySnapshot>(
              // Podpinamy się pod kolekcję 'lodowka' na żywo
              stream: FirebaseFirestore.instance.collection('lodowka').snapshots(),
              builder: (context, snapshot) {
                // Jeśli jeszcze się ładuje, pokaż kółko
                if (!snapshot.hasData) return const CircularProgressIndicator();
                
                final produkty = snapshot.data!.docs;

                // Jeśli baza jest pusta
                if (produkty.isEmpty) return const Text('Baza jest pusta.');

                // Budujemy prostą listę
                return ListView.builder(
                  shrinkWrap: true, // Bardzo ważne, żeby lista nie wybuchła wewnątrz ScrollView
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: produkty.length,
                  itemBuilder: (context, index) {
                    var produkt = produkty[index];
                    var dane = produkt.data() as Map<String, dynamic>;

                    return ListTile(
                      leading: const Icon(Icons.fastfood),
                      title: Text(dane['nazwa'] ?? 'Brak nazwy'),
                      subtitle: Text('Marka: ${dane['marka'] ?? 'Brak'}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          // --- TO JEST GŁÓWNA KOMENDA USUWAJĄCA ---
                          // Bierzemy ID konkretnego produktu (produkt.id) i mówimy bazie: skasuj to!
                          await FirebaseFirestore.instance
                              .collection('lodowka')
                              .doc(produkt.id)
                              .delete();
                              
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Usunięto z bazy!')),
                            );
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
 
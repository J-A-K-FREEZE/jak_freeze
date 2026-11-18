import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;

import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';

import 'package:firebase_core/firebase_core.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
 
// --- 1. FUNKCJA DO POBIERANIA DANYCH Z INTERNETU (Kod koleżanki) ---

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

          'brand': product['brands'] ?? 'Nieznana marka',

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

  // Zmienne przechowujące to, co zeskanuje aparat

  String scannedResult = "Nie zeskanowano żadnego produktu";

  String? productName;

  String? productBrand;

  String? productImage;
 
  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        backgroundColor: Theme.of(context).colorScheme.inversePrimary,

        title: Text(widget.title),

      ),

      body: Center(

        child: Padding(

          padding: const EdgeInsets.all(16.0),

          child: Column(

            mainAxisAlignment: MainAxisAlignment.center,

            children: [

              // Wyświetlanie zdjęcia produktu lub ikony lodówki

              if (productImage != null && productImage!.isNotEmpty)

                Image.network(productImage!, height: 150)

              else

                const Icon(Icons.kitchen, size: 100, color: Colors.grey),

              const SizedBox(height: 20),

              // Wyświetlanie nazwy produktu

              Text(

                productName ?? 'Zeskanuj produkt, aby dodać do lodówki',

                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),

                textAlign: TextAlign.center,

              ),

              // Wyświetlanie marki

              if (productBrand != null)

                Text('Marka: $productBrand', style: TextStyle(fontSize: 16, color: Colors.grey[700])),

              const SizedBox(height: 30),

              // --- PRZYCISK 1: Uruchomienie aparatu ---

              ElevatedButton.icon(

                onPressed: () async {
                String? res = await SimpleBarcodeScanner.scanBarcode(context);

                  if (res != null && res != '-1') {

                    setState(() {

                      scannedResult = res;

                    });

                    var productData = await fetchProductFromApi(res);

                    if (productData != null) {

                      setState(() {

                        productName = productData['name'];

                        productBrand = productData['brand'];

                        productImage = productData['image'];

                      });

                    } else {

                      setState(() {

                        productName = "Nie znaleziono w bazie Open Food Facts";

                        productBrand = null;

                        productImage = null;

                      });

                    }

                  }

                },

                icon: const Icon(Icons.camera_alt),

                label: const Text('Zeskanuj kod kreskowy'),

              ),

              const SizedBox(height: 20),

              // --- PRZYCISK 2: Wybór daty i zapis do Firebase ---

              // Pokazuje się tylko, jeśli znaleziono produkt w bazie

              if (productName != null && productName != "Nie znaleziono w bazie Open Food Facts")

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

                      // Zapis do Waszej chmury!

                      await FirebaseFirestore.instance.collection('lodowka').add({

                        'nazwa': productName,

                        'marka': productBrand ?? 'Brak',

                        'zdjecie': productImage ?? '',

                        'data_waznosci': wybranaData,

                        'kto_dodal': 'Skaner',

                      });
 
                      // Komunikat na dole ekranu

                      if (context.mounted) {

                        ScaffoldMessenger.of(context).showSnackBar(

                          SnackBar(content: Text('Dodano $productName do lodówki!')),

                        );

                      }
 
                      // Czyszczenie ekranu do kolejnego skanowania

                      setState(() {

                        productName = null;

                        productBrand = null;

                        productImage = null;

                      });

                    }

                  },

                  icon: const Icon(Icons.save, color: Colors.white),

                  label: const Text('Wybierz datę i zapisz w lodówce', style: TextStyle(color: Colors.white)),

                ),

            ],

          ),

        ),

      ),

    );

  }

}
 
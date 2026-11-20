import 'package:flutter/material.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../helpers/product_helpers.dart';
import 'dart:async';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key, required this.title});
  final String title;

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _kcalController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  final _units = ['g', 'ml', 'szt.', 'l', 'kg'];
  String _selectedUnit = 'g';

  final _productTypes = [
    'Nabiał',
    'Warzywa',
    'Owoce',
    'Mięso i ryby',
    'Pieczywo',
    'Napoje',
    'Inne',
  ];
  String _selectedType = 'Nabiał';

  DateTime? _selectedDate;
  String? productImage;
  String? productEmoji;
  bool isScanned = false;
  bool _isSaving = false;

  List _searchResults = [];
bool _isSearching = false;
Timer? _debounce;

void _onSearchChanged(String query) {
  _debounce?.cancel();
  if (query.trim().length < 2) {
    setState(() {
      _searchResults = [];
      _isSearching = false;
    });
    return;
  }

  setState(() => _isSearching = true);
  _debounce = Timer(const Duration(milliseconds: 500), () async {
    final results = await searchProductsByName(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  });
}

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _kcalController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'dd.mm.rrrr';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d.$m.${date.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _scanBarcode() async {
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
          _nameController.text = productData['name'] ?? '';
          productImage = productData['image'];
          productEmoji = productData['emoji'];
          isScanned = true;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nie znaleziono w bazie – wpisz dane ręcznie.'),
            ),
          );
        }
      }
    }
  }

  Future<void> _saveProduct() async {
    final nazwa = _nameController.text.trim();
    if (nazwa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wpisz nazwę produktu.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final ilosc = int.tryParse(_amountController.text.trim()) ?? 0;
      final kcal = int.tryParse(_kcalController.text.trim()) ?? 0;
      final ikona = productEmoji ?? getEmojiForProduct(null, nazwa);

      await FirebaseFirestore.instance.collection('lodowka').add({
        'nazwa': nazwa,
        'marka': 'Brak',
        'typ': _selectedType,
        'ilosc_gram': ilosc,
        'jednostka': _selectedUnit,
        'kcal': kcal,
        'data_waznosci': _selectedDate,
        'zdjecie': productImage ?? '',
        'ikona': ikona,
        'kto_dodal': isScanned ? 'Skaner' : 'Ręcznie',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dodano $nazwa do lodówki!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd zapisu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _inputDecoration({
    required String hint,
    Widget? prefixIcon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFB59BA2), fontSize: 15),
      prefixIcon: prefixIcon,
      suffix: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFECDCE0), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF9E4263), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- GÓRNY PASEK (J.A.K. Freeze + Avatar) ---
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.eco_outlined, color: Color(0xFF9E4263), size: 20),
                      SizedBox(width: 6),
                      Text(
                        'J.A.K. Freeze',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF9E4263),
                        ),
                      ),
                    ],
                  ),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFFF3D4DE),
                    child: Text(
                      'A',
                      style: TextStyle(
                        color: Color(0xFF9E4263),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // --- POWRÓT: < Moja lodówka ---
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chevron_left, color: Color(0xFF9E4263), size: 20),
                      SizedBox(width: 2),
                      Text(
                        'Moja lodówka',
                        style: TextStyle(
                          color: Color(0xFF9E4263),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // --- TYTUŁ ---
              const Text(
                'Dodaj produkt',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3A262B),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Zeskanuj kod lub wpisz nazwę produktu.',
                style: TextStyle(fontSize: 14, color: Color(0xFF8A7278)),
              ),
              const SizedBox(height: 18),

              // --- KARTA SKANERA ---
              InkWell(
                onTap: _scanBarcode,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBE9EE),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFF2D0DC), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5D5E0),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner,
                          color: Color(0xFF9E4263),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Zeskanuj kod kreskowy',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF9E4263),
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Użyj aparatu — dane produktu uzupełnią się automatycznie.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7B6369),
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: Color(0xFF9E4263)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // --- SEPARATOR ---
              const Row(
                children: [
                  Expanded(child: Divider(color: Color(0xFFEADCE0))),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'lub dodaj ręcznie',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9E7F87)),
                    ),
                  ),
                  Expanded(child: Divider(color: Color(0xFFEADCE0))),
                ],
              ),
              const SizedBox(height: 14),

              // --- WYSZUKAJ PRODUKT ---
           const Text(
             'Wyszukaj produkt',
             style: TextStyle(
               fontSize: 13,
               fontWeight: FontWeight.w700,
               color: Color(0xFF3A262B),
             ),
           ),
           const SizedBox(height: 8),
           TextField(
             controller: _searchController,
             onChanged: _onSearchChanged,
             decoration: _inputDecoration(
               hint: 'Wpisz nazwę, np. mleko',
               prefixIcon: const Icon(Icons.search, color: Color(0xFF8A7278)),
               suffix: _isSearching
                   ? const SizedBox(
                       width: 16,
                       height: 16,
                       child: CircularProgressIndicator(strokeWidth: 2),
                     )
                   : null,
             ),
           ),
           if (_searchResults.isNotEmpty)
             Container(
               margin: const EdgeInsets.only(top: 6),
               decoration: BoxDecoration(
                 color: Colors.white,
                 borderRadius: BorderRadius.circular(16),
                 border: Border.all(color: const Color(0xFFECDCE0)),
               ),
               child: ListView.separated(
                 shrinkWrap: true,
                 physics: const NeverScrollableScrollPhysics(),
                 itemCount: _searchResults.length,
                 separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3E4E8)),
                 itemBuilder: (context, index) {
                   final item = _searchResults[index];
                   final String name = item['name'] ?? '';
                   final String brand = item['brand'] ?? '';
                   final String title = brand.isNotEmpty ? '$name — $brand' : name;

                   return ListTile(
                     dense: true,
                     leading: Text(item['emoji'] ?? '🛒', style: const TextStyle(fontSize: 22)),
                     title: Text(
                       title,
                       maxLines: 1,
                       overflow: TextOverflow.ellipsis,
                       style: const TextStyle(fontSize: 14, color: Color(0xFF3A262B)),
                     ),
                     subtitle: item['kcal'] != null
                         ? Text('${item['kcal']} kcal / 100 g', style: const TextStyle(fontSize: 11))
                         : null,
                     onTap: () {
                       setState(() {
                         _nameController.text = title;
                         if (item['kcal'] != null) {
                           _kcalController.text = item['kcal'].toString();
                         }
                         productImage = item['image'];
                         productEmoji = item['emoji'];
                         _searchResults = [];
                         _searchController.clear();
                       });
                     },
                   );
                 },
               ),
             ),
           const SizedBox(height: 22),

              // --- NAGŁÓWEK: DANE PRODUKTU + ETYKIETA ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Dane produktu',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3A262B),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBE9EE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isScanned ? Icons.qr_code_scanner : Icons.edit_outlined,
                          size: 13,
                          color: const Color(0xFF9E4263),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isScanned ? 'Skaner' : 'Ręcznie',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9E4263),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // --- NAZWA PRODUKTU ---
              const Text(
                'Nazwa produktu',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3A262B),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                decoration: _inputDecoration(hint: 'Jogurt naturalny'),
              ),
              const SizedBox(height: 14),

              // --- KATEGORIA (do półek w lodówce) ---
              const Text(
                'Kategoria',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3A262B),
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedType,
                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF9E4263)),
                decoration: _inputDecoration(hint: 'Wybierz kategorię'),
                items: _productTypes.map((typ) {
                  return DropdownMenuItem(value: typ, child: Text(typ));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedType = val);
                },
              ),
              const SizedBox(height: 14),

              // --- WARTOŚĆ ENERGETYCZNA ---
              const Text(
                'Wartość energetyczna',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3A262B),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _kcalController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                  hint: '61',
                  suffix: const Text(
                    'kcal / 100 g',
                    style: TextStyle(color: Color(0xFF8A7278), fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // --- DATA WAŻNOŚCI ---
              const Text(
                'Data ważności',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3A262B),
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFECDCE0), width: 1.2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDate(_selectedDate),
                        style: TextStyle(
                          fontSize: 15,
                          color: _selectedDate == null
                              ? const Color(0xFFB59BA2)
                              : const Color(0xFF3A262B),
                        ),
                      ),
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: Color(0xFF9E4263),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // --- ILOŚĆ I JEDNOSTKA OBOK SIEBIE ---
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ilość',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3A262B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration(hint: '150'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Jednostka',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3A262B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedUnit,
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Color(0xFF9E4263),
                          ),
                          decoration: _inputDecoration(hint: 'g'),
                          items: _units.map((u) {
                            return DropdownMenuItem(value: u, child: Text(u));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedUnit = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),

              // --- PRZYCISK ZAPISU ---
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9E4263),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isSaving ? null : _saveProduct,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add, size: 22),
                  label: const Text(
                    'Dodaj do lodówki',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'Wszystko gotowe? Czas schować coś dobrego.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9E7F87)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
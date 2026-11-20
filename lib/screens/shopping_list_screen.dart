import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../helpers/product_helpers.dart';
import 'add_product_page.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _itemAmountController = TextEditingController(text: '1');
  final ScrollController _scrollController = ScrollController();

  final _units = ['szt.', 'g', 'kg', 'ml', 'l'];
  String _selectedUnit = '';

  bool _isEditingEssentials = false;

  late final Stream<QuerySnapshot> _shoppingStream;
  late final Stream<QuerySnapshot> _fridgeStream;
  late final Stream<QuerySnapshot> _essentialsStream;

  // Domyślne 7 produktów (wgrywane automatycznie, jeśli kolekcja 'podstawy' jest pusta)
  final _defaultEssentials = [
    {'nazwa': 'Mleko', 'ilosc': '1 l', 'ikona': '🥛'},
    {'nazwa': 'Masło', 'ilosc': '200 g', 'ikona': '🧈'},
    {'nazwa': 'Jajka', 'ilosc': '10 szt.', 'ikona': '🥚'},
    {'nazwa': 'Jogurt', 'ilosc': '150 g', 'ikona': '🥛'},
    {'nazwa': 'Pieczywo', 'ilosc': '1 szt.', 'ikona': '🍞'},
    {'nazwa': 'Ser żółty', 'ilosc': '200 g', 'ikona': '🧀'},
    {'nazwa': 'Pomidory', 'ilosc': '3 szt.', 'ikona': '🍅'},
  ];

  @override
  void initState() {
    super.initState();
    _shoppingStream = FirebaseFirestore.instance.collection('zakupy').snapshots();
    _fridgeStream = FirebaseFirestore.instance.collection('lodowka').snapshots();
    _essentialsStream = FirebaseFirestore.instance.collection('podstawy').snapshots();
    _seedDefaultEssentialsIfEmpty();
  }

  Future<void> _seedDefaultEssentialsIfEmpty() async {
    final snap = await FirebaseFirestore.instance.collection('podstawy').limit(1).get();
    if (snap.docs.isEmpty) {
      for (final item in _defaultEssentials) {
        await FirebaseFirestore.instance.collection('podstawy').add(item);
      }
    }
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _itemAmountController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _addToShoppingList(String nazwa, String ilosc, {String notatka = ''}) async {
    final cleanName = nazwa.trim();
    if (cleanName.isEmpty) return;

    await FirebaseFirestore.instance.collection('zakupy').add({
      'nazwa': cleanName,
      'ilosc': ilosc.trim().isEmpty ? '1' : ilosc.trim(),
      'notatka': notatka,
      'w_koszyku': false,
      'utworzono': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dopisano do listy: $cleanName')),
      );
    }
  }

  // Okienko do dodawania lub edycji produktu na liście "Zawsze w lodówce"
  void _showEssentialDialog({String? docId, String initialName = '', String initialAmount = '1'}) {
    final nameCtrl = TextEditingController(text: initialName);

    String parsedNumber = initialAmount.trim();
    String selectedUnit = '';

    for (final u in _units) {
      if (parsedNumber.endsWith(' $u')) {
        selectedUnit = u;
        parsedNumber = parsedNumber.substring(0, parsedNumber.length - u.length - 1).trim();
        break;
      } else if (parsedNumber.endsWith(u) && parsedNumber != u) {
        selectedUnit = u;
        parsedNumber = parsedNumber.substring(0, parsedNumber.length - u.length).trim();
        break;
      }
    }

    final amountCtrl = TextEditingController(text: parsedNumber.isEmpty ? '1' : parsedNumber);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFDF8F6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            docId == null ? 'Dodaj stały produkt' : 'Edytuj stały produkt',
            style: const TextStyle(color: Color(0xFF3A262B), fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: _inputDecoration('Nazwa (np. Twaróg)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('Ilość (np. 250)'),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _units.map((unit) {
                  final isSelected = selectedUnit == unit;
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        selectedUnit = isSelected ? '' : unit;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF9E4263) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF9E4263) : const Color(0xFFECDCE0),
                        ),
                      ),
                      child: Text(
                        unit,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF5A4349),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Anuluj', style: TextStyle(color: Color(0xFF8A7278))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9E4263),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final nazwa = nameCtrl.text.trim();
                final rawAmount = amountCtrl.text.trim().isEmpty ? '1' : amountCtrl.text.trim();
                final ilosc = selectedUnit.isEmpty ? rawAmount : '$rawAmount $selectedUnit';
                if (nazwa.isEmpty) return;

                final data = {
                  'nazwa': nazwa,
                  'ilosc': ilosc,
                  'ikona': getEmojiForProduct(null, nazwa),
                };

                if (docId == null) {
                  await FirebaseFirestore.instance.collection('podstawy').add(data);
                } else {
                  await FirebaseFirestore.instance.collection('podstawy').doc(docId).update(data);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Zapisz'),
            ),
          ],
        ),
      ),
    );
  }

  String _shortExpirationLabel(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expDate = timestamp.toDate();
    final expDay = DateTime(expDate.year, expDate.month, expDate.day);
    final diff = expDay.difference(today).inDays;

    if (diff < 0) return 'Po terminie';
    if (diff == 0) return 'Dzisiaj';
    if (diff == 1) return 'Jutro';
    return 'Za $diff dni';
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFB59BA2), fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFECDCE0), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
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
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- GÓRNY PASEK ---
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

              // --- POWRÓT ---
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
              const SizedBox(height: 6),

              // --- TYTUŁ ---
              const Text(
                'Lista zakupów',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3A262B),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'W sklepie odhaczaj i skanuj prosto do lodówki.',
                style: TextStyle(fontSize: 14, color: Color(0xFF8A7278)),
              ),
              const SizedBox(height: 18),

              // --- 1. CO DOPISAĆ DO LISTY? ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBE9EE),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Co dopisać do listy?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3A262B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Produkt',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5A4349)),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _itemNameController,
                                decoration: _inputDecoration('np. pieczywo'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ilość',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5A4349)),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _itemAmountController,
                                keyboardType: TextInputType.number,
                                decoration: _inputDecoration('1'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Opcjonalne jednostki (kliknij, aby dodać lub odznaczyć)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _units.map((unit) {
                        final isSelected = _selectedUnit == unit;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedUnit = isSelected ? '' : unit;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF9E4263) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF9E4263) : const Color(0xFFECDCE0),
                              ),
                            ),
                            child: Text(
                              unit,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF5A4349),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9E4263),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          final amount = _itemAmountController.text.trim();
                          final baseAmount = amount.isEmpty ? '1' : amount;
                          final fullAmount = _selectedUnit.isEmpty ? baseAmount : '$baseAmount $_selectedUnit';
                          _addToShoppingList(_itemNameController.text, fullAmount);
                          setState(() {
                            _itemNameController.clear();
                            _itemAmountController.text = '1';
                            _selectedUnit = '';
                          });
                        },
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text(
                          'Dodaj do listy zakupów',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- 2. DO KUPIENIA & W KOSZYKU ---
              StreamBuilder<QuerySnapshot>(
                stream: _shoppingStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allItems = snapshot.data!.docs;
                  final toBuy = allItems.where((d) => (d.data() as Map<String, dynamic>)['w_koszyku'] != true).toList();
                  final inCart = allItems.where((d) => (d.data() as Map<String, dynamic>)['w_koszyku'] == true).toList();
                  final double progress = allItems.isEmpty ? 0 : inCart.length / allItems.length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // DO KUPIENIA
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Do kupienia',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF3A262B)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBE9EE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${toBuy.length} produkty',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF9E4263)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Zaznacz produkt lub kliknij aparat, aby zeskanować go do lodówki.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF8A7278)),
                      ),
                      const SizedBox(height: 12),

                      if (toBuy.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFF2E2E6)),
                          ),
                          child: const Text(
                            'Lista do kupienia jest pusta.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF9E7F87), fontSize: 13),
                          ),
                        )
                      else
                        ...toBuy.map((doc) => _buildShoppingTile(doc, false)),

                      const SizedBox(height: 22),

                      // W KOSZYKU
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'W koszyku',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3A262B)),
                          ),
                          Text(
                            '${inCart.length} z ${allItems.length} produktów',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF9E4263)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: const Color(0xFFF2DCE2),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9E4263)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (inCart.isNotEmpty) ...inCart.map((doc) => _buildShoppingTile(doc, true)),

                      const SizedBox(height: 8),
                      const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 15, color: Color(0xFF8A7278)),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Kliknij ikonę aparatu przy produkcie, aby zeskanować jego kod kreskowy i od razu dodać go do lodówki.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF8A7278), height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 26),

              // --- 3. ZAJRZYJ DO LODÓWKI ---
              const Text(
                'Zajrzyj do lodówki',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF3A262B)),
              ),
              const SizedBox(height: 12),

              StreamBuilder<QuerySnapshot>(
                stream: _fridgeStream,
                builder: (context, snapshot) {
                  final fridgeDocs = snapshot.data?.docs ?? [];

                  final withDates = fridgeDocs.where((d) {
                    return (d.data() as Map<String, dynamic>)['data_waznosci'] is Timestamp;
                  }).toList();

                  withDates.sort((a, b) {
                    final tsA = (a.data() as Map<String, dynamic>)['data_waznosci'] as Timestamp;
                    final tsB = (b.data() as Map<String, dynamic>)['data_waznosci'] as Timestamp;
                    return tsA.compareTo(tsB);
                  });
                  final top3 = withDates.take(3).toList();

                  final fridgeNames = fridgeDocs
                      .map((d) => ((d.data() as Map<String, dynamic>)['nazwa'] ?? '').toString().toLowerCase())
                      .toList();

                  return Column(
                    children: [
                      // Karta: Kończy się ważność
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBE9EE),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.schedule, color: Color(0xFF9E4263), size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Kończy się ważność',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3A262B)),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${top3.length}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF9E4263)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Najpierw wykorzystaj to, co masz. Nowe opakowanie możesz dopisać na później.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF7B6369)),
                            ),
                            const SizedBox(height: 12),
                            if (top3.isEmpty)
                              const Text('Brak produktów z krótkim terminem.', style: TextStyle(fontSize: 13, color: Color(0xFF8A7278)))
                            else
                              ...top3.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final nazwa = data['nazwa'] ?? '';
                                final gramy = data['ilosc_gram'] ?? 0;
                                final jednostka = data['jednostka'] ?? 'g';
                                final ikona = data['ikona'] ?? getEmojiForProduct(null, nazwa);
                                final ts = data['data_waznosci'] as Timestamp?;
                                final iloscStr = gramy > 0 ? '$gramy $jednostka' : '1 szt.';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(ikona, style: const TextStyle(fontSize: 24)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '$nazwa${gramy > 0 ? ' · $iloscStr' : ''}',
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF3A262B)),
                                            ),
                                            Text(
                                              _shortExpirationLabel(ts),
                                              style: const TextStyle(fontSize: 12, color: Color(0xFFB85D3B), fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => _addToShoppingList(nazwa, iloscStr, notatka: 'Uzupełnienie zapasów'),
                                        child: const Text(
                                          '+ Do listy',
                                          style: TextStyle(color: Color(0xFF9E4263), fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Karta: Zawsze w lodówce (EDYtOWALNA lista w Firebase)
                      StreamBuilder<QuerySnapshot>(
                        stream: _essentialsStream,
                        builder: (context, essSnapshot) {
                          final essentials = essSnapshot.data?.docs ?? [];

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFF0DCE2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.inventory_2_outlined, color: Color(0xFF9E4263), size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Zawsze w lodówce',
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF3A262B)),
                                        ),
                                      ],
                                    ),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        minimumSize: Size.zero,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () {
                                        setState(() => _isEditingEssentials = !_isEditingEssentials);
                                      },
                                      child: Text(
                                        _isEditingEssentials ? 'Gotowe' : 'Edytuj',
                                        style: const TextStyle(
                                          color: Color(0xFF9E4263),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Twoje podstawowe produkty. Dopisuj je jednym kliknięciem lub edytuj listę pod siebie.',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF8A7278)),
                                ),
                                const SizedBox(height: 12),
                                ...essentials.map((doc) {
                                  final item = doc.data() as Map<String, dynamic>;
                                  final String nazwa = item['nazwa'] ?? '';
                                  final String ilosc = item['ilosc'] ?? '1';
                                  final String ikona = item['ikona'] ?? getEmojiForProduct(null, nazwa);
                                  final bool isInFridge = fridgeNames.any((n) => n.contains(nazwa.toLowerCase()));

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: SizedBox(
                                      height: 36,
                                      child: Row(
                                        children: [
                                          Text(ikona, style: const TextStyle(fontSize: 20)),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  nazwa,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF3A262B)),
                                                ),
                                                Text(
                                                  isInFridge ? 'Masz w lodówce' : 'Brak w lodówce · $ilosc',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isInFridge ? const Color(0xFF3E6B48) : const Color(0xFFB85D3B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (_isEditingEssentials) ...[
                                            IconButton(
                                              constraints: const BoxConstraints(),
                                              padding: const EdgeInsets.all(6),
                                              icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF9E4263)),
                                              onPressed: () => _showEssentialDialog(
                                                docId: doc.id,
                                                initialName: nazwa,
                                                initialAmount: ilosc,
                                              ),
                                            ),
                                            IconButton(
                                              constraints: const BoxConstraints(),
                                              padding: const EdgeInsets.all(6),
                                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                              onPressed: () {
                                                FirebaseFirestore.instance.collection('podstawy').doc(doc.id).delete();
                                              },
                                            ),
                                          ] else
                                            TextButton(
                                              style: TextButton.styleFrom(
                                                minimumSize: Size.zero,
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              onPressed: () => _addToShoppingList(nazwa, ilosc, notatka: 'Podstawowy produkt'),
                                              child: const Text(
                                                '+ Do listy',
                                                style: TextStyle(color: Color(0xFF9E4263), fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                                if (_isEditingEssentials) ...[
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF9E4263),
                                        side: const BorderSide(color: Color(0xFF9E4263)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => _showEssentialDialog(),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('Dodaj produkt do podstaw'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.eco_outlined, size: 15, color: Color(0xFF3E6B48)),
                    SizedBox(width: 6),
                    Text(
                      'Dobrze kupić. Mniej zmarnować.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF8A7278)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShoppingTile(QueryDocumentSnapshot doc, bool isInCart) {
    final data = doc.data() as Map<String, dynamic>;
    final String nazwa = data['nazwa'] ?? '';
    final String ilosc = data['ilosc'] ?? '';
    final String notatka = data['notatka'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isInCart ? const Color(0xFFF9E6EC) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isInCart ? const Color(0xFFF0D0DA) : const Color(0xFFF3E4E8),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: isInCart,
            activeColor: const Color(0xFF9E4263),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            onChanged: (val) {
              FirebaseFirestore.instance.collection('zakupy').doc(doc.id).update({
                'w_koszyku': val ?? false,
              });
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nazwa,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isInCart ? const Color(0xFF7B6369) : const Color(0xFF3A262B),
                  ),
                ),
                if (isInCart || notatka.isNotEmpty)
                  Text(
                    isInCart ? 'Do zeskanowania do lodówki' : notatka,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF8A7278)),
                  ),
              ],
            ),
          ),
          Text(
            ilosc,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF5A4349)),
          ),
          const SizedBox(width: 4),
          // IKONKA APARATU -> przejście do dodawania z wypełnionymi danymi
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined, size: 20, color: Color(0xFF9E4263)),
            tooltip: 'Zeskanuj i dodaj do lodówki',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddProductPage(
                    title: 'Dodaj produkt',
                    initialName: nazwa,
                    initialAmount: ilosc,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Color(0xFFB59BA2)),
            onPressed: () {
              FirebaseFirestore.instance.collection('zakupy').doc(doc.id).delete();
            },
          ),
        ],
      ),
    );
  }
}
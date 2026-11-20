import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../helpers/product_helpers.dart';
import 'add_product_page.dart';
import 'expiring_screen.dart';
import 'fridge_interior_screen.dart';
import 'shopping_list_screen.dart';

class FridgeScreen extends StatelessWidget {
  const FridgeScreen({super.key});

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
    if (diff <= 6) return 'Za $diff dni';
    final day = expDate.day.toString().padLeft(2, '0');
    final month = expDate.month.toString().padLeft(2, '0');
    return '$day.$month';
  }

  bool _isExpiringSoon(Timestamp? timestamp) {
    if (timestamp == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expDate = timestamp.toDate();
    final expDay = DateTime(expDate.year, expDate.month, expDate.day);
    return expDay.difference(today).inDays <= 3;
  }

  void _showProductDetails(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String nazwa = data['nazwa'] ?? 'Bez nazwy';
    final String marka = data['marka'] ?? 'Brak';
    final String typ = data['typ'] ?? 'Inne';
    final int gramy = data['ilosc_gram'] ?? 0;
    final String jednostka = data['jednostka'] ?? 'g';
    final String ikona = data['ikona'] ?? getEmojiForProduct(null, nazwa);
    final Timestamp? dataWaznosci = data['data_waznosci'] as Timestamp?;
    final expInfo = formatExpirationDate(dataWaznosci);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFDF8F6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ikona, style: const TextStyle(fontSize: 52)),
              const SizedBox(height: 8),
              Text(
                nazwa,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3A262B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$typ • Marka: $marka${gramy > 0 ? ' • $gramy $jednostka' : ''}',
                style: const TextStyle(fontSize: 14, color: Color(0xFF8A7278)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Termin ważności: ${expInfo['text']}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: expInfo['color'],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFDE8EC),
                    foregroundColor: const Color(0xFFB3261E),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text(
                    'Usuń z lodówki',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('lodowka')
                        .doc(doc.id)
                        .delete();
                    if (ctx.mounted) Navigator.pop(ctx);
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F6),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('lodowka').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Błąd pobierania danych z bazy.'));
            }

            final allDocs = List<QueryDocumentSnapshot>.from(snapshot.data?.docs ?? []);

            final nabial = allDocs.where((d) {
              final typ = ((d.data() as Map<String, dynamic>)['typ'] ?? '').toString().toLowerCase();
              return typ == 'nabiał';
            }).toList();

            final warzywa = allDocs.where((d) {
              final typ = ((d.data() as Map<String, dynamic>)['typ'] ?? '').toString().toLowerCase();
              return typ == 'warzywa';
            }).toList();

            final inne = allDocs.where((d) {
              final typ = ((d.data() as Map<String, dynamic>)['typ'] ?? '').toString().toLowerCase();
              return typ != 'nabiał' && typ != 'warzywa';
            }).toList();

            final withDates = allDocs.where((d) {
              final ts = (d.data() as Map<String, dynamic>)['data_waznosci'];
              return ts is Timestamp;
            }).toList();

            withDates.sort((a, b) {
              final tsA = (a.data() as Map<String, dynamic>)['data_waznosci'] as Timestamp;
              final tsB = (b.data() as Map<String, dynamic>)['data_waznosci'] as Timestamp;
              return tsA.compareTo(tsB);
            });

            final top3Expiring = withDates.take(3).toList();

            return Column(
              children: [
                // --- GÓRNY NAGŁÓWEK ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Moja lodówka',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3A262B),
                                  height: 1.1,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Dobre rzeczy masz pod ręką.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF8A7278),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${allDocs.length} produktów',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8A7278),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // --- GŁÓWNA LODÓWKA (WNĘTRZE + DRZWICZKI) ---
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // LEWA STRONA: WNĘTRZE LODÓWKI (przewijane w środku)
                        Expanded(
                          flex: 6,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDF3F5),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: const Color(0xFFEDAAC0),
                                width: 6,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Pasek temperatury u góry lodówki
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Świeżo i na miejscu',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF9E4263),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        '4°C',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF3E6B48),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Scrollowane półki wewnątrz ramki
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildShelf(context, 'NABIAŁ', nabial),
                                        _buildShelf(context, 'WARZYWA', warzywa),
                                        _buildShelf(context, 'JESZCZE COŚ DOBREGO', inne),
                                        const SizedBox(height: 6),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF5E6E4),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: const Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.eco_outlined, size: 14, color: Color(0xFF3E6B48)),
                                                  SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      'Mniej marnowania',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFF3A262B),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Najpierw sięgnij po produkty z krótkim terminem.',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Color(0xFF7B6369),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // PRZYCISK: Zobacz wszystko -> (otwiera pełne Wnętrze lodówki)
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const FridgeInteriorScreen(),
                                      ),
                                    );
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Zobacz wszystko',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF9E4263),
                                          ),
                                        ),
                                        Icon(Icons.arrow_forward, size: 14, color: Color(0xFF9E4263)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // PRAWA STRONA: DRZWICZKI LODÓWKI
                        Expanded(
                          flex: 4,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9E1E8),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFFEDAAC0),
                                width: 5,
                              ),
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'POD RĘKĄ',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: Color(0xFF9E4263),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Puste miejsce 1 (na Przepisy)
                                  const SizedBox(height: 75),
                                  _buildDoorShelfDivider(),
                                  const SizedBox(height: 16),

                                  // Puste miejsce 2 (na Listę zakupów)
                                  // Półka 2: LISTA ZAKUPÓW
InkWell(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ShoppingListScreen(),
      ),
    );
  },
  child: const Padding(
    padding: EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(Icons.shopping_basket_outlined, color: Color(0xFF9E4263), size: 22),
            Icon(Icons.chevron_right, color: Color(0xFF9E4263), size: 18),
          ],
        ),
        SizedBox(height: 8),
        Text(
          'Lista zakupów',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3A262B),
          ),
        ),
        SizedBox(height: 2),
        Text(
          'Odhaczaj w sklepie',
          style: TextStyle(fontSize: 11, color: Color(0xFF8A7278)),
        ),
      ],
    ),
  ),
),

                                  // Półka 3: KOŃCZY SIĘ WAŻNOŚĆ
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Icon(Icons.schedule, color: Color(0xFF9E4263), size: 22),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF9E4263),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '${top3Expiring.length}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Kończy się\nważność',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF3A262B),
                                      height: 1.15,
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  if (top3Expiring.isEmpty)
                                    const Text(
                                      'Brak produktów z datą',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF8A7278)),
                                    )
                                  else
                                    ...top3Expiring.map((doc) {
                                      final data = doc.data() as Map<String, dynamic>;
                                      final nazwa = data['nazwa'] ?? '';
                                      final ts = data['data_waznosci'] as Timestamp?;
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                nazwa,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF3A262B),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _shortExpirationLabel(ts),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFFB85D3B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),

                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const ExpiringScreen(),
                                        ),
                                      );
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Zobacz wszystkie',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF9E4263),
                                            ),
                                          ),
                                          Icon(Icons.arrow_forward, size: 13, color: Color(0xFF9E4263)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _buildDoorShelfDivider(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // --- DOLNA SEKCJA Z PRZYCISKIEM ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                  child: Column(
                    children: [
                      const Text(
                        'Dotknij produktu, aby zobaczyć szczegóły',
                        style: TextStyle(fontSize: 11, color: Color(0xFF8A7278)),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9E4263),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
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
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text(
                            'Dodaj produkt',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Zeskanuj kod lub wpisz nazwę produktu',
                        style: TextStyle(fontSize: 11, color: Color(0xFF9E7F87)),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildShelf(BuildContext context, String title, List<QueryDocumentSnapshot> docs) {
    final List<Widget> rows = [];
    for (int i = 0; i < docs.length; i += 2) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Expanded(child: _buildProductCard(context, docs[i])),
              const SizedBox(width: 6),
              Expanded(
                child: i + 1 < docs.length
                    ? _buildProductCard(context, docs[i + 1])
                    : const SizedBox(),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Color(0xFF9E7F87),
            ),
          ),
          const SizedBox(height: 6),
          if (docs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text(
                  'Pusta półka',
                  style: TextStyle(fontSize: 11, color: Color(0xFFB59BA2)),
                ),
              ),
            )
          else
            ...rows,
          const SizedBox(height: 2),
          Container(
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFE5B5C5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String nazwa = data['nazwa'] ?? 'Bez nazwy';
    final String ikona = data['ikona'] ?? getEmojiForProduct(null, nazwa);
    final int gramy = data['ilosc_gram'] ?? 0;
    final String jednostka = data['jednostka'] ?? 'g';
    final Timestamp? ts = data['data_waznosci'] as Timestamp?;
    final shortDate = _shortExpirationLabel(ts);
    final urgent = _isExpiringSoon(ts);

    String subtitle = '';
    if (gramy > 0) subtitle += '$gramy $jednostka';
    if (shortDate.isNotEmpty) {
      subtitle += subtitle.isEmpty ? shortDate : ' · $shortDate';
    }

    return GestureDetector(
      onTap: () => _showProductDetails(context, doc),
      child: Container(
        height: 92,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: urgent ? const Color(0xFFE6B89C) : const Color(0xFFF3E4E8),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(ikona, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 4),
            Text(
              nazwa,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3A262B),
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: urgent ? FontWeight.w600 : FontWeight.normal,
                  color: urgent ? const Color(0xFFB85D3B) : const Color(0xFF8A7278),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDoorShelfDivider() {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFFDF9EB4),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
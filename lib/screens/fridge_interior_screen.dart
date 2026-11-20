import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../helpers/product_helpers.dart';

class FridgeInteriorScreen extends StatelessWidget {
  const FridgeInteriorScreen({super.key});

  Map<String, dynamic> _getExpirationBadge(Timestamp? timestamp) {
    if (timestamp == null) {
      return {'hasDate': false, 'text': 'Nie podano daty'};
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expDate = timestamp.toDate();
    final expDay = DateTime(expDate.year, expDate.month, expDate.day);
    final diff = expDay.difference(today).inDays;

    if (diff < 0) {
      return {
        'hasDate': true,
        'text': '• Po terminie',
        'bgColor': const Color(0xFFFDE8EC),
        'textColor': const Color(0xFFB3261E),
      };
    } else if (diff == 0) {
      return {
        'hasDate': true,
        'text': '• Termin: dzisiaj',
        'bgColor': const Color(0xFFFFEFE0),
        'textColor': const Color(0xFFD84315),
      };
    } else if (diff == 1) {
      return {
        'hasDate': true,
        'text': '• Termin: jutro',
        'bgColor': const Color(0xFFFFF1E6),
        'textColor': const Color(0xFFB85D3B),
      };
    } else if (diff <= 6) {
      return {
        'hasDate': true,
        'text': '• Termin: za $diff dni',
        'bgColor': const Color(0xFFFFF1E6),
        'textColor': const Color(0xFFB85D3B),
      };
    } else {
      final day = expDate.day.toString().padLeft(2, '0');
      final month = expDate.month.toString().padLeft(2, '0');
      return {
        'hasDate': true,
        'text': '• $day.$month.${expDate.year}',
        'bgColor': const Color(0xFFF3F6F1),
        'textColor': const Color(0xFF4A6B4E),
      };
    }
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

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- GÓRNY NAGŁÓWEK ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
                      const SizedBox(height: 10),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Wnętrze lodówki',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3A262B),
                                  height: 1.1,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Wszystko, co masz. Teraz z bliska.',
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

                // --- PEŁNOEKRANOWA RAMKA LODÓWKI (SCROLLOWANA W ŚRODKU) ---
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF3F5),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: const Color(0xFFEDAAC0),
                          width: 7,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Pasek temperatury na górze lodówki
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Świeżo i na miejscu',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF9E4263),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.thermostat, size: 14, color: Color(0xFF3E6B48)),
                                    SizedBox(width: 2),
                                    Text(
                                      '4°C',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF3E6B48),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Scrollowane półki wewnątrz ramki
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildShelf(context, 'NABIAŁ', nabial),
                                  _buildShelf(context, 'WARZYWA', warzywa),
                                  _buildShelf(context, 'JESZCZE COŚ DOBREGO', inne),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5E6E4),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.eco_outlined, size: 16, color: Color(0xFF3E6B48)),
                                            SizedBox(width: 6),
                                            Text(
                                              'Mniej marnowania',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF3A262B),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Najpierw sięgnij po produkty z krótkim terminem.',
                                          style: TextStyle(
                                            fontSize: 12,
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
                        ],
                      ),
                    ),
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
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(child: _buildLargeProductCard(context, docs[i])),
              const SizedBox(width: 10),
              Expanded(
                child: i + 1 < docs.length
                    ? _buildLargeProductCard(context, docs[i + 1])
                    : const SizedBox(),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Color(0xFF9E7F87),
            ),
          ),
          const SizedBox(height: 8),
          if (docs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: Text(
                  'Pusta półka',
                  style: TextStyle(fontSize: 12, color: Color(0xFFB59BA2)),
                ),
              ),
            )
          else
            ...rows,
          const SizedBox(height: 2),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFE5B5C5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeProductCard(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String nazwa = data['nazwa'] ?? 'Bez nazwy';
    final String ikona = data['ikona'] ?? getEmojiForProduct(null, nazwa);
    final int gramy = data['ilosc_gram'] ?? 0;
    final String jednostka = data['jednostka'] ?? 'g';
    final Timestamp? ts = data['data_waznosci'] as Timestamp?;
    final badge = _getExpirationBadge(ts);

    return GestureDetector(
      onTap: () => _showProductDetails(context, doc),
      child: Container(
        constraints: const BoxConstraints(minHeight: 162),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: badge['hasDate'] == true
                ? const Color(0xFFEBD0BE)
                : const Color(0xFFF3E4E8),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(ikona, style: const TextStyle(fontSize: 38)),
            const SizedBox(height: 8),
            Text(
              nazwa,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3A262B),
              ),
            ),
            if (gramy > 0) ...[
              const SizedBox(height: 2),
              Text(
                '$gramy $jednostka',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8A7278),
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (badge['hasDate'] == true)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badge['bgColor'],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge['text'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badge['textColor'],
                  ),
                ),
              )
            else
              Text(
                badge['text'],
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFA89399),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
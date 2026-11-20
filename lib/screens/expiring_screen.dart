import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../helpers/product_helpers.dart';

class ExpiringScreen extends StatelessWidget {
  const ExpiringScreen({super.key});

  // Formatowanie terminu dokładnie pod makietę z Figmy
  Map<String, dynamic> _getFigmaExpirationStyle(Timestamp? timestamp) {
    if (timestamp == null) {
      return {
        'label': 'Brak daty',
        'sublabel': null,
        'bgColor': const Color(0xFFF3ECEF),
        'textColor': const Color(0xFF8A7278),
      };
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expDate = timestamp.toDate();
    final expDay = DateTime(expDate.year, expDate.month, expDate.day);
    final diff = expDay.difference(today).inDays;

    if (diff < -1) {
      return {
        'label': 'Po terminie',
        'sublabel': '${-diff} dni temu',
        'bgColor': const Color(0xFFFDE8EC),
        'textColor': const Color(0xFFB3261E),
      };
    } else if (diff == -1) {
      return {
        'label': 'Po terminie',
        'sublabel': 'Wczoraj',
        'bgColor': const Color(0xFFFDE8EC),
        'textColor': const Color(0xFFB3261E),
      };
    } else if (diff == 0) {
      return {
        'label': 'Dzisiaj',
        'sublabel': null,
        'bgColor': const Color(0xFFFFEFE0),
        'textColor': const Color(0xFFD84315),
      };
    } else if (diff == 1) {
      return {
        'label': 'Jutro',
        'sublabel': null,
        'bgColor': const Color(0xFFFFF4E5),
        'textColor': const Color(0xFFE65100),
      };
    } else if (diff <= 7) {
      return {
        'label': 'Za $diff dni',
        'sublabel': null,
        'bgColor': const Color(0xFFFFF8E1),
        'textColor': const Color(0xFF9E6B00),
      };
    } else {
      final day = expDate.day.toString().padLeft(2, '0');
      final month = expDate.month.toString().padLeft(2, '0');
      return {
        'label': 'Za $diff dni',
        'sublabel': '$day.$month.${expDate.year}',
        'bgColor': const Color(0xFFF3F6F1),
        'textColor': const Color(0xFF4A6B4E),
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F6), // Kremowe tło z Figmy
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDF8F6),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF9E4263), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Moja lodówka',
          style: TextStyle(
            color: Color(0xFF9E4263),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        titleSpacing: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nagłówek ekranu
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kończy się ważność',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3A262B),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Wszystkie terminy w jednym miejscu.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF8A7278),
                  ),
                ),
              ],
            ),
          ),

          // Nagłówki tabeli: PRODUKT | TERMIN WAŻNOŚCI
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PRODUKT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Color(0xFF9E7F87),
                  ),
                ),
                Text(
                  'TERMIN WAŻNOŚCI',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Color(0xFF9E7F87),
                  ),
                ),
              ],
            ),
          ),

          // Lista produktów z Firebase
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('lodowka').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Błąd pobierania danych.'));
                }

                final docs = List<QueryDocumentSnapshot>.from(snapshot.data?.docs ?? []);

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Brak produktów w lodówce.',
                      style: TextStyle(color: Color(0xFF8A7278), fontSize: 16),
                    ),
                  );
                }

                // Sortowanie od najkrótszej daty ważności (brak daty na sam koniec)
                docs.sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>;
                  final dataB = b.data() as Map<String, dynamic>;
                  final tsA = dataA['data_waznosci'] as Timestamp?;
                  final tsB = dataB['data_waznosci'] as Timestamp?;

                  if (tsA == null && tsB == null) return 0;
                  if (tsA == null) return 1;
                  if (tsB == null) return -1;
                  return tsA.compareTo(tsB);
                });

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final String nazwa = data['nazwa'] ?? 'Bez nazwy';
                    final String ikona = data['ikona'] ?? getEmojiForProduct(null, nazwa);
                    final int gramy = data['ilosc_gram'] ?? 0;
                    final String jednostka = data['jednostka'] ?? 'g';
                    final Timestamp? dataWaznosci = data['data_waznosci'] as Timestamp?;
                    final expStyle = _getFigmaExpirationStyle(dataWaznosci);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFF2DCE2), width: 1),
                      ),
                      child: Row(
                        children: [
                          Text(ikona, style: const TextStyle(fontSize: 28)),
                          const SizedBox(width: 14),
                          // Nazwa i ilość
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nazwa,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF3A262B),
                                  ),
                                ),
                                if (gramy > 0) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '$gramy $jednostka',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF8A7278),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Pigułka z terminem ważności
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: expStyle['bgColor'],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  expStyle['label'],
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: expStyle['textColor'],
                                  ),
                                ),
                                if (expStyle['sublabel'] != null)
                                  Text(
                                    expStyle['sublabel'],
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: expStyle['textColor'],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
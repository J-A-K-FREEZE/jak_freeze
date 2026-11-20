import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

// --- 1. FUNKCJA DO POBIERANIA DANYCH Z OPEN FOOD FACTS ---
Future fetchProductFromApi(String barcode) async {
  final url = Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json');
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
  if (text.contains('milk') || text.contains('mlek') || text.contains('yogurt') || text.contains('jogur') || text.contains('kefir') || text.contains('śmietan')) return '🥛';

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

// --- 4. WYSZUKIWANIE PRODUKTÓW PO NAZWIE (OPEN FOOD FACTS PL) ---
Future searchProductsByName(String query) async {
  if (query.trim().length < 2) return [];

  final encoded = Uri.encodeQueryComponent(query.trim());
  final url = Uri.parse(
    'https://pl.openfoodfacts.org/cgi/search.pl?search_terms=$encoded&search_simple=1&action=process&json=1&page_size=6',
  );

  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List products = data['products'] ?? [];

      return products
          .where((p) => (p['product_name'] ?? '').toString().trim().isNotEmpty)
          .map((p) {
        final String name = (p['product_name'] ?? '').toString().trim();
        final String brand = (p['brands'] ?? '').toString().trim();
        final List<dynamic>? categories = p['categories_tags'];
        final nutriments = p['nutriments'] as Map<String, dynamic>?;
        final dynamic kcalRaw = nutriments?['energy-kcal_100g'];
        final int? kcal = kcalRaw is num ? kcalRaw.round() : int.tryParse(kcalRaw?.toString() ?? '');

        return {
          'name': name,
          'brand': brand,
          'kcal': kcal,
          'image': p['image_front_url'] ?? '',
          'emoji': getEmojiForProduct(categories, name),
        };
      }).toList();
    }
  } catch (e) {
    debugPrint('Błąd wyszukiwania: $e');
  }
  return [];
}
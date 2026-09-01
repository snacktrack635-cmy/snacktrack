import 'dart:convert';
import 'dart:io';

class BarcodeProductResult {
  final String barcode;
  final String name;
  final String? category;
  final String? imageUrl;
  final String? brand;

  const BarcodeProductResult({
    required this.barcode,
    required this.name,
    this.category,
    this.imageUrl,
    this.brand,
  });
}

class BarcodeRepository {
  final HttpClient _httpClient;

  BarcodeRepository({HttpClient? httpClient}) : _httpClient = httpClient ?? HttpClient();

  /// Looks up a barcode in Open Food Facts API (free, no key required)
  Future<BarcodeProductResult?> lookupBarcode(String barcode) async {
    try {
      final uri = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$barcode.json?fields=product_name,categories,image_url,brands',
      );

      final request = await _httpClient.getUrl(uri);
      request.headers.set('User-Agent', 'SnackTrack - Flutter Pantry App');
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final data = jsonDecode(responseBody) as Map<String, dynamic>;

        if (data['status'] == 1 && data['product'] != null) {
          final product = data['product'] as Map<String, dynamic>;
          final name = product['product_name'] as String? ?? 'Scanned Product';
          final categories = product['categories'] as String?;
          final category = categories?.split(',').first.trim();
          final imageUrl = product['image_url'] as String?;
          final brand = product['brands'] as String?;

          return BarcodeProductResult(
            barcode: barcode,
            name: name,
            category: category,
            imageUrl: imageUrl,
            brand: brand,
          );
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

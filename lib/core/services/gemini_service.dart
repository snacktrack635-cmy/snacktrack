import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/ai_food_scan_result.dart';
import '../constants/app_constants.dart';
import '../errors/exceptions.dart';
import '../network/supabase_client.dart';

/// Service for multimodal AI food item scanning and approximate expiry estimation
/// powered by Google Gemini.
///
/// Follows the architecture outlined in `context/pantry_tracker_architecture.md`:
/// - Primary mode: Calls Supabase Edge Function (`scan-food-item`) to enforce subscription
///   quotas and keep the Gemini API key secure on the backend.
/// - Direct mode: Can optionally call Google Generative Language REST API directly if an
///   API key is supplied (e.g. for development, testing, or standalone builds).
class GeminiService {
  final SupabaseClient? _supabaseClient;
  final String? _directApiKey;
  final String _modelName;

  GeminiService({
    SupabaseClient? supabaseClient,
    String? directApiKey,
    String modelName = AppConstants.geminiDefaultModel,
  })  : _supabaseClient = supabaseClient,
        _directApiKey = directApiKey,
        _modelName = modelName;

  /// Scans a food item from an image file or bytes using Gemini multimodal vision.
  ///
  /// Returns an [AiFoodScanResult] containing:
  /// - Food item name (e.g., "Honeycrisp Apples", "Whole Milk")
  /// - Categorization (e.g., "Produce", "Dairy", "Bakery")
  /// - Approximate expiry date & shelf life days
  /// - Freshness observations & storage advice
  /// - Estimated quantity and unit
  Future<AiFoodScanResult> scanFoodItem({
    File? imageFile,
    String? imagePath,
    Uint8List? imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    try {
      // 1. Resolve and compress image bytes
      final rawBytes = await _resolveAndCompressImage(
        imageFile: imageFile,
        imagePath: imagePath,
        imageBytes: imageBytes,
      );

      if (rawBytes == null || rawBytes.isEmpty) {
        throw const ScanException('Could not read image data for AI food scanning.');
      }

      final base64Image = base64Encode(rawBytes);

      // 2. Invoke via Supabase Edge Function if authenticated client is available
      if (_supabaseClient != null) {
        try {
          return await _scanViaEdgeFunction(
            base64Image: base64Image,
            mimeType: mimeType,
            imagePath: imagePath ?? imageFile?.path,
          );
        } on QuotaExceededException {
          rethrow;
        } catch (edgeError) {
          debugPrint('⚠️ [GeminiService] Edge Function unavailable or failed ($edgeError). Checking fallback...');
          final directKey = _directApiKey;
          if (directKey != null && directKey.isNotEmpty) {
            try {
              return await _scanViaDirectGeminiApi(
                base64Image: base64Image,
                mimeType: mimeType,
                imagePath: imagePath ?? imageFile?.path,
              );
            } catch (directErr) {
              debugPrint('⚠️ [GeminiService] Direct Gemini API failed: $directErr');
            }
          }

          // Check if the Edge Function itself is not deployed on Supabase gateway
          final errorStr = edgeError.toString();
          final isFunctionRouteNotFound = errorStr.contains('Requested function was not found') ||
              (errorStr.contains('NOT_FOUND') && !errorStr.contains('Gemini API'));
          if (isFunctionRouteNotFound) {
            debugPrint('⚠️ [GeminiService] Edge function "${AppConstants.scanFoodItemFunction}" not deployed on Supabase gateway. Falling back to review item.');
            return _generateVisualScanFallback(imagePath: imagePath ?? imageFile?.path);
          }

          if (edgeError is FunctionsHttpException) {
            final details = edgeError.details;
            final message = (details is Map && details['error'] != null)
                ? details['error'].toString()
                : (details?.toString() ?? edgeError.toString());
            debugPrint('❌ [GeminiService] Edge Function execution error (${edgeError.status}): $message');
            throw ServerException(message, code: edgeError.status.toString());
          }

          if (edgeError is AppException) rethrow;
          throw ServerException('Failed to scan food item with AI: $edgeError');
        }
      }

      // 3. Direct Gemini API call (fallback or standalone mode)
      final directKey = _directApiKey;
      if (directKey != null && directKey.isNotEmpty) {
        try {
          return await _scanViaDirectGeminiApi(
            base64Image: base64Image,
            mimeType: mimeType,
            imagePath: imagePath ?? imageFile?.path,
          );
        } catch (directErr) {
          debugPrint('⚠️ [GeminiService] Direct Gemini API failed: $directErr');
        }
      }

      // 4. Offline / Undeployed fallback: allow manual confirmation without blocking user
      return _generateVisualScanFallback(imagePath: imagePath ?? imageFile?.path);
    } catch (e, st) {
      AppSupabaseClient.logError('GeminiService.scanFoodItem', e, st);
      if (e is AppException) rethrow;
      throw ScanException('Failed to identify food item: $e');
    }
  }

  /// Estimates approximate expiry date and storage advice for a known food item name.
  /// Useful when an item is entered manually or via barcode lookup without an expiry date.
  Future<AiFoodScanResult> estimateExpiryForFoodName({
    required String foodName,
    String? category,
    String? storageLocation,
  }) async {
    try {
      if (_supabaseClient != null) {
        try {
          final response = await _supabaseClient.functions.invoke(
            AppConstants.scanFoodItemFunction,
            body: {
              'mode': 'text_estimate',
              'name': foodName,
              'category': category,
              'storage_location': storageLocation,
            },
          );

          if (response.status == 200 && response.data != null) {
            final data = response.data is Map<String, dynamic>
                ? response.data as Map<String, dynamic>
                : jsonDecode(response.data.toString()) as Map<String, dynamic>;
            return AiFoodScanResult.fromJson(data);
          }
        } catch (_) {
          // Fall through to direct call or fallback heuristic
        }
      }

      final directKey = _directApiKey;
      if (directKey != null && directKey.isNotEmpty) {
        final prompt = _buildTextEstimatePrompt(foodName, category, storageLocation);
        final jsonResult = await _queryDirectGeminiText(prompt);
        return AiFoodScanResult.fromJson(jsonResult);
      }

      // Heuristic fallback if offline
      return _generateHeuristicFallback(foodName, category);
    } catch (e, st) {
      AppSupabaseClient.logError('GeminiService.estimateExpiryForFoodName ($foodName)', e, st);
      return _generateHeuristicFallback(foodName, category);
    }
  }

  // ==========================================
  // Private Helpers & Implementations
  // ==========================================

  /// Invokes the `scan-food-item` Supabase Edge Function
  Future<AiFoodScanResult> _scanViaEdgeFunction({
    required String base64Image,
    required String mimeType,
    String? imagePath,
  }) async {
    final response = await _supabaseClient!.functions.invoke(
      AppConstants.scanFoodItemFunction,
      body: {
        'image': base64Image,
        'mime_type': mimeType,
        'mode': 'vision_scan',
      },
    );

    if (response.status == 429) {
      debugPrint('⚠️ [GeminiService] HTTP 429 Quota Exceeded');
      throw const QuotaExceededException('Monthly AI food scan quota reached. Upgrade your subscription to continue.');
    }

    if (response.status != 200) {
      final errorMsg = response.data?['error'] ?? 'AI food scanning failed.';
      throw ServerException(errorMsg.toString(), code: response.status.toString());
    }

    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : jsonDecode(response.data.toString()) as Map<String, dynamic>;

    return AiFoodScanResult.fromJson(data, imagePath: imagePath);
  }

  /// Calls the Gemini REST API directly with multimodal payload
  Future<AiFoodScanResult> _scanViaDirectGeminiApi({
    required String base64Image,
    required String mimeType,
    String? imagePath,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_modelName:generateContent?key=$_directApiKey',
    );

    final prompt = _buildVisionScanPrompt();

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Image,
              }
            }
          ]
        }
      ],
      'generationConfig': {
        'response_mime_type': 'application/json',
        'temperature': 0.2,
      }
    });

    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.write(body);
      final response = await request.close();

      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw ServerException('Gemini API returned status ${response.statusCode}: $responseBody');
      }

      final jsonResponse = jsonDecode(responseBody) as Map<String, dynamic>;
      final candidates = jsonResponse['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw const ScanException('Gemini returned empty response for this image.');
      }

      final text = candidates.first['content']?['parts']?[0]?['text'] as String?;
      if (text == null || text.trim().isEmpty) {
        throw const ScanException('No text content generated by Gemini vision.');
      }

      final cleanJson = _cleanJsonString(text);
      final parsed = jsonDecode(cleanJson) as Map<String, dynamic>;
      return AiFoodScanResult.fromJson(parsed, imagePath: imagePath);
    } finally {
      client.close();
    }
  }

  /// Text-only direct query to Gemini
  Future<Map<String, dynamic>> _queryDirectGeminiText(String prompt) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_modelName:generateContent?key=$_directApiKey',
    );

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'response_mime_type': 'application/json',
        'temperature': 0.2,
      }
    });

    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.write(body);
      final response = await request.close();

      final responseBody = await response.transform(utf8.decoder).join();
      final jsonResponse = jsonDecode(responseBody) as Map<String, dynamic>;
      final text = jsonResponse['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      if (text == null) throw const ServerException('Empty Gemini response.');

      return jsonDecode(_cleanJsonString(text)) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  /// Compresses images before transmission to keep latency and payload sizes small (<500KB)
  Future<Uint8List?> _resolveAndCompressImage({
    File? imageFile,
    String? imagePath,
    Uint8List? imageBytes,
  }) async {
    try {
      if (imagePath != null && imagePath.isNotEmpty) {
        final compressed = await FlutterImageCompress.compressWithFile(
          imagePath,
          minWidth: 1024,
          minHeight: 1024,
          quality: 80,
          format: CompressFormat.jpeg,
        );
        if (compressed != null) return compressed;
        return await File(imagePath).readAsBytes();
      }

      if (imageFile != null) {
        final compressed = await FlutterImageCompress.compressWithFile(
          imageFile.path,
          minWidth: 1024,
          minHeight: 1024,
          quality: 80,
          format: CompressFormat.jpeg,
        );
        if (compressed != null) return compressed;
        return await imageFile.readAsBytes();
      }

      if (imageBytes != null) {
        final compressed = await FlutterImageCompress.compressWithList(
          imageBytes,
          minWidth: 1024,
          minHeight: 1024,
          quality: 80,
          format: CompressFormat.jpeg,
        );
        if (compressed.isNotEmpty) return compressed;
        return imageBytes;
      }
    } catch (e) {
      debugPrint('⚠️ [GeminiService] Image compression failed, using original bytes: $e');
      if (imageFile != null) return await imageFile.readAsBytes();
      if (imagePath != null) return await File(imagePath).readAsBytes();
      return imageBytes;
    }
    return null;
  }

  String _cleanJsonString(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    return cleaned.trim();
  }

  String _buildVisionScanPrompt() {
    return '''
You are an expert culinary and food safety recognition AI.
Analyze this food image carefully and return a STRICT JSON object with these exact keys:
{
  "name": "Specific, clear food item name (e.g., 'Bananas', 'Whole Milk', 'Sourdough Loaf', 'Chicken Breast')",
  "category": "Standard category: 'Produce', 'Dairy', 'Bakery', 'Meat & Seafood', 'Pantry', 'Beverages', 'Snacks', or 'Frozen'",
  "days_until_expiry": <integer estimated days until this item expires or spoils based on its visible ripeness, freshness, bruising, and standard food shelf-life guidelines>,
  "confidence": <float between 0.0 and 1.0 indicating confidence in item detection>,
  "freshness_notes": "Concise 1-sentence observation of condition (e.g., 'Ripe yellow skin with minor brown spotting; eat soon.')",
  "suggested_storage": "Recommended storage location: 'pantry', 'refrigerator', or 'freezer'",
  "estimated_quantity": <float quantity, e.g. 1.0, 4.0, or null if uncertain>,
  "estimated_unit": "<unit string, e.g. 'pcs', 'bunch', 'bottle', 'kg', or 'carton'>"
}
Return valid JSON only. Do not include markdown or explanations.
''';
  }

  String _buildTextEstimatePrompt(String foodName, String? category, String? storageLocation) {
    return '''
Given the food item "$foodName"${category != null ? ' in category "$category"' : ''}${storageLocation != null ? ' stored in "$storageLocation"' : ''},
estimate its typical shelf life from today and return a STRICT JSON object:
{
  "name": "$foodName",
  "category": "${category ?? 'Pantry'}",
  "days_until_expiry": <integer estimated days until expiry>,
  "confidence": 0.9,
  "freshness_notes": "Estimated from standard food shelf-life tables.",
  "suggested_storage": "refrigerator",
  "estimated_quantity": 1.0,
  "estimated_unit": "pcs"
}
Return valid JSON only.
''';
  }

  AiFoodScanResult _generateHeuristicFallback(String foodName, String? category) {
    final lowerName = foodName.toLowerCase();
    int days = 7;
    String detectedCategory = category ?? 'Produce';

    if (lowerName.contains('milk') || lowerName.contains('yogurt') || lowerName.contains('cheese')) {
      days = 7;
      detectedCategory = 'Dairy';
    } else if (lowerName.contains('bread') || lowerName.contains('bakery') || lowerName.contains('croissant')) {
      days = 5;
      detectedCategory = 'Bakery';
    } else if (lowerName.contains('meat') || lowerName.contains('chicken') || lowerName.contains('beef') || lowerName.contains('fish')) {
      days = 3;
      detectedCategory = 'Meat & Seafood';
    } else if (lowerName.contains('apple') || lowerName.contains('orange') || lowerName.contains('citrus')) {
      days = 14;
      detectedCategory = 'Produce';
    } else if (lowerName.contains('banana') || lowerName.contains('berry') || lowerName.contains('spinach')) {
      days = 4;
      detectedCategory = 'Produce';
    } else if (lowerName.contains('can') || lowerName.contains('rice') || lowerName.contains('pasta') || lowerName.contains('flour')) {
      days = 365;
      detectedCategory = 'Pantry';
    }

    final now = DateTime.now();
    return AiFoodScanResult(
      name: foodName,
      category: detectedCategory,
      estimatedExpiryDate: DateTime(now.year, now.month, now.day).add(Duration(days: days)),
      daysUntilExpiry: days,
      confidence: 0.8,
      freshnessNotes: 'Calculated using typical shelf-life guidelines.',
      suggestedStorage: detectedCategory == 'Produce' || detectedCategory == 'Dairy' ? 'refrigerator' : 'pantry',
      estimatedQuantity: 1.0,
      estimatedUnit: 'pcs',
    );
  }

  AiFoodScanResult _generateVisualScanFallback({String? imagePath}) {
    final now = DateTime.now();
    const defaultDays = 5;
    return AiFoodScanResult(
      name: 'Fresh Food Item',
      category: 'Produce',
      estimatedExpiryDate: DateTime(now.year, now.month, now.day).add(const Duration(days: defaultDays)),
      daysUntilExpiry: defaultDays,
      confidence: 0.5,
      freshnessNotes: 'Edge Function not deployed on Supabase. Review details and adjust date.',
      suggestedStorage: 'refrigerator',
      estimatedQuantity: 1.0,
      estimatedUnit: 'pcs',
      imagePath: imagePath,
      rawResponse: const {'fallback': true},
    );
  }
}

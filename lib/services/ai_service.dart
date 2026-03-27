import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'api_service.dart';

/// Service for AI feature API calls with multipart file uploads.
/// Works on Web, Desktop, and Mobile — uses raw bytes, never dart:io File.
class AiService {
  /// Upload file bytes to an AI processing endpoint.
  ///
  /// [fileBytes] — the raw bytes of the file.
  /// [fileName] — the original file name (used by backend to detect format).
  static Future<Map<String, dynamic>> processFile({
    required String endpoint,
    required Uint8List fileBytes,
    required String fileName,
    Map<String, String>? extraFields,
  }) async {
    final uri = Uri.parse('${ApiService.baseUrl}/api/ai/$endpoint');

    final request = http.MultipartRequest('POST', uri);

    // Attach file as raw bytes — works on ALL platforms including Web
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
    ));

    // Attach any extra form fields (e.g., aspect_ratio for reframe)
    if (extraFields != null) {
      request.fields.addAll(extraFields);
    }

    // Add auth token if available
    final token = await ApiService.getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    // Send request
    final streamedResponse = await request.send().timeout(
      const Duration(minutes: 10),
    );

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'AI processing failed (${response.statusCode})');
    }
  }

  /// Get the full URL for a processed output file.
  static String getOutputUrl(String relativePath) {
    return '${ApiService.baseUrl}$relativePath';
  }
}

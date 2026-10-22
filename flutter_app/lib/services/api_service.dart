import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/product.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class SearchResponse {
  final List<Product> results;
  final double thresholdUsed;

  SearchResponse(this.results, this.thresholdUsed);
}

class ApiService {
  final Duration timeout = const Duration(seconds: 20);

  Future<List<String>> fetchColors() async {
    try {
      final response =
          await http.get(Uri.parse('$kBaseUrl/colors')).timeout(timeout);
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['colors'] as List).map((c) => c.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Uint8List> downloadBytes(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(timeout);
      if (response.statusCode != 200) {
        throw ApiException('Could not load that image');
      }
      return response.bodyBytes;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Request timed out. Is the server running?');
    } catch (_) {
      throw ApiException('Cannot reach server at $kBaseUrl');
    }
  }

  Future<SearchResponse> searchText(
    String query, {
    int topK = 12,
    String? color,
  }) async {
    final body = <String, dynamic>{'query': query, 'top_k': topK};
    if (color != null) body['color'] = color;
    try {
      final response = await http
          .post(
            Uri.parse('$kBaseUrl/search/text'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout);
      return _parse(response.statusCode, response.body);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Request timed out. Is the server running?');
    } catch (_) {
      throw ApiException('Cannot reach server at $kBaseUrl');
    }
  }

  Future<SearchResponse> searchImage(
    Uint8List bytes,
    String filename, {
    int topK = 12,
    String? color,
  }) async {
    try {
      final request =
          http.MultipartRequest('POST', Uri.parse('$kBaseUrl/search/image'))
            ..files.add(
              http.MultipartFile.fromBytes('file', bytes, filename: filename),
            )
            ..fields['top_k'] = '$topK';
      if (color != null) request.fields['color'] = color;
      final streamed = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamed);
      return _parse(response.statusCode, response.body);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Request timed out. Is the server running?');
    } catch (_) {
      throw ApiException('Cannot reach server at $kBaseUrl');
    }
  }

  SearchResponse _parse(int status, String body) {
    if (status != 200) {
      String message = 'Request failed ($status)';
      try {
        final detail = (jsonDecode(body) as Map<String, dynamic>)['detail'];
        if (detail is String) message = detail;
      } catch (_) {}
      throw ApiException(message);
    }
    final data = jsonDecode(body) as Map<String, dynamic>;
    final results = (data['results'] as List)
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
    return SearchResponse(results, (data['threshold_used'] as num).toDouble());
  }
}
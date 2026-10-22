import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/product.dart';
import '../services/api_service.dart';

class SearchProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  bool loading = false;
  bool hasSearched = false;
  String? error;
  List<Product> results = [];
  double? thresholdUsed;
  List<String> colors = [];
  String? selectedColor;
  Uint8List? previewBytes;

  Future<void> loadColors() async {
    colors = await _api.fetchColors();
    notifyListeners();
  }

  void setColor(String? color) {
    selectedColor = color;
    notifyListeners();
  }

  Future<void> searchText(String query) async {
    if (query.trim().isEmpty) return;
    previewBytes = null;
    await _run(() => _api.searchText(query.trim(), color: selectedColor));
  }

  Future<void> searchImage(XFile file) async {
    final bytes = await file.readAsBytes();
    previewBytes = bytes;
    final name = file.name.isEmpty ? 'upload.jpg' : file.name;
    await _run(() => _api.searchImage(bytes, name, color: selectedColor));
  }

  Future<void> _run(Future<SearchResponse> Function() action) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final response = await action();
      results = response.results;
      thresholdUsed = response.thresholdUsed;
      hasSearched = true;
    } on ApiException catch (e) {
      error = e.message;
      results = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
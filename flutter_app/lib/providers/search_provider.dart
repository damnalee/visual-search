import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sileo/sileo.dart';

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
  String previewLabel = '';
  int searchVersion = 0;

  String? _lastText;
  Uint8List? _lastImage;
  String _lastImageName = 'upload.jpg';
  int _token = 0;

  Future<void> loadColors() async {
    colors = await _api.fetchColors();
    notifyListeners();
  }

  void setColor(String? color) {
    if (selectedColor == color) return;
    selectedColor = color;
    notifyListeners();
    retry();
  }

  Future<void> retry() async {
    if (_lastText != null) {
      final text = _lastText!;
      await _execute(() => _api.searchText(text, color: selectedColor));
    } else if (_lastImage != null) {
      final bytes = _lastImage!;
      final name = _lastImageName;
      await _execute(() => _api.searchImage(bytes, name, color: selectedColor));
    }
  }

  Future<void> searchText(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    _lastText = q;
    _lastImage = null;
    previewBytes = null;
    previewLabel = '';
    await _execute(() => _api.searchText(q, color: selectedColor));
  }

  Future<void> searchImage(XFile file) async {
    final bytes = await file.readAsBytes();
    final name = file.name.isEmpty ? 'upload.jpg' : file.name;
    await searchImageBytes(bytes, name, label: 'Photo search');
  }

  Future<void> searchImageBytes(
    Uint8List bytes,
    String name, {
    required String label,
  }) async {
    _lastImage = bytes;
    _lastImageName = name;
    _lastText = null;
    previewBytes = bytes;
    previewLabel = label;
    await _execute(() => _api.searchImage(bytes, name, color: selectedColor));
  }

  Future<void> findSimilar(Product product) async {
    final token = ++_token;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final bytes = await _api.downloadBytes(product.imageUrl);
      if (token != _token) return;
      await searchImageBytes(
        bytes,
        '${product.id}.jpg',
        label: 'Similar to ${product.name}',
      );
    } on ApiException catch (e) {
      if (token != _token) return;
      error = e.message;
      results = [];
      hasSearched = true;
      loading = false;
      notifyListeners();
      sileo.error(SileoOptions(title: e.message));
    }
  }

  void clear() {
    _token++;
    _lastText = null;
    _lastImage = null;
    previewBytes = null;
    previewLabel = '';
    results = [];
    thresholdUsed = null;
    hasSearched = false;
    error = null;
    loading = false;
    notifyListeners();
  }

  Future<void> _execute(Future<SearchResponse> Function() action) async {
    final token = ++_token;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final response = await action();
      if (token != _token) return;
      results = response.results;
      thresholdUsed = response.thresholdUsed;
      hasSearched = true;
      searchVersion++;
      loading = false;
      notifyListeners();
      if (results.isEmpty) {
        sileo.info(const SileoOptions(title: 'No matches found'));
      } else {
        sileo.success(SileoOptions(title: '${results.length} matches'));
      }
    } on ApiException catch (e) {
      if (token != _token) return;
      error = e.message;
      results = [];
      hasSearched = true;
      loading = false;
      notifyListeners();
      sileo.error(SileoOptions(title: e.message));
    }
  }
}
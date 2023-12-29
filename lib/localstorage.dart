import 'dart:async';

import 'package:flutter/foundation.dart' show ValueNotifier;

import 'src/directory/directory.dart';

/// Creates instance of a local storage. Key is used as a filename
class LocalStorage {
  Stream<Map<String, dynamic>> get stream => _dir.stream;
  Map<String, dynamic>? _initialData;

  static final Map<String, LocalStorage> _cache = {};

  late DirUtils _dir;

  /// [ValueNotifier] which notifies about errors during storage initialization
  ValueNotifier<Error> onError = ValueNotifier(Error());

  /// A future indicating if localstorage instance is ready for read/write operations
  late Future<bool> ready;

  /// [key] is used as a filename
  /// Optional [path] is used as a directory. Defaults to application document directory
  factory LocalStorage(String key, [String? path, Map<String, dynamic>? initialData]) {
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    } else {
      final instance = LocalStorage._internal(key, path, initialData);
      _cache[key] = instance;

      return instance;
    }
  }

  void dispose() {
    if (_cache.containsKey(_dir.fileName)) {
      _cache.remove(_dir.fileName);
    }
    _dir.dispose();
  }

  LocalStorage._internal(String key, [String? path, Map<String, dynamic>? initialData]) {
    _dir = DirUtils(key, path);
    _initialData = initialData;

    ready = new Future<bool>(() async {
      await this._init();
      return true;
    });
  }

  Future<void> _init() async {
    try {
      await _dir.init(_initialData ?? {});
    } on Error catch (err) {
      onError.value = err;
    }
  }

  /// Returns the number of bytes currently stored in the JSON file.
  /// This function will throw a `PlatformNotSupportedError` if used on the web.
  Future<int> getStorageSize() async {
    return await _dir.getFileSize();
  }

  /// Returns a value from storage by key
  dynamic getItem(String key) {
    return _dir.getItem(key);
  }

  Map<String, dynamic> getData(){
    return _dir.getData();
  }

  /// Saves item by [key] to a storage. Value should be json encodable (`json.encode()` is called under the hood).
  /// After item was set to storage, consecutive [getItem] will return `json` representation of this item
  /// if [toEncodable] is provided, it is called before setting item to storage
  /// otherwise `value.toJson()` is called
  Future<void> setItem(
    String key,
    value, {
    Object Function(Object nonEncodable)? toEncodable,
    bool write = true
  }) async {
    var data = toEncodable?.call(value) ?? null;
    if (data == null) {
      try {
        data = value.toJson();
      } on NoSuchMethodError catch (_) {
        data = value;
      }
    }

    await _dir.setItem(key, data);

    if (write) _flush(); 
  }

  /// Saves the data permanently in the JSON file.
  Future<void> writeData() async {
    return _flush();
  }

  /// Removes item from storage by key
  Future<void> deleteItem(String key) async {
    await _dir.remove(key);
    return _flush();
  }

  /// Delete multiple entries before saving those changes into the file.
  Future<void> deleteItems(List<String> keys) async {
    for (final key in keys) {
      await _dir.remove(key);
    }
    return _flush();
  }

  /// Removes all items from localstorage
  Future<void> clear() async {
    await _dir.clear();
    return _flush();
  }
  bool writing = false;
  bool needReWrite = false;

  Future<void> _flush() async {
    if(writing){
      needReWrite = true;
      return;
    }else{
      return __flush();
    }
  }
  Future<void> __flush() async {
    try {
      writing = true;
      await _dir.flush();
      writing = false;
    } catch (e) {
      writing = false;
      print(e);
      // rethrow;
    }
    if(needReWrite){
      needReWrite = false;
      __flush();
    }
    return;
  }
}

import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui';

import 'package:http/http.dart' as http;

import 'dart:io';

Future<Uint8List> fetchBytes(String url,
    {Duration timeout = const Duration(seconds: 10)}) async {
  final response = await http
      .get(Uri.parse(url))
      .timeout(timeout, onTimeout: () => throw TimeoutException('请求超时'));
  if (response.statusCode != 200) {
    throw Exception('HTTP请求失败: ${response.statusCode}');
  }
  return response.bodyBytes;
}

Future<Image> decodeImage(Uint8List bytes) async {
  final codec = await instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
}

Future<Image> fetchImage(String url,
    {Duration timeout = const Duration(seconds: 10)}) async {
  try {
    final bytes = await fetchBytes(url, timeout: timeout);
    final codec = await instantiateImageCodec(bytes);
    return (await codec.getNextFrame()).image;
  } on Exception catch (e) {
    print(e);
    rethrow;
  }
}

class Semaphore {
  int _availablePermits; // 当前可用许可数
  final Queue<Completer<void>> _waitingQueue = Queue(); // 等待队列

  Semaphore(this._availablePermits);

  /// 获取一个许可
  Future<void> acquire() async {
    if (_availablePermits > 0) {
      _availablePermits--; // 如果有可用许可，直接分配
    } else {
      // 如果没有可用许可，加入等待队列
      final completer = Completer<void>();
      _waitingQueue.add(completer);
      await completer.future; // 等待许可释放
    }
  }

  /// 释放一个许可
  void release() {
    if (_waitingQueue.isNotEmpty) {
      // 如果有等待的任务，唤醒第一个任务
      final completer = _waitingQueue.removeFirst();
      completer.complete();
    } else {
      // 没有等待的任务，增加可用许可数
      _availablePermits++;
    }
  }

  /// 尝试获取许可（非阻塞）
  bool tryAcquire() {
    if (_availablePermits > 0) {
      _availablePermits--;
      return true;
    }
    return false;
  }
}

class FileCache {
  final Directory cacheDir;
  static final _invalidFileNameChars = RegExp(r'[\\/:*?"<>|]');

  FileCache(String dirPath) : cacheDir = Directory(dirPath) {
    print(cacheDir.absolute.path);
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }
  }

  String _safeFileName(String key) {
    return key.replaceAll(_invalidFileNameChars, '_');
  }

  Future<void> write(String key, Uint8List data) async {
    final fileName = _safeFileName(key);
    final tempFile = File('${cacheDir.path}/$fileName.tmp');

    if (tempFile.existsSync()) {
      return;
    }

    try {
      await tempFile.writeAsBytes(data);
      await tempFile.rename('${cacheDir.path}/$fileName');
      return;
    } catch (e) {
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }
      rethrow;
    }
  }

  Future<Uint8List?> read(String key) async {
    final file = File('${cacheDir.path}/${_safeFileName(key)}');
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }
}

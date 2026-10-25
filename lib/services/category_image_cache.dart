import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Keeps category artwork on disk until its versioned URL changes.
class CategoryImageCache {
  CategoryImageCache._();

  static Future<void> _removalQueue = Future<void>.value();
  static final Set<String> _queuedRemovals = <String>{};

  static final CacheManager instance = CacheManager(
    Config(
      'yana_category_images_v1',
      stalePeriod: const Duration(days: 36500),
      maxNrOfCacheObjects: 1000,
    ),
  );

  static Future<void> removeFailedFile(String key) {
    if (!_queuedRemovals.add(key)) return _removalQueue;

    _removalQueue = _removalQueue.then((_) async {
      try {
        await instance.removeFile(key);
      } catch (_) {
        // The next uniquely keyed retry can still fetch the image.
      } finally {
        _queuedRemovals.remove(key);
      }
    });
    return _removalQueue;
  }
}

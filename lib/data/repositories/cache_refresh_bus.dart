import 'dart:async';

class CacheRefreshBus {
  CacheRefreshBus._();

  static final _controller = StreamController<CacheRefreshType>.broadcast();

  static Stream<CacheRefreshType> get stream => _controller.stream;

  static void emit(CacheRefreshType type) {
    if (!_controller.isClosed) {
      _controller.add(type);
    }
  }
}

enum CacheRefreshType { content, videos }

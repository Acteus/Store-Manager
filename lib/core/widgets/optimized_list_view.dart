import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class OptimizedListView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;
  final Future<List<T>> Function(int offset, int limit)? onLoadMore;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;
  final bool hasMore;
  final bool isLoading;
  final EdgeInsetsGeometry? padding;
  final double? itemExtent;
  final int loadMoreThreshold;

  const OptimizedListView({
    Key? key,
    required this.items,
    required this.itemBuilder,
    this.loadingBuilder,
    this.emptyBuilder,
    this.onLoadMore,
    this.onRefresh,
    this.controller,
    this.hasMore = true,
    this.isLoading = false,
    this.padding,
    this.itemExtent,
    this.loadMoreThreshold = 3,
  }) : super(key: key);

  @override
  State<OptimizedListView<T>> createState() => _OptimizedListViewState<T>();
}

class _OptimizedListViewState<T> extends State<OptimizedListView<T>>
    with AutomaticKeepAliveClientMixin {
  late ScrollController _scrollController;
  bool _isLoadingMore = false;
  final Set<int> _visibleItems = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    } else {
      _scrollController.removeListener(_onScroll);
    }
    super.dispose();
  }

  void _onScroll() {
    if (!widget.hasMore || _isLoadingMore || widget.onLoadMore == null) {
      return;
    }

    final position = _scrollController.position;
    final threshold =
        position.maxScrollExtent - (position.viewportDimension * 0.2);

    if (position.pixels >= threshold) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      await widget.onLoadMore!(widget.items.length, 20);
    } catch (e) {
      // Handle error
      debugPrint('Error loading more items: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    if (widget.onRefresh != null) {
      await widget.onRefresh!();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.items.isEmpty && !widget.isLoading) {
      return widget.emptyBuilder?.call(context) ??
          const Center(child: Text('No items found'));
    }

    Widget listView;

    if (widget.itemExtent != null) {
      // Use ListView.builder with itemExtent for better performance
      listView = ListView.builder(
        controller: _scrollController,
        padding: widget.padding,
        itemExtent: widget.itemExtent,
        itemCount: widget.items.length + (widget.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= widget.items.length) {
            return _buildLoadingIndicator();
          }
          return _buildItem(context, index);
        },
      );
    } else {
      // Use regular ListView.builder
      listView = ListView.builder(
        controller: _scrollController,
        padding: widget.padding,
        itemCount: widget.items.length + (widget.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= widget.items.length) {
            return _buildLoadingIndicator();
          }
          return _buildItem(context, index);
        },
      );
    }

    if (widget.onRefresh != null) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        child: listView,
      );
    }

    return listView;
  }

  Widget _buildItem(BuildContext context, int index) {
    final item = widget.items[index];

    return VisibilityDetector(
      key: Key('item_$index'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.1) {
          _visibleItems.add(index);
        } else {
          _visibleItems.remove(index);
        }
      },
      child: RepaintBoundary(
        child: widget.itemBuilder(context, item, index),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    if (widget.loadingBuilder != null) {
      return widget.loadingBuilder!(context);
    }

    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

// Visibility detector for tracking which items are visible
class VisibilityDetector extends StatefulWidget {
  final Key key;
  final Widget child;
  final Function(VisibilityInfo) onVisibilityChanged;

  const VisibilityDetector({
    required this.key,
    required this.child,
    required this.onVisibilityChanged,
  }) : super(key: key);

  @override
  State<VisibilityDetector> createState() => _VisibilityDetectorState();
}

class _VisibilityDetectorState extends State<VisibilityDetector> {
  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkVisibility();
        });
        return false;
      },
      child: widget.child,
    );
  }

  void _checkVisibility() {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);

    final viewportHeight = MediaQuery.of(context).size.height;
    final visibleHeight = size.height;

    double visibleFraction = 0.0;

    if (position.dy < viewportHeight && position.dy + visibleHeight > 0) {
      final visibleTop = position.dy < 0 ? 0 : position.dy;
      final visibleBottom = position.dy + visibleHeight > viewportHeight
          ? viewportHeight
          : position.dy + visibleHeight;

      final actualVisibleHeight = visibleBottom - visibleTop;
      visibleFraction = actualVisibleHeight / visibleHeight;
    }

    widget
        .onVisibilityChanged(VisibilityInfo(visibleFraction: visibleFraction));
  }
}

class VisibilityInfo {
  final double visibleFraction;

  VisibilityInfo({required this.visibleFraction});
}

// Optimized Grid View for products
class OptimizedGridView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;
  final Future<List<T>> Function(int offset, int limit)? onLoadMore;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;
  final bool hasMore;
  final bool isLoading;
  final EdgeInsetsGeometry? padding;
  final int crossAxisCount;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  const OptimizedGridView({
    Key? key,
    required this.items,
    required this.itemBuilder,
    this.loadingBuilder,
    this.emptyBuilder,
    this.onLoadMore,
    this.onRefresh,
    this.controller,
    this.hasMore = true,
    this.isLoading = false,
    this.padding,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.0,
    this.crossAxisSpacing = 8.0,
    this.mainAxisSpacing = 8.0,
  }) : super(key: key);

  @override
  State<OptimizedGridView<T>> createState() => _OptimizedGridViewState<T>();
}

class _OptimizedGridViewState<T> extends State<OptimizedGridView<T>>
    with AutomaticKeepAliveClientMixin {
  late ScrollController _scrollController;
  bool _isLoadingMore = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    } else {
      _scrollController.removeListener(_onScroll);
    }
    super.dispose();
  }

  void _onScroll() {
    if (!widget.hasMore || _isLoadingMore || widget.onLoadMore == null) {
      return;
    }

    final position = _scrollController.position;
    final threshold =
        position.maxScrollExtent - (position.viewportDimension * 0.2);

    if (position.pixels >= threshold) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      await widget.onLoadMore!(widget.items.length, 20);
    } catch (e) {
      debugPrint('Error loading more items: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    if (widget.onRefresh != null) {
      await widget.onRefresh!();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.items.isEmpty && !widget.isLoading) {
      return widget.emptyBuilder?.call(context) ??
          const Center(child: Text('No items found'));
    }

    Widget gridView = GridView.builder(
      controller: _scrollController,
      padding: widget.padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        childAspectRatio: widget.childAspectRatio,
        crossAxisSpacing: widget.crossAxisSpacing,
        mainAxisSpacing: widget.mainAxisSpacing,
      ),
      itemCount:
          widget.items.length + (widget.hasMore ? widget.crossAxisCount : 0),
      itemBuilder: (context, index) {
        if (index >= widget.items.length) {
          return _buildLoadingIndicator();
        }
        return RepaintBoundary(
          child: widget.itemBuilder(context, widget.items[index], index),
        );
      },
    );

    if (widget.onRefresh != null) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        child: gridView,
      );
    }

    return gridView;
  }

  Widget _buildLoadingIndicator() {
    return widget.loadingBuilder?.call(context) ??
        const Center(child: CircularProgressIndicator());
  }
}

// Memory efficient image cache manager
class MemoryEfficientImageCache {
  static final Map<String, ImageProvider> _cache = {};
  static const int _maxCacheSize = 50;

  static ImageProvider getImage(String url) {
    if (_cache.containsKey(url)) {
      return _cache[url]!;
    }

    if (_cache.length >= _maxCacheSize) {
      // Remove oldest entry
      final firstKey = _cache.keys.first;
      _cache.remove(firstKey);
    }

    final image = NetworkImage(url);
    _cache[url] = image;
    return image;
  }

  static void clearCache() {
    _cache.clear();
  }

  static void removeFromCache(String url) {
    _cache.remove(url);
  }
}

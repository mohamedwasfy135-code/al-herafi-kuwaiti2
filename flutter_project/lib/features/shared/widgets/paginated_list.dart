
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════
// PaginatedApiList — API-based paginated list (replaces Firestore)
// ═══════════════════════════════════════════════════════════════════

class PaginatedApiList extends StatefulWidget {
  /// Fetches a page of items from the API.
  /// Return an empty list to signal no more data.
  final Future<List<Map<String, dynamic>>> Function({required int page, required int pageSize}) fetcher;
  final int pageSize;
  final Widget Function(BuildContext, Map<String, dynamic>, int) itemBuilder;
  final Widget emptyWidget;
  final Function(String error)? onError;

  const PaginatedApiList({
    super.key,
    required this.fetcher,
    this.pageSize = 15,
    required this.itemBuilder,
    required this.emptyWidget,
    this.onError,
  });

  @override
  State<PaginatedApiList> createState() => _PaginatedApiListState();
}

class _PaginatedApiListState extends State<PaginatedApiList> {
  final _items = <Map<String, dynamic>>[];
  bool _loading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  final _controller = ScrollController();
  bool _errorOccurred = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMore();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_controller.position.pixels >=
        _controller.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore || _errorOccurred) return;
    setState(() => _loading = true);
    try {
      final newItems = await widget.fetcher(page: _currentPage, pageSize: widget.pageSize);
      if (!mounted) return;
      setState(() {
        _items.addAll(newItems);
        _currentPage++;
        _hasMore = newItems.length == widget.pageSize;
      });
    } catch (e) {
      debugPrint('PaginatedApiList error: $e');
      _errorOccurred = true;
      _errorMessage = e.toString();
      if (widget.onError != null) {
        widget.onError!(_errorMessage!);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> refresh() async {
    setState(() {
      _items.clear();
      _currentPage = 0;
      _hasMore = true;
      _errorOccurred = false;
      _errorMessage = null;
    });
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorOccurred && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text('فشل في تحميل البيانات',
                style: TextStyle(color: Colors.white.withOpacity(0.8))),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(_errorMessage!,
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
                    textAlign: TextAlign.center),
              ),
          ],
        ),
      );
    }

    if (!_loading && _items.isEmpty) return widget.emptyWidget;

    return RefreshIndicator(
      onRefresh: refresh,
      color: const Color(0xFF0071E3),
      child: ListView.builder(
        controller: _controller,
        itemCount: _items.length + (_loading ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i == _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF0071E3))),
            );
          }
          return widget.itemBuilder(ctx, _items[i], i);
        },
      ),
    );
  }
}

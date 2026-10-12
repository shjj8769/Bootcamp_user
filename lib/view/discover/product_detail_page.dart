part of '../home.dart';

extension _ProductDetailPageView on _HomeState {
  void _openProduct(Product initial) {
    _recordRecentlyViewed(initial.sku);
    final variants = _products
        .where((item) => item.modelKey == initial.modelKey)
        .toList();
    var selected = initial;
    var showReviews = false;
    List<dynamic> reviews = [];
    var reviewBusy = false;
    String? reviewError;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => StatefulBuilder(
          builder: (context, refresh) {
            Future<void> loadReviews() async {
              refresh(() {
                reviewBusy = true;
                reviewError = null;
              });
              try {
                final data = await _request(
                  'GET',
                  '/review/product/${Uri.encodeComponent(initial.sku)}',
                );
                refresh(() => reviews = data['results'] as List? ?? []);
              } catch (error) {
                refresh(() => reviewError = '$error');
              } finally {
                refresh(() => reviewBusy = false);
              }
            }

            return Scaffold(
              appBar: AppBar(
                title: const Text('상품 상세'),
                actions: [
                  IconButton(
                    onPressed: () => _toggleWishlist(selected),
                    icon: Icon(
                      _wishlist.contains(selected.sku)
                          ? Icons.favorite
                          : Icons.favorite_border,
                    ),
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: AspectRatio(
                      aspectRatio: 1.1,
                      child: Image.network(
                        '${AppConfig.apiBaseUrl}/product/${Uri.encodeComponent(selected.sku)}/image',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: Color(0xFFE8ECEC),
                          child: Icon(Icons.directions_run, size: 60),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    selected.brand.toUpperCase(),
                    style: const TextStyle(color: Colors.black54),
                  ),
                  Text(
                    selected.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${selected.price}원',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '색상',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final color
                          in variants.map((item) => item.color).toSet())
                        ChoiceChip(
                          label: Text(color),
                          selected: selected.color == color,
                          onSelected: (_) => refresh(
                            () => selected = variants.firstWhere(
                              (item) => item.color == color,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '사이즈',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final item in variants.where(
                        (item) => item.color == selected.color,
                      ))
                        ChoiceChip(
                          label: Text(item.size),
                          selected: selected.sku == item.sku,
                          onSelected: (_) => refresh(() => selected = item),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        _detailTab(
                          label: '상품 정보',
                          selected: !showReviews,
                          onTap: () => refresh(() => showReviews = false),
                        ),
                        _detailTab(
                          label:
                              '구매 리뷰${reviews.isEmpty ? '' : ' ${reviews.length}'}',
                          selected: showReviews,
                          onTap: () {
                            refresh(() => showReviews = true);
                            if (reviews.isEmpty && !reviewBusy) loadReviews();
                          },
                        ),
                      ],
                    ),
                  ),
                  if (!showReviews)
                    Text('${selected.color} · ${selected.size} mm')
                  else if (reviewBusy)
                    const Center(child: CircularProgressIndicator())
                  else if (reviewError != null)
                    Text(reviewError!)
                  else if (reviews.isEmpty)
                    const Text('등록된 리뷰가 없습니다.')
                  else
                    for (final review in reviews)
                      Card(
                        child: ListTile(
                          title: Text(
                            '★ ${review['rating'] ?? 0} · ${review['color'] ?? ''} ${review['size'] ?? ''}',
                          ),
                          subtitle: Text('${review['post'] ?? ''}'),
                        ),
                      ),
                ],
              ),
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: FilledButton(
                    onPressed: () {
                      _addToCart(selected);
                      Navigator.pop(routeContext);
                    },
                    child: const Text('장바구니 담기'),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _detailTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 2,
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
          ),
        ],
      ),
    ),
  );
}

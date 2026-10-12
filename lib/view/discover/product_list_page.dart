part of '../home.dart';

extension _ProductListPageView on _HomeState {
  Widget _catalog() {
    final brands = _products.map((p) => p.brand).toSet().toList()..sort();
    final categories = _products.map((p) => p.category).toSet().toList()
      ..sort();
    final visibleProducts = _uniqueProducts.where((product) {
      final categoryMatches =
          _catalogCategory == null || product.category == _catalogCategory;
      final brandMatches =
          _catalogBrand == null || product.brand == _catalogBrand;
      return categoryMatches && brandMatches;
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('카테고리')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '용도별 카테고리',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('전체'),
                selected: _catalogCategory == null,
                onSelected: (_) => _updateState(() => _catalogCategory = null),
              ),
              for (final category in categories)
                ChoiceChip(
                  label: Text(category),
                  selected: _catalogCategory == category,
                  onSelected: (_) => _updateState(
                    () => _catalogCategory = _catalogCategory == category
                        ? null
                        : category,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('브랜드', style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('전체'),
                selected: _catalogBrand == null,
                onSelected: (_) => _updateState(() => _catalogBrand = null),
              ),
              for (final brand in brands)
                ChoiceChip(
                  label: Text(brand),
                  selected: _catalogBrand == brand,
                  onSelected: (_) => _updateState(
                    () => _catalogBrand = _catalogBrand == brand ? null : brand,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('${visibleProducts.length}개 모델'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleProducts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.74,
            ),
            itemBuilder: (context, index) {
              final product = visibleProducts[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _openProduct(product),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SizedBox.expand(
                          child: Image.network(
                            '${AppConfig.apiBaseUrl}/product/${Uri.encodeComponent(product.sku)}/image',
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.directions_run),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product.brand),
                            Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text('${product.price}원'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Product> get _uniqueProducts {
    final seen = <String>{};
    return _products.where((p) => seen.add(p.modelKey)).toList();
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../models/product.dart';

/// Storefront landing view: database-backed banners, filters and product models.
class HomePage extends StatefulWidget {
  const HomePage({
    required this.products,
    required this.banners,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onShowCatalog,
    required this.onOpenNotifications,
    required this.onOpenProduct,
    super.key,
  });

  final List<Product> products;
  final List<int> banners;
  final bool loading;
  final String? error;
  final Future<void> Function() onRetry;
  final VoidCallback onShowCatalog;
  final VoidCallback onOpenNotifications;
  final ValueChanged<Product> onOpenProduct;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _gender = '전체';
  String _category = '전체';
  String _brand = '전체';
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> get _filtered {
    final seen = <String>{};
    return widget.products.where((product) {
      if (_gender != '전체' && product.audience != _gender) return false;
      if (_category != '전체' && product.category != _category) return false;
      if (_brand != '전체' && product.brand != _brand) return false;
      if (_query.isNotEmpty &&
          !'${product.brand} ${product.name} ${product.code}'
              .toLowerCase()
              .contains(_query)) {
        return false;
      }
      return seen.add(product.modelKey);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final brands = widget.products.map((p) => p.brand).toSet().toList()..sort();
    final categories = widget.products.map((p) => p.category).toSet().toList()
      ..sort();
    final filtered = _filtered;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'FITPICK',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              Text('.', style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          actions: [
            IconButton(
              onPressed: widget.onOpenNotifications,
              icon: const Icon(Icons.notifications_none_rounded),
              tooltip: '알림',
            ),
          ],
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text('안녕하세요!', style: TextStyle(color: Color(0xFF68716F))),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 3, 20, 12),
            child: Text(
              '오늘도 좋은 하루 되세요 👋',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: CupertinoSearchTextField(
              controller: _searchController,
              placeholder: '신발 검색',
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
        ),
        if (widget.banners.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 205,
              child: PageView.builder(
                itemCount: widget.banners.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      '${AppConfig.apiBaseUrl}/banner/${widget.banners[index]}/image',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: Color(0xFFE8ECEC)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (categories.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '용도별 둘러보기',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final category in categories)
                        ActionChip(
                          label: Text(category),
                          onPressed: () => setState(() => _category = category),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        _filter(
          '성별',
          const ['전체', '남녀공용', '여성', '아동'],
          _gender,
          (value) => setState(() {
            if (value == '전체') {
              _gender = '전체';
              _category = '전체';
              _brand = '전체';
            } else {
              _gender = value;
            }
          }),
        ),
        if (brands.isNotEmpty)
          _filter(
            '브랜드',
            ['전체', ...brands],
            _brand,
            (value) => setState(() {
              if (value == '전체') {
                _gender = '전체';
                _category = '전체';
                _brand = '전체';
              } else {
                _brand = value;
              }
            }),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(
              children: [
                const Text(
                  '추천 상품',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  '${filtered.length}개',
                  key: const ValueKey('home-filtered-count'),
                ),
                TextButton(
                  onPressed: widget.onShowCatalog,
                  child: const Text('전체보기'),
                ),
              ],
            ),
          ),
        ),
        if (widget.loading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (widget.error != null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.error!),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: widget.onRetry,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          )
        else if (filtered.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('표시할 상품이 없습니다.')),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            sliver: SliverGrid.builder(
              itemCount: filtered.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: .68,
              ),
              itemBuilder: (context, index) {
                final product = filtered[index];
                return InkWell(
                  onTap: () => widget.onOpenProduct(product),
                  borderRadius: BorderRadius.circular(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            '${AppConfig.apiBaseUrl}/product/${Uri.encodeComponent(product.sku)}/image',
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const ColoredBox(
                              color: Color(0xFFE8ECEC),
                              child: Center(
                                child: Icon(Icons.directions_run, size: 42),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product.brand,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${product.price}원',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _filter(
    String title,
    List<String> options,
    String value,
    ValueChanged<String> onChanged,
  ) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final option in options)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(option),
                        selected: value == option,
                        onSelected: (_) => onChanged(option),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

part of '../home.dart';

extension _CartPageView on _HomeState {
  Widget _cartPage() {
    final subtotal = _cart.values.fold<int>(
      0,
      (sum, row) =>
          sum + (row['product'] as Product).price * (row['quantity'] as int),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('장바구니')),
      body: _cart.isEmpty
          ? const Center(child: Text('장바구니가 비어 있습니다.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final entry in _cart.entries)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              '${AppConfig.apiBaseUrl}/product/${Uri.encodeComponent(entry.key)}/image',
                              width: 88,
                              height: 88,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const SizedBox(
                                width: 88,
                                height: 88,
                                child: ColoredBox(
                                  color: Color(0xFFE8ECEC),
                                  child: Icon(Icons.directions_run),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (entry.value['product'] as Product).name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${(entry.value['product'] as Product).color} · ${(entry.value['product'] as Product).size} mm',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${(entry.value['product'] as Product).price}원',
                                ),
                                TextButton.icon(
                                  onPressed: () => _chooseCartVariant(
                                    entry.key,
                                    entry.value['product'] as Product,
                                  ),
                                  icon: const Icon(Icons.tune, size: 18),
                                  label: const Text('색상 / 사이즈 변경'),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _changeQuantity(
                                        entry.key,
                                        (entry.value['quantity'] as int) - 1,
                                      ),
                                      icon: const Icon(Icons.remove),
                                    ),
                                    Text('${entry.value['quantity']}'),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _changeQuantity(
                                        entry.key,
                                        (entry.value['quantity'] as int) + 1,
                                      ),
                                      icon: const Icon(Icons.add),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('상품 금액'),
                  trailing: Text('$subtotal원'),
                ),
              ],
            ),
      bottomNavigationBar: _cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: _checkout,
                  child: const Text('수령 매장 선택 및 주문하기'),
                ),
              ),
            ),
    );
  }

  Future<void> _changeQuantity(String sku, int count) async {
    if (count <= 0) {
      _updateState(() => _cart.remove(sku));
      if (_localAvailable) {
        await LocalDatabase.instance.deleteRecords(
          LocalDatabase.package,
          where: 'option_code = ?',
          whereArgs: [sku],
        );
      }
    } else {
      final row = _cart[sku]!;
      _updateState(() => row['quantity'] = count);
      await _storeCart(row['product'] as Product, count);
    }
  }

  Future<void> _chooseCartVariant(String sku, Product current) async {
    final variants = _products
        .where((product) => product.modelKey == current.modelKey)
        .toList();
    if (variants.isEmpty) return;
    var selected = current;
    final chosen = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refreshSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '옵션 변경',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text('색상'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final color
                        in variants.map((item) => item.color).toSet())
                      ChoiceChip(
                        label: Text(color.isEmpty ? '색상 미등록' : color),
                        selected: selected.color == color,
                        onSelected: (_) => refreshSheet(() {
                          selected = variants.firstWhere(
                            (item) =>
                                item.color == color &&
                                item.size == selected.size,
                            orElse: () => variants.firstWhere(
                              (item) => item.color == color,
                            ),
                          );
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('사이즈'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final item in variants.where(
                      (item) => item.color == selected.color,
                    ))
                      ChoiceChip(
                        label: Text('${item.size} mm'),
                        selected: selected.sku == item.sku,
                        onSelected: (_) => refreshSheet(() => selected = item),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, selected),
                    child: const Text('변경 적용'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (chosen != null) await _changeCartVariant(sku, chosen);
  }

  Future<void> _changeCartVariant(String oldSku, Product nextProduct) async {
    final oldRow = _cart[oldSku];
    if (oldRow == null) return;
    final oldQuantity = oldRow['quantity'] as int;
    if (oldSku == nextProduct.sku) {
      _updateState(() => oldRow['product'] = nextProduct);
      await _storeCart(nextProduct, oldQuantity);
      return;
    }
    final mergedQuantity =
        oldQuantity + (_cart[nextProduct.sku]?['quantity'] as int? ?? 0);
    _updateState(() {
      _cart.remove(oldSku);
      _cart[nextProduct.sku] = {
        'product': nextProduct,
        'quantity': mergedQuantity,
      };
    });
    if (!_localAvailable) return;
    try {
      await LocalDatabase.instance.deleteRecords(
        LocalDatabase.package,
        where: 'option_code = ?',
        whereArgs: [oldSku],
      );
      await _storeCart(nextProduct, mergedQuantity);
    } catch (_) {
      _localAvailable = false;
    }
  }
}

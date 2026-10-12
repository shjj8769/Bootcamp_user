part of '../home.dart';

extension _OrderHistoryPageView on _HomeState {
  Widget _orderPage() {
    if (_email == null) return _loginGate();
    return FutureBuilder<dynamic>(
      future: _request(
        'GET',
        '/purchase/customer/${Uri.encodeComponent(_email!)}',
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('주문 내역을 불러오지 못했습니다: ${snapshot.error}'));
        }
        final rows = (snapshot.data['results'] as List? ?? const [])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        return Scaffold(
          appBar: AppBar(title: const Text('주문 · 수령 내역')),
          body: rows.isEmpty
              ? const Center(child: Text('주문 내역이 없습니다.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '주문 내역',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _openClaims,
                          icon: const Icon(Icons.assignment_return_outlined),
                          label: const Text('교환 · 반품'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final row in rows)
                      Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _openOrderDetail(row),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${row['p_date'] ?? ''} · 주문 ${row['p_id']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _orderThumbnail('${row['SKU'] ?? ''}'),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${row['pr_brand'] ?? ''}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            '${row['pr_name'] ?? row['SKU']}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '${row['color'] ?? ''} · ${row['size'] ?? ''} mm · 수량 ${row['p_count'] ?? 1}',
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                                const Divider(),
                                Row(
                                  children: [
                                    const Text('주문 상세 · 현재 상태 확인'),
                                    const Spacer(),
                                    Text('${row['p_price'] ?? ''}원'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }

  Widget _orderThumbnail(String sku) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Image.network(
      '${AppConfig.apiBaseUrl}/product/${Uri.encodeComponent(sku)}/image',
      width: 72,
      height: 72,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const SizedBox(
        width: 72,
        height: 72,
        child: ColoredBox(
          color: Color(0xFFE8ECEC),
          child: Icon(Icons.shopping_bag_outlined),
        ),
      ),
    ),
  );
}

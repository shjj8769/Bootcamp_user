part of '../home.dart';

extension _OrderDetailPageView on _HomeState {
  Future<void> _openOrderDetail(Map<String, dynamic> order) async {
    var orderDetails = Map<String, dynamic>.from(order);
    if (orderDetails['p_count'] == null && orderDetails['p_id'] != null) {
      try {
        orderDetails = {
          ...orderDetails,
          ...Map<String, dynamic>.from(
            await _request('GET', '/purchase/${orderDetails['p_id']}'),
          ),
        };
      } catch (_) {}
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => FutureBuilder<dynamic>(
          future: _request(
            'GET',
            '/notification/customer/${Uri.encodeComponent(_email!)}',
          ),
          builder: (context, snapshot) {
            final statuses = (snapshot.data?['results'] as List? ?? const [])
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row));
            final state = statuses
                .where((row) => '${row['p_id']}' == '${orderDetails['p_id']}')
                .firstOrNull;
            final received = state?['status'] == '수령 완료';
            return Scaffold(
              appBar: AppBar(title: const Text('주문 · 준비 상태')),
              body: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Text(
                    '주문번호 ${orderDetails['p_id']}',
                    style: const TextStyle(fontSize: 12, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            received ? '수령이 완료되었어요' : '주문이 접수되었어요',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            received
                                ? '매장 수령이 확인되었습니다.'
                                : '매장 준비가 완료되면 알림으로 안내해 드립니다.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '주문 진행 상황',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  const SizedBox(height: 8),
                  _timelineTile(
                    '주문 접수',
                    true,
                    '${orderDetails['p_date'] ?? ''}',
                  ),
                  _timelineTile(
                    '매장 수령',
                    received,
                    received ? '${state?['status_at'] ?? ''}' : '수령 확인 대기',
                  ),
                  Card(
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          '${AppConfig.apiBaseUrl}/product/${Uri.encodeComponent('${orderDetails['SKU'] ?? ''}')}/image',
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(
                            width: 64,
                            height: 64,
                            child: ColoredBox(
                              color: Color(0xFFE8ECEC),
                              child: Icon(Icons.shopping_bag_outlined),
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        '${orderDetails['pr_name'] ?? orderDetails['SKU'] ?? '상품'}',
                      ),
                      subtitle: Text(
                        '${orderDetails['color'] ?? ''} · ${orderDetails['size'] ?? ''} mm · 수량 ${orderDetails['p_count'] ?? 1}',
                      ),
                      trailing: Text('${orderDetails['p_price'] ?? ''}원'),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.store_outlined),
                    title: Text(
                      '${state?['store_name'] ?? _favoriteStore?['name'] ?? '수령 매장'}',
                    ),
                    subtitle: Text('매장 번호 ${orderDetails['store_seq'] ?? ''}'),
                  ),
                  if (!received)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        '현재 DB에서 확인할 수 있는 상태만 표시합니다. 배송 출발·픽업 준비 단계는 백엔드에 상태값이 없어 표시하지 않습니다.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                  if (snapshot.hasError)
                    Text(
                      '상태 조회 실패: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  const SizedBox(height: 12),
                  if (!received)
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(routeContext).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PickupQrPage(
                              order: orderDetails,
                              email: _email!,
                              onTabSelected: (index) {
                                Navigator.of(context).pop();
                                if (mounted) _updateState(() => _tab = index);
                              },
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text('매장 수령 QR 발급'),
                    ),
                  OutlinedButton(
                    onPressed: () => _openClaims(),
                    child: const Text('교환 · 반품 내역 보기'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _timelineTile(String title, bool complete, String subtitle) =>
      ListTile(
        leading: Icon(
          complete ? Icons.check_circle : Icons.radio_button_unchecked,
          color: complete ? const Color(0xFF527765) : Colors.black38,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
      );
}

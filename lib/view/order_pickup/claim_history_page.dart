part of '../home.dart';

extension _ClaimHistoryPageView on _HomeState {
  Future<void> _openClaims() async {
    if (_email == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('교환 · 반품 내역')),
          body: FutureBuilder<dynamic>(
            future: _request(
              'GET',
              '/refund/customer/${Uri.encodeComponent(_email!)}',
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('내역을 불러오지 못했습니다: ${snapshot.error}'));
              }
              final rows = (snapshot.data['results'] as List? ?? const [])
                  .whereType<Map>()
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList();
              if (rows.isEmpty) {
                return const Center(child: Text('등록된 교환·반품 내역이 없습니다.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final refunded =
                      row['is_refunded'] == 1 || row['is_refunded'] == true;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${row['p_r_date'] ?? ''} · 주문 ${row['p_r_id']}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${row['pr_brand'] ?? ''} ${row['pr_name'] ?? row['SKU']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${row['color'] ?? ''} · ${row['size'] ?? ''} mm · ${row['p_count'] ?? 1}개',
                          ),
                          const Divider(),
                          Text('신청 사유 · ${row['p_r_reason'] ?? '미입력'}'),
                          Text(
                            refunded ? '환불 완료' : '접수 · 처리 대기',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${row['p_price'] ?? ''}원',
                            textAlign: TextAlign.end,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

part of '../home.dart';

extension _NotificationPageView on _HomeState {
  Future<void> _openNotifications() async {
    if (_email == null) {
      _goLogin();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('알림')),
          body: FutureBuilder<dynamic>(
            future: _request(
              'GET',
              '/notification/customer/${Uri.encodeComponent(_email!)}',
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('알림을 불러오지 못했습니다: ${snapshot.error}'));
              }
              final rows = (snapshot.data['results'] as List? ?? const [])
                  .whereType<Map>()
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList();
              if (rows.isEmpty) {
                return const Center(child: Text('새로운 알림이 없습니다.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final done = row['status'] == '수령 완료';
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        done
                            ? Icons.check_circle_outline
                            : Icons.receipt_long_outlined,
                      ),
                      title: Text(done ? '수령이 완료되었어요' : '주문이 접수되었어요'),
                      subtitle: Text(
                        '${row['pr_name']} · ${row['store_name']}\n${row['status_at'] ?? ''}',
                      ),
                      isThreeLine: true,
                      onTap: () => _openOrderDetail({
                        'p_id': row['p_id'],
                        'SKU': row['SKU'],
                        'pr_name': row['pr_name'],
                        'store_seq': row['store_seq'],
                        'p_date': row['created_at'],
                      }),
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

part of '../home.dart';

extension _CustomerSupportPageView on _HomeState {
  Future<void> _openSupport() async {
    if (_email == null) return;
    var subject = '';
    var detail = '';
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('고객센터')),
          body: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const Text(
                '무엇을 도와드릴까요?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Text('문의 내용을 작성하면 회원 계정으로 등록됩니다.'),
              const SizedBox(height: 18),
              ExpansionTile(
                title: const Text('주문 상태는 어디서 확인하나요?'),
                children: const [
                  ListTile(
                    title: Text('마이페이지의 주문 · 수령 내역에서 현재 저장된 상태를 확인할 수 있습니다.'),
                  ),
                ],
              ),
              ExpansionTile(
                title: const Text('매장에서 상품을 수령하려면 어떻게 하나요?'),
                children: const [
                  ListTile(title: Text('주문 상세에서 QR을 발급한 뒤 매장 직원에게 보여 주세요.')),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                '1:1 문의 작성',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextField(
                onChanged: (value) => subject = value,
                decoration: const InputDecoration(
                  labelText: '문의 제목',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                minLines: 4,
                maxLines: 8,
                onChanged: (value) => detail = value,
                decoration: const InputDecoration(
                  labelText: '문의 내용',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  try {
                    final submittedSubject = subject.trim();
                    final submittedDetail = detail.trim();
                    if (submittedSubject.isEmpty || submittedDetail.isEmpty) {
                      _toast('문의 제목과 내용을 입력해 주세요.');
                      return;
                    }
                    await _request(
                      'POST',
                      '/inquiry/customer/${Uri.encodeComponent(_email!)}',
                      body: {
                        'post': submittedSubject,
                        'inquiry_detail': submittedDetail,
                      },
                    );
                    if (!mounted) return;
                    Navigator.pop(context);
                    _toast('문의가 등록되었습니다.');
                  } catch (error) {
                    _toast('$error');
                  }
                },
                child: const Text('문의 등록'),
              ),
              const SizedBox(height: 24),
              const Text(
                '내 문의 내역',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              FutureBuilder<dynamic>(
                future: _request(
                  'GET',
                  '/inquiry/customer/${Uri.encodeComponent(_email!)}',
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LinearProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Text('문의 내역 조회 실패: ${snapshot.error}');
                  }
                  final rows = (snapshot.data['results'] as List? ?? const [])
                      .whereType<Map>();
                  if (rows.isEmpty) {
                    return const ListTile(title: Text('등록된 문의가 없습니다.'));
                  }
                  return Column(
                    children: [
                      for (final row in rows)
                        ListTile(
                          title: Text('${row['post'] ?? ''}'),
                          subtitle: Text(
                            '${row['i_date'] ?? ''} · ${row['inquiry_detail'] ?? ''}',
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

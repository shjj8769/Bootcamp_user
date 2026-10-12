part of '../home.dart';

extension _MyPageView on _HomeState {
  Widget _myPage() {
    if (_email == null) return _loginGate();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            '마이페이지',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 25,
                    child: Icon(Icons.person_outline),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_profile['c_name'] ?? '회원'}님',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(_email!, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _openProfile,
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: '내 정보 수정',
                  ),
                ],
              ),
              if ('${_profile['tel'] ?? ''}'.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '${_profile['tel']} · ${_profile['c_address'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _summaryValue(
                      '주문',
                      '내역 보기',
                      () => _updateState(() => _tab = 3),
                    ),
                  ),
                  Expanded(
                    child: _summaryValue(
                      '찜',
                      '${_wishlist.length}개',
                      () => _openLocalSection('찜한 상품'),
                    ),
                  ),
                  Expanded(child: _summaryValue('리뷰', '내 리뷰', _openMyReviews)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('자주 찾는 매장'),
            subtitle: Text('${_favoriteStore?['name'] ?? '설정된 매장이 없습니다'}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openFavoriteStoreSetting,
          ),
        ),
        for (final title in [
          '주문 · 수령 내역',
          '교환 · 반품 내역',
          '작성한 리뷰',
          '결제수단',
          '쿠폰',
          '찜한 상품',
          '최근 본 상품',
          '고객센터',
          '앱 설정',
        ])
          Card(
            child: ListTile(
              title: Text(title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                switch (title) {
                  case '주문 · 수령 내역':
                    _updateState(() => _tab = 3);
                  case '교환 · 반품 내역':
                    _openClaims();
                  case '작성한 리뷰':
                    _openMyReviews();
                  case '고객센터':
                    _openSupport();
                  case '앱 설정':
                    _openSettings();
                  default:
                    _openLocalSection(title);
                }
              },
            ),
          ),
        Card(
          child: ListTile(
            title: const Text('로그아웃'),
            leading: const Icon(Icons.logout),
            onTap: _logout,
          ),
        ),
      ],
    );
  }

  Widget _summaryValue(String label, String value, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      );
}

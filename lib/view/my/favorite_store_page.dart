part of '../home.dart';

extension _FavoriteStorePageView on _HomeState {
  Future<void> _openFavoriteStoreSetting() async {
    List<dynamic> stores = [];
    try {
      final data = await _request('GET', '/store/');
      stores = data['results'] as List? ?? [];
    } catch (error) {
      _toast('$error');
      return;
    }
    if (!mounted) return;
    var searchQuery = '';
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StatefulBuilder(
          builder: (context, refresh) {
            final query = searchQuery.trim().toLowerCase();
            final matches = stores
                .where(
                  (row) => '${row['name']} ${row['address']}'
                      .toLowerCase()
                      .contains(query),
                )
                .toList();
            return Scaffold(
              appBar: AppBar(title: const Text('자주 찾는 매장')),
              body: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: TextField(
                      onChanged: (value) => refresh(() => searchQuery = value),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: '매장 또는 지역 검색',
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final row = Map<String, dynamic>.from(matches[index]);
                        final isFavorite =
                            '${_favoriteStore?['seq']}' == '${row['seq']}';
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 140,
                                width: double.infinity,
                                child: Image.network(
                                  '${AppConfig.apiBaseUrl}/store/${row['seq']}/map',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const ColoredBox(
                                    color: Color(0xFFE8ECEC),
                                    child: Center(
                                      child: Icon(Icons.map_outlined, size: 40),
                                    ),
                                  ),
                                ),
                              ),
                              ListTile(
                                title: Text('${row['name']}'),
                                subtitle: Text('${row['address']}'),
                                trailing: IconButton(
                                  icon: Icon(
                                    isFavorite ? Icons.star : Icons.star_border,
                                    color: isFavorite ? Colors.amber : null,
                                  ),
                                  tooltip: '자주 찾는 매장으로 설정',
                                  onPressed: () async {
                                    if (_localAvailable) {
                                      await LocalDatabase.instance
                                          .deleteRecords(
                                            LocalDatabase.favoriteStore,
                                            where: '1 = ?',
                                            whereArgs: [1],
                                          );
                                      await LocalDatabase.instance.insertRecord(
                                        LocalDatabase.favoriteStore,
                                        {
                                          'store_seq': row['seq'],
                                          'store_name': row['name'],
                                          'address': row['address'],
                                        },
                                      );
                                    }
                                    _updateState(() => _favoriteStore = row);
                                    refresh(() {});
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

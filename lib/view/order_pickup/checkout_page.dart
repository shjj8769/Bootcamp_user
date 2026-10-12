part of '../home.dart';

extension _CheckoutPageView on _HomeState {
  Future<void> _checkout() async {
    try {
      final data = await _request('GET', '/store/');
      final storeRows = (data['results'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      if (!mounted) return;
      if (storeRows.isEmpty) {
        _toast('선택할 수 있는 매장이 없습니다. 서버의 매장 정보를 확인해 주세요.');
        return;
      }

      final favoriteStore = storeRows.firstWhere(
        (row) => '${row['seq']}' == '${_favoriteStore?['seq']}',
        orElse: () => storeRows.first,
      );
      final store = await _selectPickupStore(storeRows, favoriteStore);
      if (store == null || !mounted) return;

      final coupons = await _availableCoupons();
      final subtotal = _cart.values.fold<int>(
        0,
        (sum, row) =>
            sum + (row['product'] as Product).price * (row['quantity'] as int),
      );
      final savedPayment = await _readPaymentMethod() ?? '01';
      if (!mounted) return;

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => OrderCheckoutPage(
            store: store,
            products: _cart.values
                .map((row) => row['product'] as Product)
                .toList(),
            quantities: {
              for (final entry in _cart.entries)
                entry.key: entry.value['quantity'] as int,
            },
            customer: _profile,
            email: _email ?? '',
            coupons: coupons,
            subtotal: subtotal,
            initialPayment: savedPayment,
            onStoreChanged: (selected) =>
                _selectPickupStore(storeRows, selected),
            onPaymentChanged: _savePaymentMethod,
            onPlaceOrder: _placeOrder,
          ),
        ),
      );
    } catch (error) {
      if (mounted) _toast('$error');
    }
  }

  Future<List<Map<String, Object?>>> _availableCoupons() async {
    if (!_localAvailable) return [];
    try {
      final rows = await LocalDatabase.instance.queryRecords(
        LocalDatabase.coupon,
        where: 'status = ?',
        whereArgs: ['available'],
      );
      final today = DateTime.now().toIso8601String().substring(0, 10);
      return rows.where((coupon) {
        final startsAt = '${coupon['start_date'] ?? ''}';
        final expiresAt = '${coupon['exp'] ?? ''}';
        return (startsAt.isEmpty || startsAt.compareTo(today) <= 0) &&
            expiresAt.compareTo(today) >= 0;
      }).toList();
    } catch (_) {
      _localAvailable = false;
      return [];
    }
  }

  Future<Map<String, dynamic>?> _selectPickupStore(
    List<Map<String, dynamic>> stores,
    Map<String, dynamic> initialStore,
  ) async {
    final mapError = await _initializeNaverMap();
    if (!mounted) return null;
    Map<String, dynamic>? selectedStore = initialStore;
    NaverMapController? mapController;
    var query = '';
    var showMap = mapError == null;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (pageContext) => StatefulBuilder(
          builder: (context, refresh) {
            final matches = stores.where((store) {
              final text = '${store['name'] ?? ''} ${store['address'] ?? ''}';
              return text.toLowerCase().contains(query.trim().toLowerCase());
            }).toList();
            final mapStore = selectedStore ?? stores.first;
            final lat = double.tryParse('${mapStore['lat'] ?? ''}');
            final lng = double.tryParse('${mapStore['lng'] ?? ''}');
            return Scaffold(
              appBar: AppBar(title: const Text('매장 찾기')),
              body: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '수령 매장을 선택해 주세요',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text('지도 핀이나 매장 목록에서 지점을 고른 뒤 선택을 눌러 주세요.'),
                          const SizedBox(height: 12),
                          TextField(
                            onChanged: (value) => refresh(() => query = value),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: '매장명 또는 지역 검색',
                            ),
                          ),
                          const SizedBox(height: 8),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: true,
                                icon: Icon(Icons.map_outlined),
                                label: Text('지도 보기'),
                              ),
                              ButtonSegment(
                                value: false,
                                icon: Icon(Icons.list),
                                label: Text('목록 보기'),
                              ),
                            ],
                            selected: {showMap},
                            onSelectionChanged: (values) =>
                                refresh(() => showMap = values.first),
                          ),
                        ],
                      ),
                    ),
                    if (showMap)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          height: 230,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: lat == null || lng == null
                                ? const ColoredBox(
                                    color: Color(0xFFE8ECEC),
                                    child: Center(
                                      child: Text('매장 위치 좌표가 등록되지 않았습니다.'),
                                    ),
                                  )
                                : NaverMap(
                                    options: NaverMapViewOptions(
                                      initialCameraPosition: NCameraPosition(
                                        target: NLatLng(lat, lng),
                                        zoom: 12,
                                      ),
                                    ),
                                    onMapReady: (controller) {
                                      mapController = controller;
                                      final markers = <NMarker>{};
                                      for (final store in stores) {
                                        final storeLat = double.tryParse(
                                          '${store['lat'] ?? ''}',
                                        );
                                        final storeLng = double.tryParse(
                                          '${store['lng'] ?? ''}',
                                        );
                                        if (storeLat == null ||
                                            storeLng == null) {
                                          continue;
                                        }
                                        final marker = NMarker(
                                          id: 'store-${store['seq']}',
                                          position: NLatLng(storeLat, storeLng),
                                          caption: NOverlayCaption(
                                            text: '${store['name'] ?? '매장'}',
                                          ),
                                        );
                                        marker.setOnTapListener((_) {
                                          refresh(() => selectedStore = store);
                                        });
                                        markers.add(marker);
                                      }
                                      controller.addOverlayAll(markers);
                                    },
                                  ),
                          ),
                        ),
                      ),
                    if (mapError != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Text(
                          '$mapError 목록에서 매장을 선택할 수 있습니다.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (matches.isEmpty)
                      const Expanded(child: Center(child: Text('검색 결과가 없습니다.')))
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          itemCount: matches.length,
                          itemBuilder: (context, index) {
                            final store = matches[index];
                            final isSelected =
                                '${store['seq']}' == '${selectedStore?['seq']}';
                            return Card(
                              color: isSelected
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.secondaryContainer
                                  : null,
                              child: ListTile(
                                leading: Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.storefront_outlined,
                                ),
                                title: Text('${store['name'] ?? '매장'}'),
                                subtitle: Text('${store['address'] ?? ''}'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  refresh(() => selectedStore = store);
                                  final storeLat = double.tryParse(
                                    '${store['lat'] ?? ''}',
                                  );
                                  final storeLng = double.tryParse(
                                    '${store['lng'] ?? ''}',
                                  );
                                  if (showMap &&
                                      mapController != null &&
                                      storeLat != null &&
                                      storeLng != null) {
                                    mapController!.updateCamera(
                                      NCameraUpdate.scrollAndZoomTo(
                                        target: NLatLng(storeLat, storeLng),
                                        zoom: 14,
                                      ),
                                    );
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              bottomNavigationBar: SafeArea(
                minimum: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: selectedStore == null
                      ? null
                      : () => Navigator.pop(pageContext),
                  child: Text('${selectedStore?['name'] ?? '매장'} 선택'),
                ),
              ),
            );
          },
        ),
      ),
    );
    return selectedStore;
  }

  Future<String?> _initializeNaverMap() async {
    if (kIsWeb) return 'Naver 지도는 iOS/Android 앱에서 이용할 수 있습니다.';
    if (_naverMapInitialized) return null;
    try {
      final config = await _request('GET', '/store/map/config');
      final clientId = '${config['client_id'] ?? ''}'.trim();
      if (clientId.isEmpty) return '서버에 Naver 지도 Client ID가 설정되지 않았습니다.';
      await FlutterNaverMap().init(
        clientId: clientId,
        onAuthFailed: (exception) => _toast('Naver 지도 인증 실패: $exception'),
      );
      _naverMapInitialized = true;
      return null;
    } catch (error) {
      return 'Naver 지도를 초기화하지 못했습니다: $error';
    }
  }

  Future<String?> _readPaymentMethod() async {
    if (!_localAvailable || _email == null) return null;
    try {
      final rows = await LocalDatabase.instance.queryRecords(
        LocalDatabase.paymentMethod,
        where: 'payment_id = ?',
        whereArgs: [_email],
      );
      return rows.isEmpty ? null : '${rows.first['option']}';
    } catch (_) {
      _localAvailable = false;
      return null;
    }
  }

  Future<void> _savePaymentMethod(String option) async {
    if (!_localAvailable || _email == null) return;
    try {
      await LocalDatabase.instance.insertRecord(LocalDatabase.paymentMethod, {
        'payment_id': _email!,
        'option': option,
      }, conflictAlgorithm: __conflictReplace);
    } catch (_) {
      _localAvailable = false;
    }
  }

  Future<bool> _placeOrder(Map<String, dynamic> store, String payment) async {
    _updateState(() => _busy = true);
    try {
      await _request(
        'POST',
        '/purchase/checkout',
        body: {
          'email': _email,
          'store_seq': store['seq'],
          'payment_method': payment,
          'items': [
            for (final entry in _cart.entries)
              {'SKU': entry.key, 'quantity': entry.value['quantity']},
          ],
        },
      );
      _updateState(_cart.clear);
      if (_localAvailable) {
        await LocalDatabase.instance.deleteRecords(
          LocalDatabase.package,
          where: '1 = ?',
          whereArgs: [1],
        );
      }
      if (mounted) {
        _toast('주문이 완료되었습니다.');
        _updateState(() => _tab = 3);
      }
      return true;
    } catch (error) {
      if (mounted) _toast('$error');
      return false;
    } finally {
      if (mounted) _updateState(() => _busy = false);
    }
  }
}

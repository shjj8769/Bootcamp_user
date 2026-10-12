import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';

import '../../config/app_config.dart';

/// Requests a short-lived pickup token only when opened from the customer's
/// explicit "QR 코드 발급" action. The token is held in memory only.
class PickupQrPage extends StatefulWidget {
  const PickupQrPage({
    required this.order,
    required this.email,
    required this.onTabSelected,
    super.key,
  });

  final Map<String, dynamic> order;
  final String email;
  final ValueChanged<int> onTabSelected;

  @override
  State<PickupQrPage> createState() => _PickupQrPageState();
}

class _PickupQrPageState extends State<PickupQrPage> {
  Timer? _ticker;
  String? _code;
  DateTime? _expiresAt;
  Duration _remaining = Duration.zero;
  String? _error;
  String? _storeName;
  bool _issuing = false;

  int get _orderId => (widget.order['p_id'] as num).toInt();

  bool get _expired => _code != null && _remaining <= Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadPickupStore();
    _issueCode();
  }

  Future<void> _loadPickupStore() async {
    final storeSeq = widget.order['store_seq'];
    if (storeSeq == null) return;
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.apiBaseUrl}/store/'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return;
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return;
      final stores = decoded['results'];
      if (stores is! List) return;
      for (final item in stores.whereType<Map>()) {
        if ('${item['seq']}' == '$storeSeq' && mounted) {
          setState(() => _storeName = '${item['name'] ?? ''}');
          return;
        }
      }
    } catch (_) {
      // Store lookup is supplementary; the order's store_seq remains shown.
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _issueCode() async {
    if (_issuing) return;
    _ticker?.cancel();
    setState(() {
      _issuing = true;
      _error = null;
      _code = null;
      _expiresAt = null;
      _remaining = Duration.zero;
    });

    try {
      final response = await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/qr/issue'),
            headers: const {
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            // Sending a Map with this content type uses form-url-encoded fields.
            body: {'p_id': '$_orderId', 'email': widget.email},
          )
          .timeout(const Duration(seconds: 10));

      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode != 200 || decoded is! Map) {
        throw const _PickupRequestFailure('서버에 연결할 수 없습니다. 다시 시도해 주세요');
      }

      if (decoded['result'] != 'OK') {
        final reason = '${decoded['message'] ?? ''}'.toLowerCase();
        if (reason.contains('already picked up')) {
          throw const _PickupRequestFailure('이미 픽업이 완료된 주문입니다');
        }
        if (reason.contains('order not found')) {
          throw const _PickupRequestFailure('주문 정보를 확인해 주세요');
        }
        throw const _PickupRequestFailure('서버에 연결할 수 없습니다. 다시 시도해 주세요');
      }

      final code = decoded['code'];
      final expiry = DateTime.tryParse(
        '${decoded['expires_at'] ?? ''}',
      )?.toLocal();
      if (code is! String || code.isEmpty || expiry == null) {
        throw const _PickupRequestFailure('서버 응답을 확인할 수 없습니다. 다시 시도해 주세요');
      }

      if (!mounted) return;
      setState(() {
        _code = code;
        _expiresAt = expiry;
        _remaining = expiry.difference(DateTime.now());
      });
      _startCountdown();
    } on _PickupRequestFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } on TimeoutException {
      if (mounted) {
        setState(() => _error = '서버에 연결할 수 없습니다. 다시 시도해 주세요');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = '서버에 연결할 수 없습니다. 다시 시도해 주세요');
      }
    } finally {
      if (mounted) setState(() => _issuing = false);
    }
  }

  void _startCountdown() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final expiry = _expiresAt;
      if (!mounted || expiry == null) return;
      final remaining = expiry.difference(DateTime.now());
      setState(
        () => _remaining = remaining.isNegative ? Duration.zero : remaining,
      );
      if (remaining <= Duration.zero) _ticker?.cancel();
    });
  }

  String get _countdown {
    final seconds = _remaining.inSeconds.clamp(0, 5999);
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainder';
  }

  Future<void> _copyCode() async {
    final code = _code;
    if (code == null || _expired) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('픽업 코드를 복사했습니다.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F8F7),
    appBar: AppBar(
      title: const Text('수령 인증 QR'),
      centerTitle: true,
      backgroundColor: const Color(0xFFF7F8F7),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF5B9877), size: 34),
            const SizedBox(height: 8),
            const Text(
              '매장에서 상품을 수령하세요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              '직원에게 수령 인증 QR을 보여주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF737C7A), fontSize: 13),
            ),
            const SizedBox(height: 20),
            _pickupStoreCard(),
            const SizedBox(height: 12),
            if (_issuing && _code == null)
              const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _errorCard()
            else if (_code != null)
              _qrCard(),
            const SizedBox(height: 12),
            _productCard(),
            const SizedBox(height: 12),
            const Card(
              color: Color(0xFFF0F4F1),
              child: Padding(
                padding: EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '수령 전 확인해 주세요',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '주문한 사이즈와 상품 상태를 매장에서 확인해 주세요.',
                      style: TextStyle(color: Color(0xFF737C7A), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    bottomNavigationBar: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _actionDock(),
        SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: 3,
            onDestinationSelected: widget.onTabSelected,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                label: '홈',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                label: '카테고리',
              ),
              NavigationDestination(
                icon: Icon(Icons.shopping_bag_outlined),
                label: '장바구니',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                label: '주문내역',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                label: '마이',
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _pickupStoreCard() {
    final storeSeq = widget.order['store_seq'];
    final storeName = _storeName?.trim().isNotEmpty == true
        ? _storeName!
        : '픽업 매장${storeSeq == null ? '' : ' · $storeSeq'}';
    return Card(
      color: const Color(0xFFF0F5F1),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Column(
          children: [
            const Icon(Icons.location_on_outlined, size: 20),
            const SizedBox(height: 4),
            Text(
              storeName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(
              '주문번호 $_orderId · 매장 운영시간 내 방문',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF737C7A)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qrCard() => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: Color(0xFFE5E9E6)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text(
            '수령 인증 QR',
            style: TextStyle(
              color: Color(0xFF68716F),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Center(
          child: Opacity(
            opacity: _expired ? .12 : 1,
            child: QrImageView(
              // The QR payload must be exactly the server-issued token.
              data: _code!,
              version: QrVersions.auto,
              size: 238,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SelectableText(
            _code!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 5),
        if (_expired)
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text(
              '만료되었습니다. 새로 발급해 주세요',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 14, top: 4),
            child: Text(
              '남은 시간 $_countdown',
              style: const TextStyle(
                color: Color(0xFF737C7A),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _productCard() {
    final sku = '${widget.order['SKU'] ?? ''}';
    final brand = '${widget.order['pr_brand'] ?? ''}';
    final name = '${widget.order['pr_name'] ?? sku}';
    final color = '${widget.order['color'] ?? ''}';
    final size = '${widget.order['size'] ?? ''}';
    final count = widget.order['p_count'] ?? 1;
    final amount = widget.order['p_price'];
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                '${AppConfig.apiBaseUrl}/product/${Uri.encodeComponent(sku)}/image',
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 70,
                  height: 70,
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
                  Text(brand, style: const TextStyle(fontSize: 11)),
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '$color · $size mm',
                    style: const TextStyle(
                      color: Color(0xFF737C7A),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${amount ?? ''}원  ·  수량 $count',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorCard() => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB54A44), size: 38),
          const SizedBox(height: 10),
          Text(_error!, textAlign: TextAlign.center),
        ],
      ),
    ),
  );

  Widget _actionDock() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: SizedBox(
      height: 52,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1E2B2E),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        onPressed: _issuing
            ? null
            : _expired
            ? _issueCode
            : _error != null
            ? _issueCode
            : _code == null
            ? null
            : _copyCode,
        icon: Icon(_expired || _error != null ? Icons.refresh : Icons.copy),
        label: Text(
          _expired
              ? '새 QR 발급'
              : _error != null
              ? '다시 시도'
              : '수령 인증 코드 복사',
        ),
      ),
    ),
  );
}

class _PickupRequestFailure implements Exception {
  const _PickupRequestFailure(this.message);

  final String message;
}

import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../models/product.dart';
import 'coupon_selection_page.dart';

/// 주문 확인, 결제수단, 쿠폰 선택을 한 화면에서 진행하는 checkout 페이지.
class OrderCheckoutPage extends StatefulWidget {
  const OrderCheckoutPage({
    required this.store,
    required this.products,
    required this.quantities,
    required this.customer,
    required this.email,
    required this.coupons,
    required this.subtotal,
    required this.initialPayment,
    required this.onStoreChanged,
    required this.onPaymentChanged,
    required this.onPlaceOrder,
    super.key,
  });

  final Map<String, dynamic> store;
  final List<Product> products;
  final Map<String, int> quantities;
  final Map<String, dynamic> customer;
  final String email;
  final List<Map<String, Object?>> coupons;
  final int subtotal;
  final String initialPayment;
  final Future<Map<String, dynamic>?> Function(Map<String, dynamic> current)
  onStoreChanged;
  final Future<void> Function(String payment) onPaymentChanged;
  final Future<bool> Function(Map<String, dynamic> store, String payment)
  onPlaceOrder;

  @override
  State<OrderCheckoutPage> createState() => _OrderCheckoutPageState();
}

class _OrderCheckoutPageState extends State<OrderCheckoutPage> {
  late Map<String, dynamic> _store;
  late String _payment;
  Map<String, Object?>? _coupon;
  bool _confirmed = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _store = widget.store;
    _payment = widget.initialPayment;
  }

  int get _discount {
    if (_coupon == null) return 0;
    final value = (_coupon!['discount_rate'] as num?)?.round() ?? 0;
    final amount = _coupon!['discount_type'] == 'fixed'
        ? value
        : (widget.subtotal * value / 100).floor();
    return amount.clamp(0, widget.subtotal);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('주문하기')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _progressHeader(),
            const SizedBox(height: 20),
            _sectionTitle('1. 수령 매장'),
            _storeCard(),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 18),
              child: Text(
                '상품은 선택한 수령 매장으로 발송합니다. 도착 후 수령 안내를 확인해 주세요.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            _sectionTitle('2. 주문 상품'),
            for (final product in widget.products) _productCard(product),
            const SizedBox(height: 18),
            _sectionTitle('3. 주문자 정보'),
            _customerCard(),
            const SizedBox(height: 18),
            _sectionTitle('4. 결제 방법'),
            _paymentChoices(),
            const SizedBox(height: 18),
            _sectionTitle('5. 쿠폰'),
            _couponEntry(),
            const SizedBox(height: 10),
            _priceSummary(),
            const SizedBox(height: 10),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              onChanged: (value) => setState(() => _confirmed = value ?? false),
              title: const Text('상품·수령 매장과 주문 내용을 확인했습니다.'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const Text(
              '연습용 모의 주문입니다. 쿠폰 할인은 화면 시연용이며 서버 주문 금액은 상품 원가 기준으로 처리됩니다.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: FilledButton(
          onPressed: !_confirmed || _submitting ? null : _submit,
          child: Text(
            _submitting
                ? '주문 처리 중…'
                : '₩${_formatMoney(widget.subtotal - _discount)} 모의 결제하기',
          ),
        ),
      ),
    );
  }

  Widget _progressHeader() {
    const labels = ['01 주문 확인', '02 결제', '03 완료'];
    return Row(
      children: [
        for (var index = 0; index < labels.length; index++) ...[
          if (index > 0)
            Expanded(
              child: Divider(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: index == 0
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              labels[index],
              style: TextStyle(
                fontSize: 11,
                fontWeight: index == 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
    ),
  );

  Widget _storeCard() => Card(
    child: ListTile(
      leading: const Icon(Icons.storefront_outlined),
      title: Text('${_store['name'] ?? '수령 매장'}'),
      subtitle: Text('${_store['address'] ?? ''}'),
      trailing: TextButton(onPressed: _changeStore, child: const Text('변경')),
    ),
  );

  Widget _productCard(Product product) {
    final quantity = widget.quantities[product.sku] ?? 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                '${AppConfig.apiBaseUrl}/product/${Uri.encodeComponent(product.sku)}/image',
                width: 76,
                height: 76,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 76,
                  height: 76,
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
                  Text(product.brand, style: const TextStyle(fontSize: 12)),
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text('${product.color} · ${product.size}mm'),
                  Text('₩${_formatMoney(product.price)} · 수량 $quantity'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _customerCard() {
    final name =
        '${widget.customer['c_name'] ?? widget.customer['name'] ?? '주문자'}';
    final phone = '${widget.customer['tel'] ?? widget.customer['phone'] ?? ''}';
    final address =
        '${widget.customer['c_address'] ?? widget.customer['address'] ?? ''}';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text(name),
        subtitle: Text(
          [
            widget.email,
            phone,
            address,
          ].where((value) => value.isNotEmpty).join('\n'),
        ),
      ),
    );
  }

  Widget _paymentChoices() {
    const methods = {'01': '신용 / 체크카드', '02': '카카오페이', '03': '네이버페이'};
    return RadioGroup<String>(
      groupValue: _payment,
      onChanged: (value) async {
        if (value == null) return;
        setState(() => _payment = value);
        await widget.onPaymentChanged(value);
      },
      child: Card(
        child: Column(
          children: [
            for (final method in methods.entries)
              RadioListTile<String>(
                value: method.key,
                title: Text(method.value),
              ),
          ],
        ),
      ),
    );
  }

  Widget _couponEntry() => Card(
    child: ListTile(
      leading: const Icon(Icons.confirmation_number_outlined),
      title: Text(_coupon == null ? '쿠폰 선택' : _couponName(_coupon!)),
      subtitle: Text(
        _coupon == null
            ? '사용 가능한 쿠폰 ${widget.coupons.length}장'
            : '₩${_formatMoney(_discount)} 할인 적용 중',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: widget.coupons.isEmpty ? null : _selectCoupon,
    ),
  );

  Widget _priceSummary() => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _priceRow('상품 금액', widget.subtotal),
          const SizedBox(height: 8),
          _priceRow('쿠폰 할인', -_discount),
          const Divider(height: 22),
          _priceRow('최종 결제 금액', widget.subtotal - _discount, strong: true),
        ],
      ),
    ),
  );

  Widget _priceRow(String label, int amount, {bool strong = false}) {
    final style = TextStyle(
      fontWeight: strong ? FontWeight.w700 : FontWeight.normal,
      fontSize: strong ? 16 : 14,
      color: amount < 0 ? Theme.of(context).colorScheme.primary : null,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text('${amount < 0 ? '-₩' : '₩'}${_formatMoney(amount)}', style: style),
      ],
    );
  }

  Future<void> _selectCoupon() async {
    final result = await Navigator.of(context).push<Map<String, Object?>>(
      MaterialPageRoute(
        builder: (_) => CouponSelectionPage(
          coupons: widget.coupons,
          subtotal: widget.subtotal,
          selectedCouponCode: _coupon?['c_code'] as String?,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _coupon = result.isEmpty ? null : result);
  }

  Future<void> _changeStore() async {
    final confirmedStore = await widget.onStoreChanged(_store);
    if (confirmedStore != null && mounted) {
      setState(() => _store = confirmedStore);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final success = await widget.onPlaceOrder(_store, _payment);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (success) Navigator.pop(context);
  }

  String _couponName(Map<String, Object?> coupon) {
    final code = '${coupon['c_code'] ?? ''}';
    return switch (code) {
      'WELCOME10' => '회원가입 10% 쿠폰',
      'FIRST_REVIEW_10000' => '첫 리뷰 ₩10,000 쿠폰',
      'AUTUMN30' => '가을 시즌 30% 쿠폰',
      _ => code,
    };
  }

  String _formatMoney(int amount) => amount.abs().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
}

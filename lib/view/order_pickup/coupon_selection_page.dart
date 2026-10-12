import 'package:flutter/material.dart';

/// 주문에서 사용할 쿠폰을 고르는 독립 페이지.
/// 선택 결과는 호출한 checkout 화면으로 돌려보내고 별도 저장은 하지 않는다.
class CouponSelectionPage extends StatefulWidget {
  const CouponSelectionPage({
    required this.coupons,
    required this.subtotal,
    this.selectedCouponCode,
    super.key,
  });

  final List<Map<String, Object?>> coupons;
  final int subtotal;
  final String? selectedCouponCode;

  @override
  State<CouponSelectionPage> createState() => _CouponSelectionPageState();
}

class _CouponSelectionPageState extends State<CouponSelectionPage> {
  String? _selectedCode;

  @override
  void initState() {
    super.initState();
    _selectedCode = widget.selectedCouponCode;
  }

  Map<String, Object?>? get _selectedCoupon {
    for (final coupon in widget.coupons) {
      if ('${coupon['c_code'] ?? ''}' == _selectedCode) return coupon;
    }
    return null;
  }

  int get _discount {
    final coupon = _selectedCoupon;
    if (coupon == null) return 0;
    final value = (coupon['discount_rate'] as num?)?.round() ?? 0;
    final amount = coupon['discount_type'] == 'fixed'
        ? value
        : (widget.subtotal * value / 100).floor();
    return amount.clamp(0, widget.subtotal);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('쿠폰 선택')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              children: [
                const Text(
                  '사용할 쿠폰을 선택해 주세요',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  '주문 금액에 적용할 쿠폰은 한 장만 선택할 수 있습니다.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 18),
                _choiceCard(
                  title: '쿠폰 사용 안 함',
                  subtitle: '쿠폰을 적용하지 않고 주문합니다.',
                  selected: _selectedCode == null,
                  leadingText: '선택 안 함',
                  onTap: () => setState(() => _selectedCode = null),
                ),
                const SizedBox(height: 10),
                if (widget.coupons.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 44),
                    child: Column(
                      children: [
                        Icon(Icons.confirmation_number_outlined, size: 40),
                        SizedBox(height: 10),
                        Text('지금 사용할 수 있는 쿠폰이 없습니다.'),
                      ],
                    ),
                  )
                else
                  for (final coupon in widget.coupons) ...[
                    _couponCard(coupon),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.outlineVariant)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _summaryRow(label: '상품 금액', amount: widget.subtotal),
                  const SizedBox(height: 5),
                  _summaryRow(label: '쿠폰 할인', amount: -_discount),
                  const Divider(height: 18),
                  _summaryRow(
                    label: '최종 결제 금액',
                    amount: widget.subtotal - _discount,
                    emphasize: true,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop<Map<String, Object?>>(
                          context,
                          _selectedCoupon ?? <String, Object?>{},
                        );
                      },
                      child: const Text('쿠폰 적용'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _couponCard(Map<String, Object?> coupon) {
    final code = '${coupon['c_code'] ?? ''}';
    final discountType = '${coupon['discount_type'] ?? 'percent'}';
    final value = (coupon['discount_rate'] as num?)?.round() ?? 0;
    final selected = _selectedCode == code;
    final colors = Theme.of(context).colorScheme;
    final startsAt = '${coupon['start_date'] ?? ''}';
    final expiresAt = '${coupon['exp'] ?? ''}';
    return _choiceCard(
      title: _titleFor(code),
      subtitle:
          '${coupon['description'] ?? 'FITPICK 쿠폰'}\n'
          '${_dateRange(startsAt, expiresAt)}',
      selected: selected,
      leadingText: discountType == 'fixed' ? '₩$value' : '$value%',
      trailing: Icon(
        selected ? Icons.check_circle : Icons.radio_button_unchecked,
        color: selected ? colors.primary : colors.outline,
      ),
      onTap: () => setState(() => _selectedCode = code),
    );
  }

  String _titleFor(String code) => switch (code) {
    'WELCOME10' => '회원가입 쿠폰',
    'FIRST_REVIEW_10000' => '리뷰 작성 쿠폰',
    'AUTUMN30' => '가을 시즌 쿠폰',
    _ => code,
  };

  String _dateRange(String start, String end) {
    if (start.isEmpty) return '$end까지 사용 가능';
    return '$start ~ $end';
  }

  Widget _choiceCard({
    required String title,
    required String subtitle,
    required bool selected,
    required String leadingText,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.secondaryContainer : colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? colors.surface : colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  leadingText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: selected ? colors.primary : colors.outline,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow({
    required String label,
    required int amount,
    bool emphasize = false,
  }) {
    final style = TextStyle(
      fontWeight: emphasize ? FontWeight.w700 : FontWeight.normal,
      fontSize: emphasize ? 16 : 14,
      color: amount < 0 ? Theme.of(context).colorScheme.primary : null,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text('$amount원', style: style),
      ],
    );
  }
}

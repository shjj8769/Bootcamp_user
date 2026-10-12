part of '../home.dart';

extension _CouponPageView on _HomeState {
  Future<void> _openLocalSection(String title) async {
    List<Map<String, Object?>> rows = [];
    if (title == '쿠폰') {
      await _ensureDemoCoupons();
      await _unlockFirstReviewCoupon();
    }
    if (_localAvailable) {
      try {
        final db = LocalDatabase.instance;
        if (title == '쿠폰') {
          rows = await db.queryRecords(LocalDatabase.coupon, orderBy: 'exp');
        }
        if (title == '결제수단') {
          rows = await db.queryRecords(
            LocalDatabase.savedPaymentMethod,
            where: 'owner_email = ?',
            whereArgs: [_email],
            orderBy: 'method_seq DESC',
          );
        }
        if (title == '찜한 상품') {
          rows = await db.queryRecords(LocalDatabase.wishlist);
        }
        if (title == '최근 본 상품') {
          rows = await db.queryRecords(
            LocalDatabase.recentlyViewedProduct,
            orderBy: 'view_date DESC',
          );
        }
      } catch (_) {
        _localAvailable = false;
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => StatefulBuilder(
          builder: (context, refresh) => Scaffold(
            appBar: AppBar(
              title: Text(title),
              actions: title == '결제수단'
                  ? [
                      IconButton(
                        tooltip: '결제수단 추가',
                        icon: const Icon(Icons.add),
                        onPressed: () async {
                          final added = await _registerMockPaymentMethod();
                          if (!added || !_localAvailable || !context.mounted) {
                            return;
                          }
                          final updated = await LocalDatabase.instance
                              .queryRecords(
                                LocalDatabase.savedPaymentMethod,
                                where: 'owner_email = ?',
                                whereArgs: [_email],
                                orderBy: 'method_seq DESC',
                              );
                          refresh(() => rows = updated);
                        },
                      ),
                    ]
                  : null,
            ),
            body: rows.isEmpty
                ? Center(
                    child: Text(
                      title == '결제수단'
                          ? '등록된 결제수단이 없습니다. 우측 상단 +를 눌러 추가해 주세요.'
                          : '저장된 항목이 없습니다.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : title == '찜한 상품' || title == '최근 본 상품'
                ? GridView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: rows.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: .62,
                        ),
                    itemBuilder: (context, index) =>
                        _localProductCard(title, rows[index]),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (title == '쿠폰') ...[
                        const Text(
                          '나의 쿠폰함',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('할인 쿠폰은 한 번에 하나만 적용할 수 있습니다.'),
                        const SizedBox(height: 12),
                      ],
                      for (final row in rows) _localRow(title, row),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _localRow(String section, Map<String, Object?> row) {
    if (section == '쿠폰') {
      final code = '${row['c_code'] ?? ''}';
      final discountType = '${row['discount_type'] ?? 'percent'}';
      final value = row['discount_rate'] ?? 0;
      final status = '${row['status'] ?? 'available'}';
      final title = switch (code) {
        'WELCOME10' => '회원가입 10%',
        'FIRST_REVIEW_10000' => '첫 리뷰 ₩10,000',
        'AUTUMN30' => '가을 시즌 30%',
        _ => code,
      };
      final discountLabel = discountType == 'fixed'
          ? '₩${value.toString().replaceAll('.0', '')} 할인'
          : '$value% 할인';
      final startDate = '${row['start_date'] ?? ''}';
      final expiration = '${row['exp'] ?? ''}';
      final isLocked = status == 'locked';
      final expired =
          expiration.isNotEmpty &&
          expiration.compareTo(
                DateTime.now().toIso8601String().substring(0, 10),
              ) <
              0;
      final stateLabel = isLocked
          ? '첫 리뷰 작성 후 사용 가능'
          : expired
          ? '사용 기간 만료'
          : '사용 가능';
      return Card(
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isLocked || expired
                    ? Colors.grey
                    : Theme.of(context).colorScheme.primary,
                width: 5,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: Icon(
                  Icons.confirmation_number_outlined,
                  color: isLocked || expired ? Colors.grey : null,
                ),
                title: Text(title),
                subtitle: Text(discountLabel),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${row['description'] ?? ''}'),
                    const SizedBox(height: 4),
                    Text(
                      '$startDate ~ $expiration',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            stateLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: isLocked || expired ? Colors.grey : null,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '쿠폰 정보 수정',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _editCoupon(row),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (section == '결제수단') {
      final type = '${row['method_type'] ?? ''}';
      final isCard = type == 'card';
      return Card(
        child: ListTile(
          leading: Icon(
            isCard ? Icons.credit_card : Icons.account_balance_wallet_outlined,
          ),
          title: Text('${row['display_name'] ?? '결제수단'}'),
          subtitle: Text(
            isCard
                ? '카드번호 **** ${row['card_last_four'] ?? '----'} · 만료 ${row['expires_on'] ?? '-'}'
                : '이 기기에서 사용하는 간편결제',
          ),
        ),
      );
    }
    final sku = '${row['product_id'] ?? ''}';
    final product = _products.where((item) => item.sku == sku).firstOrNull;
    return ListTile(
      title: Text(product?.name ?? sku),
      subtitle: Text(
        section == '최근 본 상품'
            ? '${row['view_date'] ?? ''}'
            : product?.brand ?? '',
      ),
      trailing: section == '찜한 상품'
          ? IconButton(
              icon: const Icon(Icons.favorite, color: Colors.red),
              onPressed: () async {
                if (product != null) await _toggleWishlist(product);
                if (mounted) Navigator.pop(context);
              },
            )
          : const Icon(Icons.chevron_right),
      onTap: product == null ? null : () => _openProduct(product),
    );
  }

  Widget _localProductCard(String section, Map<String, Object?> row) {
    final sku = '${row['product_id'] ?? ''}';
    final product = _products.where((item) => item.sku == sku).firstOrNull;
    final imageUrl =
        '${AppConfig.apiBaseUrl}/product/${Uri.encodeComponent(sku)}/image';

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: product == null ? null : () => _openProduct(product),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: product == null
                  ? const ColoredBox(
                      color: Color(0xFFE8ECEC),
                      child: Center(
                        child: Icon(Icons.image_not_supported_outlined),
                      ),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Color(0xFFE8ECEC),
                        child: Center(
                          child: Icon(Icons.directions_run, size: 42),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product?.brand ?? '상품',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    product?.name ?? sku,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          section == '최근 본 상품'
                              ? '${row['view_date'] ?? ''}'
                              : '${product?.price ?? ''}원',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      if (section == '찜한 상품')
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 36,
                            height: 36,
                          ),
                          tooltip: '찜 해제',
                          icon: const Icon(Icons.favorite, color: Colors.red),
                          onPressed: product == null
                              ? null
                              : () async {
                                  await _toggleWishlist(product);
                                  if (mounted) Navigator.pop(context);
                                },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _registerMockPaymentMethod() async {
    if (_email == null) {
      _toast('로그인 후 결제수단을 등록할 수 있습니다.');
      return false;
    }

    var methodType = 'card';
    var validationMessage = '';
    final cardNumberParts = List.generate(4, (_) => TextEditingController());
    final expiryParts = List.generate(2, (_) => TextEditingController());
    final cvc = TextEditingController();
    var accepted = false;
    try {
      accepted =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => StatefulBuilder(
              builder: (context, refresh) => AlertDialog(
                title: const Text('결제수단 모의 등록'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('등록 유형'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('카드'),
                            selected: methodType == 'card',
                            onSelected: (_) => refresh(() {
                              methodType = 'card';
                              validationMessage = '';
                            }),
                          ),
                          ChoiceChip(
                            label: const Text('간편결제'),
                            selected: methodType != 'card',
                            onSelected: (_) => refresh(() {
                              methodType = 'kakaopay';
                              validationMessage = '';
                            }),
                          ),
                        ],
                      ),
                      if (methodType != 'card') ...[
                        const SizedBox(height: 8),
                        RadioGroup<String>(
                          groupValue: methodType,
                          onChanged: (value) {
                            if (value != null) {
                              refresh(() => methodType = value);
                            }
                          },
                          child: const Column(
                            children: [
                              RadioListTile<String>(
                                contentPadding: EdgeInsets.zero,
                                value: 'kakaopay',
                                title: Text('카카오페이'),
                              ),
                              RadioListTile<String>(
                                contentPadding: EdgeInsets.zero,
                                value: 'naverpay',
                                title: Text('네이버페이'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (methodType == 'card') ...[
                        const SizedBox(height: 8),
                        const Text('카드번호'),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            for (
                              var index = 0;
                              index < cardNumberParts.length;
                              index++
                            ) ...[
                              if (index > 0) const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: cardNumberParts[index],
                                  keyboardType: TextInputType.number,
                                  maxLength: 4,
                                  textAlign: TextAlign.center,
                                  decoration: const InputDecoration(
                                    hintText: '0000',
                                    counterText: '',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('유효기간'),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: expiryParts[0],
                                keyboardType: TextInputType.number,
                                maxLength: 2,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  hintText: 'MM',
                                  counterText: '',
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text('/'),
                            ),
                            Expanded(
                              child: TextField(
                                controller: expiryParts[1],
                                keyboardType: TextInputType.number,
                                maxLength: 2,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  hintText: 'YY',
                                  counterText: '',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: cvc,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'CVC',
                            hintText: '3~4자리 모의 번호',
                            counterText: '',
                          ),
                        ),
                      ],
                      if (validationMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            validationMessage,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      const Text(
                        '연습용 등록입니다. 입력한 CVC는 확인에만 사용하고 저장하지 않습니다.',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('취소'),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (methodType == 'card') {
                        final digits = cardNumberParts
                            .map(
                              (part) => part.text.replaceAll(RegExp(r'\D'), ''),
                            )
                            .join();
                        final month = expiryParts[0].text.trim();
                        final year = expiryParts[1].text.trim();
                        final cvcDigits = cvc.text.replaceAll(
                          RegExp(r'\D'),
                          '',
                        );
                        final monthNumber = int.tryParse(month);
                        if (digits.length != 16 ||
                            month.length != 2 ||
                            monthNumber == null ||
                            monthNumber < 1 ||
                            monthNumber > 12 ||
                            year.length != 2 ||
                            !RegExp(r'^\d{3,4}$').hasMatch(cvcDigits)) {
                          refresh(
                            () => validationMessage =
                                '카드번호 16자리, 유효기간 월·년, 3~4자리 CVC를 확인해 주세요.',
                          );
                          return;
                        }
                      }
                      Navigator.pop(dialogContext, true);
                    },
                    child: const Text('등록'),
                  ),
                ],
              ),
            ),
          ) ??
          false;
      if (!accepted) return false;

      final isCard = methodType == 'card';
      final digits = cardNumberParts
          .map((part) => part.text.replaceAll(RegExp(r'\D'), ''))
          .join();
      final expiresOn =
          '${expiryParts[0].text.trim()}/${expiryParts[1].text.trim()}';
      final displayName = switch (methodType) {
        'kakaopay' => '카카오페이',
        'naverpay' => '네이버페이',
        _ => '신용 / 체크카드',
      };
      await LocalDatabase.instance.insertRecord(
        LocalDatabase.savedPaymentMethod,
        {
          'owner_email': _email!,
          'method_type': methodType,
          'display_name': displayName,
          'card_last_four': isCard ? digits.substring(digits.length - 4) : null,
          'expires_on': isCard ? expiresOn : null,
          'created_at': DateTime.now().toIso8601String(),
        },
      );
      _toast('결제수단을 모의 등록했습니다.');
      return true;
    } catch (error) {
      _toast('결제수단 등록에 실패했습니다 (입력 창 또는 로컬 저장): $error');
      return false;
    } finally {
      cvc.clear();
      for (final part in cardNumberParts) {
        part.dispose();
      }
      for (final part in expiryParts) {
        part.dispose();
      }
      cvc.dispose();
    }
  }

  Future<void> _editCoupon(Map<String, Object?> coupon) async {
    final code = TextEditingController(text: '${coupon['c_code'] ?? ''}');
    final issuer = TextEditingController(text: '${coupon['issuer'] ?? ''}');
    final rate = TextEditingController(
      text: '${coupon['discount_rate'] ?? ''}',
    );
    final expiry = TextEditingController(text: '${coupon['exp'] ?? ''}');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('쿠폰 정보 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(code, '쿠폰 코드'),
              _field(issuer, '발급처'),
              _field(rate, '할인율 (%)', keyboard: TextInputType.number),
              _field(expiry, '사용 기한'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              final seq = coupon['c_seq'];
              final parsedRate = double.tryParse(rate.text.trim());
              if (seq == null || parsedRate == null || parsedRate < 0) {
                _toast('쿠폰 할인율을 확인해 주세요.');
                return;
              }
              try {
                await LocalDatabase.instance.updateRecords(
                  LocalDatabase.coupon,
                  {
                    'c_code': code.text.trim(),
                    'issuer': issuer.text.trim(),
                    'discount_rate': parsedRate,
                    'exp': expiry.text.trim(),
                  },
                  where: 'c_seq = ?',
                  whereArgs: [seq],
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                _toast('이 기기의 쿠폰 정보를 수정했습니다.');
              } catch (error) {
                _toast('수정에 실패했습니다: $error');
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
    code.dispose();
    issuer.dispose();
    rate.dispose();
    expiry.dispose();
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';

import '../config/app_config.dart';
import '../services/local_database.dart';
import 'discover/home_page.dart';
import 'models/product.dart';
import 'order_pickup/order_checkout_page.dart';
import 'order_pickup/pickup_qr_page.dart';
part 'discover/product_detail_page.dart';
part 'discover/product_list_page.dart';
part 'order_pickup/cart_page.dart';
part 'order_pickup/checkout_page.dart';
part 'order_pickup/order_history_page.dart';
part 'order_pickup/order_detail_page.dart';
part 'order_pickup/claim_history_page.dart';
part 'my/notification_page.dart';
part 'my/my_page.dart';
part 'my/profile_page.dart';
part 'my/review_management_page.dart';
part 'my/favorite_store_page.dart';
part 'my/settings_page.dart';
part 'my/customer_support_page.dart';
part 'my/coupon_page.dart';
part 'auth/login_page.dart';

/// Carries the HTTP status so authentication can distinguish bad credentials
/// from server-side failures without exposing request data or passwords.
class ApiRequestException implements Exception {
  const ApiRequestException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

/// FITPICK app shell and shared state; page implementations live in the view tree.
class Home extends StatefulWidget {
  const Home({
    required this.darkMode,
    required this.fontScale,
    required this.onSettingsChanged,
    super.key,
  });

  final bool darkMode;
  final double fontScale;
  final void Function(bool darkMode, double fontScale) onSettingsChanged;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _tab = 0;
  String? _catalogCategory;
  String? _catalogBrand;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _email;
  String? _message;
  bool _signingUp = false;
  Map<String, dynamic> _profile = {};
  Map<String, dynamic>? _favoriteStore;
  List<Product> _products = [];
  List<int> _banners = [];
  final Map<String, Map<String, dynamic>> _cart = {};
  final Set<String> _wishlist = {};
  final List<String> _recent = [];
  final _emailInput = TextEditingController();
  final _passwordInput = TextEditingController();
  final _nameInput = TextEditingController();
  final _phoneInput = TextEditingController();
  final _addressInput = TextEditingController();
  final _genderInput = TextEditingController(text: '남성');
  final _sizeInput = TextEditingController(text: '');
  bool _localAvailable = !kIsWeb;
  bool _naverMapInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadStorefront();
  }

  @override
  void dispose() {
    _emailInput.dispose();
    _passwordInput.dispose();
    _nameInput.dispose();
    _phoneInput.dispose();
    _addressInput.dispose();
    _genderInput.dispose();
    _sizeInput.dispose();
    super.dispose();
  }

  Future<dynamic> _request(String method, String path, {Object? body}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final response = switch (method) {
      'POST' => await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
      'PUT' => await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
      'DELETE' => await http.delete(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body == null ? null : jsonEncode(body),
      ),
      _ => await http.get(uri),
    };
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      decoded = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map ? decoded['detail'] : null;
      throw ApiRequestException(
        response.statusCode,
        detail?.toString() ?? '서버 요청 실패 (${response.statusCode})',
      );
    }
    return decoded;
  }

  Future<void> _loadStorefront() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _request('GET', '/product/');
      final rows = (data['results'] as List? ?? const []).whereType<Map>();
      final products = rows
          .map((row) => Product.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      final bannerData = await _request('GET', '/banner/');
      final bannerRows = (bannerData['results'] as List? ?? const [])
          .whereType<Map>();
      if (mounted) {
        setState(() {
          _products = products;
          _banners = bannerRows.map((row) => row['b_seq'] as int).toList();
        });
      }
      await _restoreLocalData();
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error'.replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restoreLocalData() async {
    if (!_localAvailable) return;
    try {
      final db = LocalDatabase.instance;
      // The local cart is not tied to a persisted login session. Never expose
      // leftovers while signed out; clear them rather than restoring as guest.
      final cartRows = _email == null
          ? <Map<String, Object?>>[]
          : await db.queryRecords(LocalDatabase.package);
      if (_email == null) {
        await _clearStoredCart();
      }
      final wishRows = await db.queryRecords(LocalDatabase.wishlist);
      final recentRows = await db.queryRecords(
        LocalDatabase.recentlyViewedProduct,
        orderBy: 'view_date DESC, view_seq DESC',
      );
      final favoriteRows = await db.queryRecords(LocalDatabase.favoriteStore);
      final bySku = {for (final product in _products) product.sku: product};
      final restored = <String, Map<String, dynamic>>{};
      for (final row in cartRows) {
        final sku = '${row['option_code'] ?? ''}';
        final product = bySku[sku];
        final quantity = row['quantity'];
        if (product != null && quantity is int && quantity > 0) {
          restored[sku] = {'product': product, 'quantity': quantity};
        }
      }
      if (mounted) {
        setState(() {
          _cart
            ..clear()
            ..addAll(restored);
          _wishlist
            ..clear()
            ..addAll(wishRows.map((row) => '${row['product_id']}'));
          _recent
            ..clear()
            ..addAll(recentRows.map((row) => '${row['product_id']}').toSet());
          _favoriteStore = favoriteRows.isEmpty
              ? null
              : {
                  'seq': favoriteRows.first['store_seq'],
                  'name': favoriteRows.first['store_name'],
                  'address': favoriteRows.first['address'],
                };
        });
      }
    } catch (_) {
      _localAvailable = false;
    }
  }

  /// 쿠폰 화면과 가입/로그인에서 데모용 쿠폰을 코드별로 한 번만 준비한다.
  Future<void> _ensureDemoCoupons() async {
    if (!_localAvailable) return;
    try {
      final db = LocalDatabase.instance;
      final rows = await db.queryRecords(LocalDatabase.coupon);
      final existingCodes = rows.map((row) => '${row['c_code']}').toSet();
      final today = DateTime.now();
      String date(DateTime value) =>
          '${value.year.toString().padLeft(4, '0')}-'
          '${value.month.toString().padLeft(2, '0')}-'
          '${value.day.toString().padLeft(2, '0')}';
      final welcomeEnd = date(today.add(const Duration(days: 30)));
      final todayText = date(today);
      final defaults = <Map<String, Object?>>[
        {
          'c_code': 'WELCOME10',
          'issuer': 'FITPICK',
          'discount_rate': 10,
          'discount_type': 'percent',
          'start_date': todayText,
          'exp': welcomeEnd,
          'description': '신규 회원 웰컴 쿠폰',
          'status': 'available',
        },
        {
          'c_code': 'FIRST_REVIEW_10000',
          'issuer': 'FITPICK',
          'discount_rate': 10000,
          'discount_type': 'fixed',
          'start_date': todayText,
          'exp': todayText,
          'description': '첫 구매 리뷰 저장 후 발급',
          'status': 'locked',
        },
        {
          'c_code': 'AUTUMN30',
          'issuer': 'FITPICK',
          'discount_rate': 30,
          'discount_type': 'percent',
          'start_date': '2026-09-20',
          'exp': '2026-10-15',
          'description': '행사 기간에만 사용 가능',
          'status': 'available',
        },
      ];
      for (final coupon in defaults) {
        if (!existingCodes.contains(coupon['c_code'])) {
          await db.insertRecord(LocalDatabase.coupon, coupon);
        }
      }
    } catch (_) {
      _localAvailable = false;
    }
  }

  /// MySQL의 내 리뷰 조회 결과가 있으면 첫 리뷰 쿠폰을 잠금 해제한다.
  Future<void> _unlockFirstReviewCoupon() async {
    if (!_localAvailable || _email == null) return;
    try {
      final data = await _request(
        'GET',
        '/review/customer/${Uri.encodeComponent(_email!)}',
      );
      final reviews = data['results'] as List? ?? const [];
      if (reviews.isEmpty) return;
      final now = DateTime.now();
      final today =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      await LocalDatabase.instance.updateRecords(
        LocalDatabase.coupon,
        {'status': 'available', 'start_date': today, 'exp': today},
        where: 'c_code = ? AND status = ?',
        whereArgs: ['FIRST_REVIEW_10000', 'locked'],
      );
    } catch (_) {
      // 리뷰 조회 실패는 쿠폰/기본 쇼핑 흐름을 막지 않는다.
    }
  }

  Future<void> _storeCart(Product product, int quantity) async {
    if (!_localAvailable) return;
    try {
      final db = LocalDatabase.instance;
      await db.insertRecord(LocalDatabase.package, {
        'option_code': product.sku,
        'size': product.size,
        'color': product.color,
        'product': product.name,
        'quantity': quantity,
      }, conflictAlgorithm: __conflictReplace);
    } catch (_) {
      _localAvailable = false;
    }
  }

  Future<void> _clearStoredCart() async {
    final db = LocalDatabase.instance;
    final rows = await db.queryRecords(LocalDatabase.package);
    for (final row in rows) {
      await db.deleteRecords(
        LocalDatabase.package,
        where: 'option_code = ?',
        whereArgs: [row['option_code']],
      );
    }
  }

  Future<void> _recordRecentlyViewed(String sku) async {
    setState(() {
      _recent.remove(sku);
      _recent.insert(0, sku);
    });
    if (!_localAvailable) return;
    try {
      final db = LocalDatabase.instance;
      await db.deleteRecords(
        LocalDatabase.recentlyViewedProduct,
        where: 'product_id = ?',
        whereArgs: [sku],
      );
      await db.addRecentlyViewedProduct(
        productId: sku,
        viewedAt: DateTime.now(),
      );
    } catch (_) {
      _localAvailable = false;
    }
  }

  Future<void> _toggleWishlist(Product product) async {
    if (_email == null) {
      _goLogin();
      return;
    }
    final saved = _wishlist.contains(product.sku);
    setState(() {
      saved ? _wishlist.remove(product.sku) : _wishlist.add(product.sku);
    });
    if (!_localAvailable) return;
    try {
      final db = LocalDatabase.instance;
      if (saved) {
        await db.deleteRecords(
          LocalDatabase.wishlist,
          where: 'product_id = ?',
          whereArgs: [product.sku],
        );
      } else {
        await db.addWishlistItem(productId: product.sku);
      }
    } catch (_) {
      _localAvailable = false;
    }
  }

  void _addToCart(Product product) {
    if (_email == null) {
      _goLogin();
      return;
    }
    final current = _cart[product.sku]?['quantity'] as int? ?? 0;
    setState(
      () => _cart[product.sku] = {'product': product, 'quantity': current + 1},
    );
    _storeCart(product, current + 1);
    _toast('${product.name}을(를) 장바구니에 담았습니다.');
  }

  Future<void> _logout() async {
    setState(() {
      _email = null;
      _profile = {};
      _cart.clear();
      _tab = 0;
    });
    if (!_localAvailable) return;
    try {
      await _clearStoredCart();
    } catch (_) {
      _localAvailable = false;
    }
  }

  void _goLogin() => setState(() {
    _tab = 5;
    _signingUp = false;
    _message = null;
  });

  Future<void> _authenticate() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_signingUp) {
        await _request(
          'POST',
          '/auth/signup',
          body: {
            'email': _emailInput.text.trim(),
            'password': _passwordInput.text,
            'tel': _phoneInput.text.trim(),
            'c_name': _nameInput.text.trim(),
            'c_gender': _genderInput.text.trim(),
            'c_address': _addressInput.text.trim(),
            'c_path': '',
            'c_size': _sizeInput.text.trim(),
          },
        );
        await _ensureDemoCoupons();
        if (mounted) {
          setState(() {
            _signingUp = false;
            _message = '가입되었습니다. 로그인해 주세요.';
          });
        }
      } else {
        await _request(
          'POST',
          '/auth/login',
          body: {
            'email': _emailInput.text.trim(),
            'password': _passwordInput.text,
          },
        );
        Map<String, dynamic> profileData = {};
        try {
          profileData = Map<String, dynamic>.from(
            await _request(
              'GET',
              '/auth/profile/${Uri.encodeComponent(_emailInput.text.trim())}',
            ),
          );
        } catch (_) {
          // Login must remain usable if optional profile details are unavailable.
        }
        await _ensureDemoCoupons();
        await _unlockFirstReviewCoupon();
        if (mounted) {
          setState(() {
            _email = _emailInput.text.trim().toLowerCase();
            _profile = Map<String, dynamic>.from(profileData);
            _tab = 0;
            _passwordInput.clear();
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = _authErrorMessage(error);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _authErrorMessage(Object error) {
    if (error is ApiRequestException) {
      if (error.statusCode == 401) {
        return '이메일 또는 비밀번호가 올바르지 않습니다.';
      }
      if (error.statusCode == 422) {
        return '입력한 이메일/비밀번호 형식을 확인해 주세요.';
      }
      if (error.statusCode >= 500) {
        return '서버에서 오류가 발생했습니다. 잠시 후 다시 시도해 주세요. (${error.statusCode})';
      }
      return '요청을 처리하지 못했습니다. (${error.statusCode})';
    }
    if (error is http.ClientException || error is FormatException) {
      return '서버에 연결할 수 없습니다. 네트워크와 서버 상태를 확인해 주세요.';
    }
    return '로그인 처리 중 오류가 발생했습니다. 서버 상태를 확인해 주세요.';
  }

  Widget _currentPage() => switch (_tab) {
    0 => HomePage(
      products: _products,
      banners: _banners,
      loading: _loading,
      error: _error,
      onRetry: _loadStorefront,
      onShowCatalog: () => setState(() => _tab = 1),
      onOpenNotifications: _openNotifications,
      onOpenProduct: _openProduct,
    ),
    1 => _catalog(),
    2 => _email == null ? _loginGate() : _cartPage(),
    3 => _orderPage(),
    4 => _myPage(),
    _ => _authPage(),
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: _currentPage(),
        ),
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab > 4 ? 4 : _tab,
      onDestinationSelected: (index) {
        if (index >= 2 && _email == null) {
          _goLogin();
        } else {
          setState(() => _tab = index);
        }
      },
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          label: '홈',
        ),
        const NavigationDestination(
          icon: Icon(Icons.grid_view_outlined),
          label: '카테고리',
        ),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: _email != null && _cart.isNotEmpty,
            label: Text('${_cart.length}'),
            child: const Icon(Icons.shopping_bag_outlined),
          ),
          label: '장바구니',
        ),
        const NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          label: '주문내역',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: '마이',
        ),
      ],
    ),
  );

  void _toast(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  /// Extensions keep page sections in separate files and delegate state changes here.
  void _updateState(VoidCallback update) => setState(update);
}

// The conflict API is referenced through a helper to keep storage writes explicit.
const __conflictReplace = ConflictAlgorithm.replace;

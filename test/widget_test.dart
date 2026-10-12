// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_user/main.dart';
import 'package:project_user/view/discover/home_page.dart';
import 'package:project_user/view/models/product.dart';

void main() {
  testWidgets('FITPICK storefront shows the customer navigation', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('FITPICK'), findsOneWidget);
    expect(find.text('홈'), findsOneWidget);
    expect(find.text('카테고리'), findsWidgets);
    expect(find.text('장바구니'), findsOneWidget);
    expect(find.text('주문내역'), findsOneWidget);
    expect(find.text('마이'), findsOneWidget);
  });

  testWidgets('guest cart entry opens the dedicated login page', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('장바구니').last);
    await tester.pumpAndSettle();

    expect(find.text('로그인'), findsWidgets);
    expect(find.text('로그인 후 이용할 수 있어요.'), findsNothing);

    await tester.tap(find.text('아직 회원이 아니신가요? 회원가입'));
    await tester.pumpAndSettle();
    expect(find.text('회원가입'), findsOneWidget);
    expect(find.text('가입하기'), findsOneWidget);
    expect(find.text('신발 사이즈'), findsOneWidget);
  });

  testWidgets('home filters default to all products and combine selections', (
    tester,
  ) async {
    final products = [
      const Product(
        sku: 'SKU-A',
        code: 'MODEL-A',
        name: 'Model A',
        brand: 'Adidas',
        price: 100,
        category: '데일리',
        gender: '여성',
        size: '230',
        color: 'white',
      ),
      const Product(
        sku: 'SKU-B',
        code: 'MODEL-B',
        name: 'Model B',
        brand: 'Nike',
        price: 200,
        category: '클래식',
        gender: '남녀공용',
        size: '250',
        color: 'black',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomePage(
            products: products,
            banners: const [],
            loading: false,
            error: null,
            onRetry: () async {},
            onShowCatalog: () {},
            onOpenNotifications: () {},
            onOpenProduct: (_) {},
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('home-filtered-count')))
          .data,
      '2개',
    );

    await tester.tap(find.widgetWithText(ChoiceChip, '여성'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('home-filtered-count')))
          .data,
      '1개',
    );

    await tester.tap(find.widgetWithText(ChoiceChip, '전체').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, '클래식'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Nike'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('home-filtered-count')))
          .data,
      '1개',
    );
  });
}

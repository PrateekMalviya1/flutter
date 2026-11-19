import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/models/product.dart';
import 'package:flutter_application_1/services/product_service.dart';

void main() {
  testWidgets('products can be added, totaled, and removed from the cart', (
    WidgetTester tester,
  ) async {
    final product = _product(
      id: 1,
      title: 'Test backpack',
      category: 'Accessories',
      price: 12.5,
    );
    await tester.pumpWidget(
      MyApp(productService: _FakeProductService([product])),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('add-to-cart-1')));
    await tester.pumpAndSettle();
    expect(find.text('Test backpack'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-to-cart-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-to-cart-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cart').last);
    await tester.pumpAndSettle();

    expect(find.text('Test backpack'), findsOneWidget);
    expect(find.text('\$25.00'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('remove-1')));
    await tester.pumpAndSettle();

    expect(find.text('Your cart is empty'), findsOneWidget);
  });

  testWidgets('search filters the product list', (WidgetTester tester) async {
    final products = [
      _product(
        id: 1,
        title: 'Test backpack',
        category: 'Accessories',
        price: 12.5,
      ),
      _product(id: 2, title: 'City sneakers', category: 'Shoes', price: 35),
    ];
    await tester.pumpWidget(
      MyApp(productService: _FakeProductService(products)),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 products'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('product-search')),
      'backpack',
    );
    await tester.pumpAndSettle();

    expect(find.text('1 product'), findsOneWidget);
    expect(find.text('No products found'), findsNothing);
  });
}

Product _product({
  required int id,
  required String title,
  required String category,
  required double price,
}) {
  return Product(
    id: id,
    title: title,
    description: 'A sample product',
    category: category,
    price: price,
    thumbnail: 'https://example.com/image.jpg',
  );
}

class _FakeProductService extends ProductService {
  _FakeProductService(this.products);

  final List<Product> products;

  @override
  Future<List<Product>> fetchProducts() async => products;
}

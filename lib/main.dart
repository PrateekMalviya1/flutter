import 'package:material_ui/material_ui.dart';

import 'models/product.dart';
import 'services/product_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.productService});

  final ProductService? productService;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF176B57);
    return MaterialApp(
      title: 'Market',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: green),
        scaffoldBackgroundColor: const Color(0xFFF6F8F6),
        useMaterial3: true,
      ),
      home: ShopPage(productService: productService ?? ProductService()),
    );
  }
}

class ShopPage extends StatefulWidget {
  const ShopPage({super.key, required this.productService});

  final ProductService productService;

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  late Future<List<Product>> _productsFuture;
  final Map<int, int> _cart = {};
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _productsFuture = widget.productService.fetchProducts();
  }

  void _reloadProducts() {
    setState(() {
      _productsFuture = widget.productService.fetchProducts();
    });
  }

  void _addToCart(Product product) {
    setState(() {
      _cart.update(product.id, (quantity) => quantity + 1, ifAbsent: () => 1);
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${product.title} added to cart'),
          duration: const Duration(seconds: 1),
        ),
      );
  }

  void _changeQuantity(int productId, int change) {
    setState(() {
      final quantity = (_cart[productId] ?? 0) + change;
      if (quantity <= 0) {
        _cart.remove(productId);
      } else {
        _cart[productId] = quantity;
      }
    });
  }

  void _removeFromCart(int productId) {
    setState(() => _cart.remove(productId));
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = _cart.values.fold<int>(
      0,
      (sum, quantity) => sum + quantity,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedTab == 0 ? 'Market' : 'Your cart'),
        centerTitle: false,
        actions: [
          if (_selectedTab == 0)
            IconButton(
              tooltip: 'Open cart',
              onPressed: () => setState(() => _selectedTab = 1),
              icon: Badge(
                isLabelVisible: itemCount > 0,
                label: Text('$itemCount'),
                child: const Icon(Icons.shopping_bag_outlined),
              ),
            ),
        ],
      ),
      body: FutureBuilder<List<Product>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _LoadError(
              message: snapshot.error.toString(),
              onRetry: _reloadProducts,
            );
          }

          final products = snapshot.data ?? const <Product>[];
          if (products.isEmpty) {
            return _LoadError(
              message: 'No products were returned. Please try again.',
              onRetry: _reloadProducts,
            );
          }

          if (_selectedTab == 0) {
            return _ProductList(
              products: products,
              cart: _cart,
              onAdd: _addToCart,
            );
          }
          return _CartView(
            products: products,
            cart: _cart,
            onQuantityChanged: _changeQuantity,
            onRemove: _removeFromCart,
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Shop',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: itemCount > 0,
              label: Text('$itemCount'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: itemCount > 0,
              label: Text('$itemCount'),
              child: const Icon(Icons.shopping_cart),
            ),
            label: 'Cart',
          ),
        ],
      ),
    );
  }
}

enum _ProductSort { recommended, priceLowToHigh, priceHighToLow, name }

class _ProductList extends StatefulWidget {
  const _ProductList({
    required this.products,
    required this.cart,
    required this.onAdd,
  });

  final List<Product> products;
  final Map<int, int> cart;
  final ValueChanged<Product> onAdd;

  @override
  State<_ProductList> createState() => _ProductListState();
}

class _ProductListState extends State<_ProductList> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  _ProductSort _sort = _ProductSort.recommended;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories =
        widget.products.map((product) => product.category).toSet().toList()
          ..sort();
    final activeCategory =
        categories.contains(_selectedCategory) || _selectedCategory == 'All'
        ? _selectedCategory
        : 'All';
    final query = _searchController.text.trim().toLowerCase();
    final visibleProducts = widget.products.where((product) {
      final matchesCategory =
          activeCategory == 'All' || product.category == activeCategory;
      final matchesSearch =
          query.isEmpty ||
          product.title.toLowerCase().contains(query) ||
          product.description.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();

    switch (_sort) {
      case _ProductSort.recommended:
        break;
      case _ProductSort.priceLowToHigh:
        visibleProducts.sort((a, b) => a.price.compareTo(b.price));
      case _ProductSort.priceHighToLow:
        visibleProducts.sort((a, b) => b.price.compareTo(a.price));
      case _ProductSort.name:
        visibleProducts.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WelcomeBanner(productCount: widget.products.length),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('product-search'),
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search products',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: _searchController.clear,
                            icon: const Icon(Icons.close),
                          ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final category in ['All', ...categories])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(category),
                            selected: activeCategory == category,
                            onSelected: (_) {
                              setState(() => _selectedCategory = category);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${visibleProducts.length} ${visibleProducts.length == 1 ? 'product' : 'products'}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(Icons.swap_vert, size: 18),
                    const SizedBox(width: 4),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<_ProductSort>(
                        value: _sort,
                        borderRadius: BorderRadius.circular(14),
                        items: const [
                          DropdownMenuItem(
                            value: _ProductSort.recommended,
                            child: Text('Recommended'),
                          ),
                          DropdownMenuItem(
                            value: _ProductSort.priceLowToHigh,
                            child: Text('Price: low to high'),
                          ),
                          DropdownMenuItem(
                            value: _ProductSort.priceHighToLow,
                            child: Text('Price: high to low'),
                          ),
                          DropdownMenuItem(
                            value: _ProductSort.name,
                            child: Text('Name'),
                          ),
                        ],
                        onChanged: (sort) {
                          if (sort != null) setState(() => _sort = sort);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (visibleProducts.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No products found',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    const Text('Try another search or category.'),
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _selectedCategory = 'All');
                      },
                      child: const Text('Clear filters'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((context, index) {
                final product = visibleProducts[index];
                return _ProductCard(
                  product: product,
                  quantity: widget.cart[product.id] ?? 0,
                  onAdd: () => widget.onAdd(product),
                );
              }, childCount: visibleProducts.length),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.sizeOf(context).width >= 900
                    ? 4
                    : MediaQuery.sizeOf(context).width >= 600
                    ? 3
                    : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: MediaQuery.sizeOf(context).width >= 600
                    ? 0.82
                    : 0.66,
              ),
            ),
          ),
      ],
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.productCount});

  final int productCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF176B57), Color(0xFF2D9476)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -25,
            top: -38,
            child: CircleAvatar(
              radius: 68,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'A LITTLE SOMETHING FOR YOU',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Find your next\nfavorite thing.',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            height: 1.08,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$productCount picks to explore',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.86),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.shopping_basket_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.quantity,
    required this.onAdd,
  });

  final Product product;
  final int quantity;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      color: colors.surfaceContainerHighest,
                      child: Image.network(
                        product.thumbnail,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.image_not_supported_outlined,
                          color: colors.onSurfaceVariant,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 120),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        product.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600, height: 1.2),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatPrice(product.price),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton.filledTonal(
                      key: ValueKey('add-to-cart-${product.id}'),
                      tooltip: 'Add ${product.title} to cart',
                      visualDensity: VisualDensity.compact,
                      onPressed: onAdd,
                      icon: Icon(
                        quantity > 0
                            ? Icons.add_shopping_cart
                            : Icons.add_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartView extends StatelessWidget {
  const _CartView({
    required this.products,
    required this.cart,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  final List<Product> products;
  final Map<int, int> cart;
  final void Function(int productId, int change) onQuantityChanged;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final cartProducts = products
        .where((product) => cart.containsKey(product.id))
        .toList(growable: false);
    final total = cartProducts.fold<double>(
      0,
      (sum, product) => sum + product.price * cart[product.id]!,
    );

    if (cartProducts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Your cart is empty',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text('Add a few things from the shop to get started.'),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            children: [
              for (final product in cartProducts)
                _CartItem(
                  product: product,
                  quantity: cart[product.id]!,
                  onQuantityChanged: (change) =>
                      onQuantityChanged(product.id, change),
                  onRemove: () => onRemove(product.id),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        _formatPrice(total),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${cart.values.fold<int>(0, (sum, count) => sum + count)} items',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CartItem extends StatelessWidget {
  const _CartItem({
    required this.product,
    required this.quantity,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  final Product product;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                product.thumbnail,
                width: 68,
                height: 68,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 68,
                  height: 68,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.image_not_supported_outlined),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(_formatPrice(product.price * quantity)),
                  Row(
                    children: [
                      IconButton(
                        key: ValueKey('decrease-${product.id}'),
                        tooltip: 'Decrease quantity',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onQuantityChanged(-1),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('$quantity'),
                      IconButton(
                        key: ValueKey('increase-${product.id}'),
                        tooltip: 'Increase quantity',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onQuantityChanged(1),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              key: ValueKey('remove-${product.id}'),
              tooltip: 'Remove ${product.title}',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 48),
            const SizedBox(height: 12),
            Text(
              'Could not load products',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatPrice(double price) => '\$${price.toStringAsFixed(2)}';

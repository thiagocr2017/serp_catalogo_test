import 'package:go_router/go_router.dart';

import '../presentation/pages/catalog_pdf_page.dart';
import '../presentation/pages/category_page.dart';
import '../presentation/pages/product_form_page.dart';
import '../presentation/pages/product_list_page.dart';
import '../presentation/pages/product_profile_page.dart';
import '../presentation/pages/product_transfer_page.dart';
import '../presentation/pages/promotion_form_page.dart';
import '../presentation/pages/promotion_page.dart';

final List<RouteBase> productRoutes = [
  GoRoute(
    path: '/products',
    builder: (context, state) => const ProductListPage(),
    routes: [
      GoRoute(
        path: 'new',
        builder: (context, state) => const ProductFormPage(),
      ),
      GoRoute(
        path: ':productId/edit',
        builder: (context, state) => ProductFormPage(
          productId: state.pathParameters['productId']!,
          returnToList: state.uri.queryParameters['returnTo'] == 'list',
        ),
      ),
      GoRoute(
        path: ':productId',
        builder: (context, state) =>
            ProductProfilePage(productId: state.pathParameters['productId']!),
      ),
    ],
  ),
  GoRoute(
    path: '/categories',
    builder: (context, state) => const CategoryPage(),
  ),
  GoRoute(
    path: '/promotions',
    builder: (context, state) => const PromotionPage(),
    routes: [
      GoRoute(
        path: 'new',
        builder: (context, state) => const PromotionFormPage(),
      ),
      GoRoute(
        path: ':id/edit',
        builder: (context, state) =>
            PromotionFormPage(id: state.pathParameters['id']!),
      ),
    ],
  ),
  GoRoute(
    path: '/catalog-export',
    builder: (context, state) => const CatalogPdfPage(),
  ),
  GoRoute(
    path: '/product-transfer',
    builder: (context, state) => const ProductTransferPage(),
  ),
];

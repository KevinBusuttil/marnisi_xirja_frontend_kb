import 'package:flutter/material.dart';
import 'package:web_admin/app_router.dart';
import 'package:web_admin/helpers/marnisi_pos_restrictions.dart';
import 'package:web_admin/views/widgets/portal_master_layout/portal_master_layout.dart';
import 'package:web_admin/views/widgets/portal_master_layout/sidebar.dart';

//sample data create categories
final Map<String, List<String>> categoriesAndProducts = {
  'Category1': ['Product1_1', 'Product1_2', 'Product1_3'],
  'Category2': ['Product2_1', 'Product2_2', 'Product2_3', 'Product2_4'],
  'Category3': [
    'Product3_1',
    'Product3_2',
    'Product3_3',
    'Product3_4',
    'Product3_5'
  ],
  'Category4': [
    'Product4_1',
    'Product4_2',
    'Product4_3',
    'Product4_4',
    'Product4_5',
    'Product4_6'
  ],
};

//function to generate menu options
List<SidebarChildMenuConfig> generateMenuOptions(
    Map<String, List<String>> categoriesAndProducts) {
  return categoriesAndProducts.entries.map((categoryEntry) {
    String category = categoryEntry.key;
    List<SidebarChildMenuConfig> productConfigs =
        categoryEntry.value.map((product) {
      return SidebarChildMenuConfig(
        uri: '/${category.toLowerCase()}/${product.toLowerCase()}',
        // uri: '/${product.toLowerCase()}',
        icon: Icons.short_text_sharp,
        title: (context) => product,
      );
    }).toList();

    return SidebarChildMenuConfig(
      uri: '/${category.toLowerCase()}',
      icon: Icons.pix_outlined,
      title: (context) => category,
      children: productConfigs,
    );
  }).toList();
}

final List<SidebarChildMenuConfig> additionalMenuOptions =
    generateMenuOptions(categoriesAndProducts);

// add extra menu items here
final sidebarMenuConfigs = [
  SidebarMenuConfig(
    uri: RouteUri.dashboard,
    icon: Icons.dashboard_rounded,
    title: (context) => 'Home',
  ),
  SidebarMenuConfig(
    uri: '',
    icon: Icons.interests_rounded,
    title: (context) => 'Sales',
    children: [
      SidebarChildMenuConfig(
        uri: RouteUri.salesRegister,
        icon: Icons.app_registration_rounded,
        title: (context) => 'Register',
      ),
      SidebarChildMenuConfig(
        uri: RouteUri.salesHistory,
        icon: Icons.short_text_sharp,
        title: (context) => 'Sales History',
      ),
      if (!MarnisiPosRestrictions.hideTourManagementMenu)
        SidebarChildMenuConfig(
          uri: RouteUri.tourManagement,
          icon: Icons.wine_bar_rounded,
          title: (context) => 'Tour Management',
          visibleForRoles: {
            'Super Admin',
            'System Manager',
            'Vineyard Admin',
            'Vineyard Staff',
          },
        ),
      // SidebarChildMenuConfig(
      //   uri: RouteUri.salesReport,
      //   icon: Icons.short_text_sharp,
      //   title: (context) => 'Report History',
      // ),
    ],
  ),
  // SidebarMenuConfig(
  //   uri: RouteUri.billing,
  //   icon: Icons.payment_rounded,
  //   title: (context) => 'Inventory',
  // ),
  SidebarMenuConfig(
    uri: RouteUri.inventory,
    icon: Icons.inventory_2_rounded,
    title: (context) => 'Item Management',
    visibleForRoles: {
      'Super Admin',
      'System Manager',
      'Vineyard Admin',
    },
  ),
  // SidebarMenuConfig(
  //   uri: RouteUri.deliveries,
  //   icon: Icons.delivery_dining_sharp,
  //   title: (context) => 'Deliveries',
  // ),
  // SidebarMenuConfig(
  //   uri: RouteUri.customers,
  //   icon: Icons.supervised_user_circle_outlined,
  //   title: (context) => 'Customers',
  // ),
  SidebarMenuConfig(
    uri: '',
    icon: Icons.settings_applications_sharp,
    title: (context) => 'Settings',
    children: [
      SidebarChildMenuConfig(
        uri: RouteUri.generalSettings,
        icon: Icons.settings,
        title: (context) => 'General Settings',
      ),
      // SidebarChildMenuConfig(
      //   uri: RouteUri.securityOptions,
      //   icon: Icons.short_text_sharp,
      //   title: (context) => 'Security Options',
      // ),
      // SidebarChildMenuConfig(
      //   uri: RouteUri.privacy,
      //   icon: Icons.short_text_sharp,
      //   title: (context) => 'Privacy',
      // ),
    ],
  ),
];

const localeMenuConfigs = [
  LocaleMenuConfig(
    languageCode: 'en',
    name: 'English',
  ),
  // LocaleMenuConfig(
  //   languageCode: 'mt',
  //   // scriptCode: 'Hans',
  //   name: 'Maltease',
  // ),
];

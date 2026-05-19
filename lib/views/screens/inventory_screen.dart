import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_admin/constants/dimens.dart';
import 'package:web_admin/constants/shared_values.dart';
import 'package:web_admin/helpers/marnisi_image_helper.dart';
import 'package:web_admin/providers/user_data_provider.dart';
import 'package:web_admin/services/marnisi_api_service.dart';
import 'package:web_admin/theme/theme_extensions/app_color_scheme.dart';
import 'package:web_admin/views/widgets/marnisi_app_background.dart';
import 'package:web_admin/views/widgets/portal_master_layout/portal_master_layout.dart';
import 'package:web_admin/views/widgets/public_master_layout/public_master_layout.dart';

class Inventory extends StatelessWidget {
  const Inventory({super.key});

  @override
  Widget build(BuildContext context) {
    final userDataProvider = context.read<UserDataProvider>();

    if (userDataProvider.isUserLoggedIn()) {
      return const PortalMasterLayout(
        body: _ItemManagementBody(),
      );
    }

    return const PublicMasterLayout(
      body: _ItemManagementBody(),
    );
  }
}

class _ItemManagementBody extends StatefulWidget {
  const _ItemManagementBody();

  @override
  State<_ItemManagementBody> createState() => _ItemManagementBodyState();
}

class _ItemManagementBodyState extends State<_ItemManagementBody> {
  final MarnisiApiService _api = const MarnisiApiService();
  final TextEditingController _searchController = TextEditingController();

  MarnisiSessionContext? _context;
  List<Map<String, dynamic>> _items = const [];
  List<Map<String, dynamic>> _movements = const [];

  String _selectedVineyard = '';
  String _selectedItemIdForMovements = '';
  String _errorMessage = '';
  String _sessionCookie = '';

  bool _loadingContext = true;
  bool _loadingItems = false;
  bool _loadingMovements = false;
  bool _lowStockOnly = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadContextAndItems());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContextAndItems() async {
    setState(() {
      _loadingContext = true;
      _errorMessage = '';
    });

    try {
      final contextData = await _api.getContext();
      final fallbackVineyard = contextData.vineyards.isNotEmpty
          ? (contextData.vineyards.first['vineyard'] ?? '').toString()
          : '';

      final selected = contextData.defaultVineyard.isNotEmpty
          ? contextData.defaultVineyard
          : fallbackVineyard;

      setState(() {
        _context = contextData;
        _selectedVineyard = selected;
      });

      if (selected.isNotEmpty) {
        await _loadItems();
        await _loadMovements();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loadingContext = false);
      }
    }
  }

  Future<void> _loadItems() async {
    if (_selectedVineyard.isEmpty) return;

    setState(() {
      _loadingItems = true;
      _errorMessage = '';
    });

    try {
      final items = await _api.listItems(
        vineyard: _selectedVineyard,
        search: _searchController.text,
        lowStock: _lowStockOnly,
      );
      final prefs = await SharedPreferences.getInstance();
      final apiBaseUrl = (prefs.getString(StorageKeys.apiBaseUrl) ??
              prefs.getString('apiBaseUrl') ??
              '')
          .trim();
      final normalizedItems = items.map((row) {
        final updated = Map<String, dynamic>.from(row);
        updated['image_path'] = MarnisiImageHelper.resolveItemImagePath(
          rawPath: (row['image_path'] ?? '').toString(),
          apiBaseUrl: apiBaseUrl,
        );
        return updated;
      }).toList(growable: false);
      final sessionCookie = await MarnisiImageHelper.readSessionCookie();

      setState(() {
        _items = normalizedItems;
        _sessionCookie = sessionCookie;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loadingItems = false);
      }
    }
  }

  Future<void> _loadMovements({String? itemId}) async {
    if (_selectedVineyard.isEmpty) return;

    setState(() {
      _loadingMovements = true;
      if (itemId != null) {
        _selectedItemIdForMovements = itemId;
      }
    });

    try {
      final movements = await _api.listItemMovements(
        vineyard: _selectedVineyard,
        itemId: _selectedItemIdForMovements.isEmpty
            ? null
            : _selectedItemIdForMovements,
        limit: 50,
      );

      setState(() {
        _movements = movements;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loadingMovements = false);
      }
    }
  }

  Future<void> _toggleEnabled(Map<String, dynamic> item) async {
    final contextData = _context;
    if (contextData == null || !contextData.canAdminMutate) {
      _showSnackbar('Only vineyard admins can enable or disable items');
      return;
    }

    final itemId = (item['name'] ?? '').toString();
    final enabled = _asInt(item['is_enabled']) == 1;

    try {
      await _api.setItemEnabled(itemId: itemId, enabled: !enabled);
      _showSnackbar('Item status updated');
      await _loadItems();
      await _loadMovements(itemId: itemId);
    } catch (e) {
      _showSnackbar(e.toString());
    }
  }

  Future<void> _openCreateOrEditItemDialog({Map<String, dynamic>? item}) async {
    final contextData = _context;
    if (contextData == null || !contextData.canAdminMutate) {
      _showSnackbar('Only vineyard admins can create or edit items');
      return;
    }

    final isEdit = item != null;

    final itemCodeController = TextEditingController(
      text: (item?['item_code'] ?? '').toString(),
    );
    final itemNameController = TextEditingController(
      text: (item?['item_name'] ?? '').toString(),
    );
    final categoryController = TextEditingController(
      text: (item?['category'] ?? 'Maltese Wines').toString(),
    );
    final brandController = TextEditingController(
      text: (item?['brand'] ?? 'Marsovin').toString(),
    );
    final priceController = TextEditingController(
      text: (item?['sell_price'] ?? 0).toString(),
    );
    final lowStockController = TextEditingController(
      text: (item?['low_stock_threshold'] ?? 5).toString(),
    );
    final unitController = TextEditingController(
      text: (item?['unit'] ?? 'Bottle').toString(),
    );
    final stockController = TextEditingController(
      text: (item?['stock_qty'] ?? 0).toString(),
    );

    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Item' : 'Create Item'),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: itemCodeController,
                      enabled: !isEdit,
                      decoration: const InputDecoration(labelText: 'Item Code'),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Item code is required'
                              : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: itemNameController,
                      decoration: const InputDecoration(labelText: 'Item Name'),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Item name is required'
                              : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: categoryController,
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: brandController,
                      decoration: const InputDecoration(labelText: 'Brand'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: priceController,
                            decoration:
                                const InputDecoration(labelText: 'Sell Price'),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: lowStockController,
                            decoration: const InputDecoration(
                                labelText: 'Low Stock Threshold'),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: unitController,
                            decoration:
                                const InputDecoration(labelText: 'Unit'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: stockController,
                            decoration:
                                const InputDecoration(labelText: 'Stock Qty'),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: Text(isEdit ? 'Save' : 'Create'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final sellPrice = double.tryParse(priceController.text.trim()) ?? 0;
    final lowStockThreshold =
        double.tryParse(lowStockController.text.trim()) ?? 0;
    final stockQty = double.tryParse(stockController.text.trim()) ?? 0;

    try {
      if (isEdit) {
        await _api.updateItem(
          itemId: (item['name'] ?? '').toString(),
          itemName: itemNameController.text.trim(),
          category: categoryController.text.trim(),
          brand: brandController.text.trim(),
          sellPrice: sellPrice,
          lowStockThreshold: lowStockThreshold,
          unit: unitController.text.trim(),
        );

        // Stock updates are tracked with explicit movement entries.
        await _api.adjustStock(
          itemId: (item['name'] ?? '').toString(),
          mode: 'set',
          setQty: stockQty,
          reason: 'Item edit stock sync from Item Management',
        );
      } else {
        await _api.createItem(
          vineyard: _selectedVineyard,
          itemCode: itemCodeController.text.trim(),
          itemName: itemNameController.text.trim(),
          category: categoryController.text.trim(),
          brand: brandController.text.trim(),
          sellPrice: sellPrice,
          lowStockThreshold: lowStockThreshold,
          unit: unitController.text.trim(),
          stockQty: stockQty,
          imagePath: 'assets/items/1.png',
        );
      }

      _showSnackbar(isEdit ? 'Item updated' : 'Item created');
      await _loadItems();
      await _loadMovements();
    } catch (e) {
      _showSnackbar(e.toString());
    }
  }

  Future<void> _openStockDialog(Map<String, dynamic> item, String mode) async {
    final contextData = _context;
    if (contextData == null || !contextData.canAdminMutate) {
      _showSnackbar('Only vineyard admins can adjust stock');
      return;
    }

    final quantityController = TextEditingController();
    final reasonController = TextEditingController(
      text: mode == 'set'
          ? 'Manual stock set from UI'
          : 'Manual stock delta from UI',
    );

    final title = mode == 'set' ? 'Set Stock' : 'Adjust Stock (+/-)';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${item['item_code']} - ${item['item_name']}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: InputDecoration(
                    labelText:
                        mode == 'set' ? 'Set Quantity' : 'Delta Quantity',
                    helperText: mode == 'delta'
                        ? 'Use negative quantity to reduce stock'
                        : 'Final quantity for this item',
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'Reason'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final parsedQty = double.tryParse(quantityController.text.trim());
    if (parsedQty == null) {
      _showSnackbar('Invalid quantity');
      return;
    }

    try {
      await _api.adjustStock(
        itemId: (item['name'] ?? '').toString(),
        mode: mode,
        setQty: mode == 'set' ? parsedQty : null,
        deltaQty: mode == 'delta' ? parsedQty : null,
        reason: reasonController.text.trim(),
      );
      _showSnackbar('Stock updated');
      await _loadItems();
      await _loadMovements(itemId: (item['name'] ?? '').toString());
    } catch (e) {
      _showSnackbar(e.toString());
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final appColorScheme = Theme.of(context).extension<AppColorScheme>()!;

    return Stack(
      children: [
        const Positioned.fill(
          child: MarnisiAppBackground(),
        ),
        ListView(
          padding: const EdgeInsets.all(kDefaultPadding),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Item Management',
                    style: themeData.textTheme.headlineMedium?.copyWith(
                      color: appColorScheme.warning,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh context',
                  onPressed: _loadingContext ? null : _loadContextAndItems,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loadingContext)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              _buildMainContent(),
          ],
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    if (_context == null) {
      return _inlineError(
        _errorMessage.isNotEmpty
            ? _errorMessage
            : 'Unable to fetch Marnisi session context.',
      );
    }

    final contextData = _context!;

    if (_selectedVineyard.isEmpty) {
      return _inlineError('No vineyard assignment found for current user.');
    }

    final vineyards = contextData.vineyards;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          runSpacing: 8,
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: DropdownButtonFormField<String>(
                value: _selectedVineyard,
                decoration: const InputDecoration(
                  labelText: 'Vineyard',
                  border: OutlineInputBorder(),
                ),
                items: vineyards
                    .map(
                      (row) => DropdownMenuItem<String>(
                        value: (row['vineyard'] ?? '').toString(),
                        child: Text(
                          ((row['vineyard'] ?? '').toString()) +
                              ' (${(row['access_role'] ?? '').toString()})',
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null || value.isEmpty) return;
                  setState(() {
                    _selectedVineyard = value;
                    _selectedItemIdForMovements = '';
                  });
                  unawaited(_loadItems());
                  unawaited(_loadMovements());
                },
              ),
            ),
            SizedBox(
              width: 320,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search item',
                  hintText: 'Code, name, category, brand',
                  suffixIcon: IconButton(
                    onPressed: _loadingItems ? null : _loadItems,
                    icon: const Icon(Icons.search),
                  ),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => unawaited(_loadItems()),
                onChanged: (value) {
                  if (value.trim().isEmpty) {
                    unawaited(_loadItems());
                  }
                },
              ),
            ),
            FilterChip(
              label: const Text('Low Stock Only'),
              selected: _lowStockOnly,
              onSelected: (value) {
                setState(() => _lowStockOnly = value);
                unawaited(_loadItems());
              },
            ),
            if (contextData.canAdminMutate)
              FilledButton.icon(
                onPressed: () => _openCreateOrEditItemDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (_errorMessage.isNotEmpty) _inlineError(_errorMessage),
        const SizedBox(height: 8),
        _buildItemsGrid(contextData),
        const SizedBox(height: 14),
        _buildMovementsPanel(),
      ],
    );
  }

  Widget _buildItemsGrid(MarnisiSessionContext contextData) {
    if (_loadingItems) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No items found for selected vineyard.'),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1400
            ? 4
            : width >= 1000
                ? 3
                : width >= 680
                    ? 2
                    : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.95,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (_, index) {
            final item = _items[index];
            final enabled = _asInt(item['is_enabled']) == 1;
            final itemId = (item['name'] ?? '').toString();
            final selected = _selectedItemIdForMovements == itemId;

            return Card(
              elevation: selected ? 4 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: selected ? Colors.orange : Colors.transparent,
                  width: 1.3,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SizedBox(
                      width: double.infinity,
                      child: (() {
                        final imagePath = (item['image_path'] ?? '').toString();
                        if (MarnisiImageHelper.isNetworkImagePath(imagePath)) {
                          return Image.network(
                            imagePath,
                            headers:
                                MarnisiImageHelper.networkImageHeadersForPath(
                              path: imagePath,
                              sessionCookie: _sessionCookie,
                            ),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              return Container(
                                color: Colors.black12,
                                alignment: Alignment.center,
                                child: const Icon(Icons.wine_bar_rounded,
                                    size: 44),
                              );
                            },
                          );
                        }
                        return Image.asset(
                          imagePath.isEmpty
                              ? MarnisiImageHelper.fallbackItemAssetPath
                              : imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return Container(
                              color: Colors.black12,
                              alignment: Alignment.center,
                              child:
                                  const Icon(Icons.wine_bar_rounded, size: 44),
                            );
                          },
                        );
                      })(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (item['item_name'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (item['item_code'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item['category']} | ${item['brand']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'EUR ${(item['sell_price'] ?? 0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.orange,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Stock Qty: ${(item['stock_qty'] ?? 0)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _loadMovements(itemId: itemId),
                                icon: const Icon(Icons.history, size: 16),
                                label: const Text('History'),
                              ),
                            ),
                          ],
                        ),
                        if (contextData.canAdminMutate) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      _openCreateOrEditItemDialog(item: item),
                                  child: const Text('Edit'),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      _openStockDialog(item, 'delta'),
                                  child: const Text('Adjust Stock'),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      _openStockDialog(item, 'set'),
                                  child: const Text('Set Stock'),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text('Enabled',
                                  style: TextStyle(fontSize: 12)),
                              Switch(
                                value: enabled,
                                onChanged: (_) => _toggleEnabled(item),
                              ),
                            ],
                          ),
                        ] else
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              enabled ? 'Enabled' : 'Disabled',
                              style: TextStyle(
                                color: enabled ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMovementsPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Stock Movement History',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: _loadingMovements ? null : _loadMovements,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_selectedItemIdForMovements.isNotEmpty)
              Text('Filtered by item: $_selectedItemIdForMovements'),
            const SizedBox(height: 8),
            if (_loadingMovements)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_movements.isEmpty)
              const Text('No movement entries found.')
            else
              SizedBox(
                height: 240,
                child: ListView.separated(
                  itemBuilder: (_, index) {
                    final movement = _movements[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        '${movement['movement_type']} | ${movement['qty_before']} -> ${movement['qty_after']}',
                      ),
                      subtitle: Text(
                        '${movement['creation']} | ${movement['reason'] ?? ''}',
                      ),
                      trailing: Text((movement['actor_user'] ?? '').toString()),
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemCount: _movements.length,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _inlineError(String message) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_admin/constants/dimens.dart';
import 'package:web_admin/providers/user_data_provider.dart';
import 'package:web_admin/services/marnisi_api_service.dart';
import 'package:web_admin/theme/theme_extensions/app_color_scheme.dart';
import 'package:web_admin/theme/theme_extensions/app_container_theme.dart';
import 'package:web_admin/views/widgets/portal_master_layout/portal_master_layout.dart';
import 'package:web_admin/views/widgets/public_master_layout/public_master_layout.dart';

class TourManagementScreen extends StatelessWidget {
  const TourManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userDataProvider = context.read<UserDataProvider>();

    if (userDataProvider.isUserLoggedIn()) {
      return const PortalMasterLayout(
        body: _TourManagementBody(),
      );
    }

    return const PublicMasterLayout(
      body: _TourManagementBody(),
    );
  }
}

class _TourManagementBody extends StatefulWidget {
  const _TourManagementBody();

  @override
  State<_TourManagementBody> createState() => _TourManagementBodyState();
}

class _TourManagementBodyState extends State<_TourManagementBody>
    with SingleTickerProviderStateMixin {
  final MarnisiApiService _api = const MarnisiApiService();

  late TabController _tabController;

  MarnisiSessionContext? _context;
  String _selectedVineyard = '';

  List<Map<String, dynamic>> _items = const [];
  List<Map<String, dynamic>> _packages = const [];
  List<Map<String, dynamic>> _bookings = const [];

  bool _loading = true;
  bool _loadingPackages = false;
  bool _loadingBookings = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    unawaited(_loadContext());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadContext() async {
    setState(() {
      _loading = true;
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
        await _refreshAll();
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadItems(),
      _loadPackages(),
      _loadBookings(),
    ]);
  }

  Future<void> _loadItems() async {
    if (_selectedVineyard.isEmpty) return;
    try {
      final items = await _api.listItems(vineyard: _selectedVineyard);
      setState(() => _items = items);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  Future<void> _loadPackages() async {
    if (_selectedVineyard.isEmpty) return;
    setState(() => _loadingPackages = true);
    try {
      final data = await _api.listPackages(vineyard: _selectedVineyard);
      setState(() => _packages = data);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingPackages = false);
      }
    }
  }

  Future<void> _loadBookings() async {
    if (_selectedVineyard.isEmpty) return;
    setState(() => _loadingBookings = true);
    try {
      final data = await _api.listBookings(vineyard: _selectedVineyard);
      setState(() => _bookings = data);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingBookings = false);
      }
    }
  }

  Future<void> _openPackageDialog(
      {Map<String, dynamic>? currentPackage}) async {
    final contextData = _context;
    if (contextData == null || !contextData.canAdminMutate) {
      _showSnackbar('Only vineyard admins can create or update packages');
      return;
    }

    if (_items.isEmpty) {
      _showSnackbar('No vineyard items available. Create items first.');
      return;
    }

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(
      text: (currentPackage?['package_name'] ?? '').toString(),
    );
    final descController = TextEditingController(
      text: (currentPackage?['description'] ?? '').toString(),
    );
    final priceController = TextEditingController(
      text: (currentPackage?['price_per_person'] ?? 0).toString(),
    );
    final maxGroupController = TextEditingController(
      text: (currentPackage?['max_group_size'] ?? 0).toString(),
    );

    final existingWines =
        (currentPackage?['wines'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);

    final selectedWineIds = <String>{
      for (final row in existingWines) (row['vineyard_item'] ?? '').toString(),
    };

    String selectedTier =
        (currentPackage?['package_tier'] ?? 'Silver').toString();
    if (nameController.text.trim().isEmpty && selectedTier != 'Custom') {
      nameController.text = 'Tour $selectedTier';
    }
    double tastingQty = existingWines.isNotEmpty
        ? double.tryParse((existingWines.first['tasting_qty_per_guest'] ?? 1)
                .toString()) ??
            1
        : 1;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(currentPackage == null
                  ? 'Create Tour Package'
                  : 'Edit Tour Package'),
              content: SizedBox(
                width: 680,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration:
                              const InputDecoration(labelText: 'Package Name'),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? 'Package name is required'
                                  : null,
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedTier,
                          decoration: const InputDecoration(labelText: 'Tier'),
                          items: const [
                            DropdownMenuItem(
                                value: 'Silver', child: Text('Silver')),
                            DropdownMenuItem(
                                value: 'Gold', child: Text('Gold')),
                            DropdownMenuItem(
                                value: 'Platinum', child: Text('Platinum')),
                            DropdownMenuItem(
                                value: 'Custom', child: Text('Custom')),
                          ],
                          onChanged: (value) {
                            if (value == null || value.isEmpty) return;
                            setDialogState(() {
                              final previousAutoName = selectedTier == 'Custom'
                                  ? ''
                                  : 'Tour $selectedTier';
                              final nextAutoName =
                                  value == 'Custom' ? '' : 'Tour $value';
                              final currentName = nameController.text.trim();
                              if (currentName.isEmpty ||
                                  currentName == previousAutoName) {
                                nameController.text = nextAutoName;
                              }
                              selectedTier = value;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: priceController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                    labelText: 'Price Per Person'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: maxGroupController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Max Group Size'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: tastingQty.toString(),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Tasting Qty Per Guest',
                          ),
                          onChanged: (value) {
                            tastingQty =
                                double.tryParse(value.trim()) ?? tastingQty;
                          },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: descController,
                          decoration:
                              const InputDecoration(labelText: 'Description'),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Select Wines',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 240,
                          child: ListView(
                            children: _items.map((item) {
                              final itemId = (item['name'] ?? '').toString();
                              final itemLabel =
                                  '${item['item_code']} - ${item['item_name']}';
                              final selected = selectedWineIds.contains(itemId);

                              return CheckboxListTile(
                                value: selected,
                                dense: true,
                                title: Text(itemLabel),
                                subtitle:
                                    Text((item['brand'] ?? '').toString()),
                                onChanged: (checked) {
                                  setDialogState(() {
                                    if (checked == true) {
                                      selectedWineIds.add(itemId);
                                    } else {
                                      selectedWineIds.remove(itemId);
                                    }
                                  });
                                },
                              );
                            }).toList(growable: false),
                          ),
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
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    if (selectedWineIds.isEmpty) {
                      _showSnackbar('Please select at least one wine item');
                      return;
                    }
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    final winesPayload = selectedWineIds
        .map(
          (itemId) => {
            'vineyard_item': itemId,
            'tasting_qty_per_guest': tastingQty,
            'serving_uom': 'Glass',
          },
        )
        .toList(growable: false);

    try {
      await _api.upsertPackage(
        packageId: currentPackage == null
            ? null
            : (currentPackage['name'] ?? '').toString(),
        vineyard: _selectedVineyard,
        packageName: nameController.text.trim(),
        packageTier: selectedTier,
        pricePerPerson: double.tryParse(priceController.text.trim()) ?? 0,
        maxGroupSize: int.tryParse(maxGroupController.text.trim()) ?? 0,
        wines: winesPayload,
        description: descController.text.trim(),
      );
      _showSnackbar('Package saved');
      await _loadPackages();
    } catch (e) {
      _showSnackbar(e.toString());
    }
  }

  Future<void> _openBookingDialog() async {
    final contextData = _context;
    if (contextData == null || !contextData.canStaffMutate) {
      _showSnackbar('Only admins or staff can create bookings');
      return;
    }

    if (_packages.isEmpty) {
      _showSnackbar('Please configure packages first.');
      return;
    }

    final formKey = GlobalKey<FormState>();
    final guestNameController = TextEditingController();
    final guestPhoneController = TextEditingController();
    final guestEmailController = TextEditingController();
    final participantsController = TextEditingController(text: '1');
    String selectedPackage = (_packages.first['name'] ?? '').toString();
    String selectedTourType = 'INDIVIDUAL';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Create Booking'),
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedPackage,
                        decoration:
                            const InputDecoration(labelText: 'Tour Package'),
                        items: _packages
                            .map(
                              (row) => DropdownMenuItem<String>(
                                value: (row['name'] ?? '').toString(),
                                child: Text(
                                  '${row['package_tier']} - ${row['package_name']}',
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null || value.isEmpty) return;
                          setDialogState(() => selectedPackage = value);
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedTourType,
                        decoration:
                            const InputDecoration(labelText: 'Tour Type'),
                        items: const [
                          DropdownMenuItem(
                              value: 'INDIVIDUAL', child: Text('INDIVIDUAL')),
                          DropdownMenuItem(
                              value: 'GROUP', child: Text('GROUP')),
                        ],
                        onChanged: (value) {
                          if (value == null || value.isEmpty) return;
                          setDialogState(() => selectedTourType = value);
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: participantsController,
                        decoration: const InputDecoration(
                            labelText: 'Participants Count'),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final parsed = int.tryParse((value ?? '').trim());
                          if (parsed == null || parsed <= 0) {
                            return 'Participants should be > 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: guestNameController,
                        decoration:
                            const InputDecoration(labelText: 'Guest Name'),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Guest name required'
                                : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: guestPhoneController,
                        decoration:
                            const InputDecoration(labelText: 'Guest Phone'),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: guestEmailController,
                        decoration:
                            const InputDecoration(labelText: 'Guest Email'),
                      ),
                    ],
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
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _api.createBooking(
        vineyard: _selectedVineyard,
        tourPackage: selectedPackage,
        tourType: selectedTourType,
        participantsCount:
            int.tryParse(participantsController.text.trim()) ?? 1,
        guestName: guestNameController.text.trim(),
        guestPhone: guestPhoneController.text.trim(),
        guestEmail: guestEmailController.text.trim(),
      );
      _showSnackbar('Booking created');
      await _loadBookings();
    } catch (e) {
      _showSnackbar(e.toString());
    }
  }

  Future<void> _updateBookingStatus(
    Map<String, dynamic> booking,
    String status,
  ) async {
    final contextData = _context;
    if (contextData == null || !contextData.canStaffMutate) {
      _showSnackbar('Only admins or staff can update booking status');
      return;
    }

    final bookingId = (booking['name'] ?? '').toString();

    try {
      await _api.updateBookingStatus(
        bookingId: bookingId,
        status: status,
        cancelReason:
            status == 'CANCELLED' ? 'Cancelled from Tour Management UI' : '',
      );
      _showSnackbar('Booking updated to $status');
      await _loadBookings();
      await _loadItems();
    } catch (e) {
      _showSnackbar(e.toString());
    }
  }

  Future<void> _openAddOnDialog(Map<String, dynamic> booking) async {
    final contextData = _context;
    if (contextData == null || !contextData.canStaffMutate) {
      _showSnackbar('Only admins or staff can add extra tasting items');
      return;
    }

    if (_items.isEmpty) {
      _showSnackbar('No vineyard items available');
      return;
    }

    String selectedItemId = (_items.first['name'] ?? '').toString();
    final qtyController = TextEditingController(text: '1');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Add Specific Tasting Item'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedItemId,
                      decoration: const InputDecoration(labelText: 'Item'),
                      items: _items
                          .map(
                            (row) => DropdownMenuItem<String>(
                              value: (row['name'] ?? '').toString(),
                              child: Text(
                                  '${row['item_code']} - ${row['item_name']}'),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null || value.isEmpty) return;
                        setDialogState(() => selectedItemId = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: qtyController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Quantity to deduct',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Booking: ${(booking['booking_no'] ?? booking['name'] ?? '').toString()}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
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
      },
    );

    if (confirmed != true) return;

    final qty = double.tryParse(qtyController.text.trim());
    if (qty == null || qty <= 0) {
      _showSnackbar('Invalid quantity');
      return;
    }

    final bookingRef =
        (booking['booking_no'] ?? booking['name'] ?? '').toString();
    try {
      await _api.adjustStock(
        itemId: selectedItemId,
        mode: 'delta',
        deltaQty: -qty,
        reason: 'Tour add-on item for booking $bookingRef',
      );
      _showSnackbar('Add-on item applied');
      await _loadItems();
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
    final appColorScheme = themeData.extension<AppColorScheme>()!;

    return Container(
      decoration: ContainerBackgroundTheme.myGradientDecoration,
      child: ListView(
        padding: const EdgeInsets.all(kDefaultPadding),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tour Management',
                  style: themeData.textTheme.headlineMedium?.copyWith(
                    color: appColorScheme.warning,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loading ? null : _loadContext,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_context == null)
            _inlineError(_errorMessage.isEmpty
                ? 'Unable to fetch context'
                : _errorMessage)
          else
            _buildLoadedContent(),
        ],
      ),
    );
  }

  Widget _buildLoadedContent() {
    final contextData = _context!;

    if (_selectedVineyard.isEmpty) {
      return _inlineError('No vineyard assigned to current user.');
    }

    final vineyards = contextData.vineyards;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 360,
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
                          '${row['vineyard']} (${row['access_role']})',
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null || value.isEmpty) return;
                  setState(() => _selectedVineyard = value);
                  unawaited(_refreshAll());
                },
              ),
            ),
            if (contextData.canAdminMutate)
              FilledButton.icon(
                onPressed: _openPackageDialog,
                icon: const Icon(Icons.local_bar),
                label: const Text('New Package'),
              ),
            if (contextData.canStaffMutate)
              FilledButton.icon(
                onPressed: _openBookingDialog,
                icon: const Icon(Icons.event_available),
                label: const Text('New Booking'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_errorMessage.isNotEmpty) _inlineError(_errorMessage),
        const SizedBox(height: 8),
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Packages'),
            Tab(text: 'Bookings'),
          ],
        ),
        SizedBox(
          height: 640,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPackageTab(contextData),
              _buildBookingTab(contextData),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPackageTab(MarnisiSessionContext contextData) {
    if (_loadingPackages) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_packages.isEmpty) {
      return const Center(child: Text('No tour packages configured yet.'));
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Tier')),
            DataColumn(label: Text('Package')),
            DataColumn(label: Text('Price')),
            DataColumn(label: Text('Max Group')),
            DataColumn(label: Text('Wines')),
            DataColumn(label: Text('Active')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _packages.map((row) {
            final isActive = _asInt(row['is_active']) == 1;
            final wineCount =
                (row['wines'] as List<dynamic>? ?? const []).length;

            return DataRow(
              cells: [
                DataCell(Text((row['package_tier'] ?? '').toString())),
                DataCell(Text((row['package_name'] ?? '').toString())),
                DataCell(Text((row['price_per_person'] ?? 0).toString())),
                DataCell(Text((row['max_group_size'] ?? 0).toString())),
                DataCell(Text(wineCount.toString())),
                DataCell(
                  Text(
                    isActive ? 'Yes' : 'No',
                    style:
                        TextStyle(color: isActive ? Colors.green : Colors.red),
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: contextData.canAdminMutate
                        ? () => _openPackageDialog(currentPackage: row)
                        : null,
                  ),
                ),
              ],
            );
          }).toList(growable: false),
        ),
      ),
    );
  }

  Widget _buildBookingTab(MarnisiSessionContext contextData) {
    if (_loadingBookings) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_bookings.isEmpty) {
      return const Center(child: Text('No bookings found.'));
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Booking No')),
            DataColumn(label: Text('Package')),
            DataColumn(label: Text('Tour Type')),
            DataColumn(label: Text('Participants')),
            DataColumn(label: Text('Guest')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _bookings.map((row) {
            final status = (row['status'] ?? '').toString();

            return DataRow(
              cells: [
                DataCell(
                    Text((row['booking_no'] ?? row['name'] ?? '').toString())),
                DataCell(Text((row['tour_package'] ?? '').toString())),
                DataCell(Text((row['tour_type'] ?? '').toString())),
                DataCell(Text((row['participants_count'] ?? 0).toString())),
                DataCell(Text((row['guest_name'] ?? '').toString())),
                DataCell(Text(status)),
                DataCell(
                  Wrap(
                    spacing: 6,
                    children: [
                      if (status == 'DRAFT')
                        OutlinedButton(
                          onPressed: contextData.canStaffMutate
                              ? () => _updateBookingStatus(row, 'CONFIRMED')
                              : null,
                          child: const Text('Confirm'),
                        ),
                      if (status == 'CONFIRMED')
                        OutlinedButton(
                          onPressed: contextData.canStaffMutate
                              ? () => _updateBookingStatus(row, 'CHECKED_IN')
                              : null,
                          child: const Text('Check-In'),
                        ),
                      if (status == 'CONFIRMED')
                        OutlinedButton(
                          onPressed: contextData.canStaffMutate
                              ? () => _openAddOnDialog(row)
                              : null,
                          child: const Text('Add Item'),
                        ),
                      if (status == 'CHECKED_IN')
                        OutlinedButton(
                          onPressed: contextData.canStaffMutate
                              ? () => _updateBookingStatus(row, 'COMPLETED')
                              : null,
                          child: const Text('Complete'),
                        ),
                      if (status != 'COMPLETED' && status != 'CANCELLED')
                        TextButton(
                          onPressed: contextData.canStaffMutate
                              ? () => _updateBookingStatus(row, 'CANCELLED')
                              : null,
                          child: const Text('Cancel'),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(growable: false),
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

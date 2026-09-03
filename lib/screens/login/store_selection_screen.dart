import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/models/executive.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/main_screen.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/screens/sales/daily_sales_close_list.dart';
import 'package:pos_machine/models/day_close_pending_status.dart';

class StoreSelectionScreen extends StatefulWidget {
  final List<Store> stores;
  final bool isFromLogin;

  const StoreSelectionScreen({
    super.key,
    required this.stores,
    this.isFromLogin = false,
  });

  @override
  State<StoreSelectionScreen> createState() => _StoreSelectionScreenState();
}

class _StoreSelectionScreenState extends State<StoreSelectionScreen> {
  int? _selectedStoreId;

  @override
  void initState() {
    super.initState();
    // initializeStores notifies listeners. Defer it until after the first
    // frame so the inherited Provider is not marked dirty during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final storeSession =
          Provider.of<StoreSessionProvider>(context, listen: false);
      storeSession.initializeStores(
        widget.stores,
        activeStoreId: storeSession.activeStore?.storeId,
      );
      setState(() {
        _selectedStoreId = storeSession.activeStore?.storeId ??
            (widget.stores.isNotEmpty ? widget.stores.first.storeId : null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width;
    final bool isMobile = width < 600;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: ColorManager.kPrimaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (widget.isFromLogin) {
              Navigator.of(context).pushReplacementNamed('/login');
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          'login.store_select_title'.tr,
          style: const TextStyle(
            fontFamily: FontConstants.fontFamily,
            fontSize: FontSize.s16,
            fontWeight: FontWeightManager.semiBold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Header section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ColorManager.kPrimaryColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.store_rounded,
                  size: isMobile ? 48 : 64,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                Text(
                  'login.store_choose'.tr,
                  style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    fontSize: isMobile ? FontSize.s14 : FontSize.s18,
                    fontWeight: FontWeightManager.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'login.store_choose_sub'.tr,
                  style: TextStyle(
                    fontFamily: FontConstants.fontFamily,
                    fontSize: isMobile ? FontSize.s10 : FontSize.s12,
                    fontWeight: FontWeightManager.regular,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          // Store cards list
          Expanded(
            child: widget.stores.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.store_mall_directory_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'login.store_empty'.tr,
                          style: TextStyle(
                            fontFamily: FontConstants.fontFamily,
                            fontSize: FontSize.s14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    itemCount: widget.stores.length,
                    itemBuilder: (context, index) {
                      final store = widget.stores[index];
                      final isSelected = _selectedStoreId == store.storeId;

                      return Consumer<StoreSessionProvider>(
                        builder: (context, storeSession, _) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Opacity(
                              opacity: storeSession.isBootstrapping ? 0.5 : 1.0,
                              child: IgnorePointer(
                                ignoring: storeSession.isBootstrapping,
                                child: _buildStoreCard(
                                  store: store,
                                  isSelected: isSelected,
                                  isMobile: isMobile,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),

          // Submit button
          if (_selectedStoreId != null)
            SafeArea(
              top: false,
              child: Container(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Consumer<StoreSessionProvider>(
                  builder: (context, storeSession, _) {
                    if (storeSession.isBootstrapping) {
                      return Column(
                        children: [
                          const CircularProgressIndicator(
                            color: ColorManager.kPrimaryColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            storeSession.statusMessage ??
                                'login.store_preparing'.tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: FontConstants.fontFamily,
                              fontSize: FontSize.s12,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      );
                    }

                    return CustomRoundButton(
                      width: isMobile ? double.infinity : 400,
                      height: isMobile ? 50 : 60,
                      fontSize: FontSize.s14,
                      radius: 25,
                      title: 'login.btn_continue'.tr,
                      fct: _handleSubmit,
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStoreCard({
    required Store store,
    required bool isSelected,
    required bool isMobile,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedStoreId = store.storeId;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected ? ColorManager.kPrimaryColor : Colors.grey.shade300,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? ColorManager.kPrimaryColor.withOpacity(0.2)
                  : Colors.black.withOpacity(0.05),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          child: Row(
            children: [
              // Store icon
              Container(
                width: isMobile ? 50 : 60,
                height: isMobile ? 50 : 60,
                decoration: BoxDecoration(
                  color: isSelected
                      ? ColorManager.kPrimaryColor.withOpacity(0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  size: isMobile ? 28 : 32,
                  color: isSelected
                      ? ColorManager.kPrimaryColor
                      : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 16),

              // Store details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.storeName ?? 'login.store_unnamed'.tr,
                      style: TextStyle(
                        fontFamily: FontConstants.fontFamily,
                        fontSize: isMobile ? FontSize.s14 : FontSize.s16,
                        fontWeight: FontWeightManager.semiBold,
                        color: isSelected
                            ? ColorManager.kPrimaryColor
                            : Colors.black87,
                      ),
                    ),
                    if (store.location != null &&
                        store.location!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: isMobile ? 14 : 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              store.location!,
                              style: TextStyle(
                                fontFamily: FontConstants.fontFamily,
                                fontSize:
                                    isMobile ? FontSize.s10 : FontSize.s12,
                                fontWeight: FontWeightManager.regular,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${'login.store_id_label'.tr}: ${store.storeId}',
                      style: TextStyle(
                        fontFamily: FontConstants.fontFamily,
                        fontSize: isMobile ? FontSize.s8 : FontSize.s10,
                        fontWeight: FontWeightManager.regular,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),

              // Selection indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isMobile ? 24 : 28,
                height: isMobile ? 24 : 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? ColorManager.kPrimaryColor
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? ColorManager.kPrimaryColor
                        : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_selectedStoreId == null) return;

    final selectedStore =
        widget.stores.firstWhere((store) => store.storeId == _selectedStoreId);

    try {
      final storeSession =
          Provider.of<StoreSessionProvider>(context, listen: false);

      await storeSession.bootstrapStore(
        context: context,
        store: selectedStore,
      );

      if (!mounted) return;

      showScaffold(
        context: context,
        message:
            '${selectedStore.storeName ?? 'login.store_unnamed'.tr} ${'login.store_ready'.tr}',
      );

      // Check compulsory day close
      bool shouldNavigateToMainScreen = true;
      bool dayCloseSubmitted = false;
      DayClosePendingStatus? pendingStatus;

      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);
      final compulsoryDayClose =
          appSettingsProvider.appSettings?.compulsoryDayCloseRegister ?? false;

      if (compulsoryDayClose) {
        final authModel = Provider.of<AuthModel>(context, listen: false);
        final accessToken = authModel.token ?? '';
        final salesProvider =
            Provider.of<SalesProvider>(context, listen: false);

        pendingStatus = await salesProvider.fetchDayClosePendingStatus(
          accessToken: accessToken,
          storeId: selectedStore.storeId ?? 0,
          userId: authModel.userId ?? 0,
        );

        debugPrint('=== DIAGNOSTICS: fetchDayClosePendingStatus ===');
        debugPrint('Sent storeId: ${selectedStore.storeId ?? 0}');
        debugPrint('Sent userId: ${authModel.userId ?? 0}');
        debugPrint('pendingStatus null? ${pendingStatus == null}');
        debugPrint('pendingDayClose: ${pendingStatus?.pendingDayClose}');
        debugPrint('openDraft: ${pendingStatus?.openDraft}');
        debugPrint(
            'requiresConfirmation: ${pendingStatus?.requiresConfirmation}');
        debugPrint('==================================================');

        if (!mounted) return;

        bool isPastDate = false;
        if (pendingStatus != null && pendingStatus.businessDate != null) {
          try {
            final parts = pendingStatus.businessDate!.split('-');
            if (parts.length == 3) {
              final year = int.parse(parts[0]);
              final month = int.parse(parts[1]);
              final day = int.parse(parts[2]);
              final businessDate = DateTime(year, month, day);
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              if (businessDate.isBefore(today)) {
                isPastDate = true;
              }
            }
          } catch (e) {
            debugPrint('Error parsing pending business date: $e');
          }
        }

        if (pendingStatus != null &&
            pendingStatus.pendingDayClose &&
            isPastDate) {
          shouldNavigateToMainScreen = false;

          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: Text('login.day_close_title'.tr),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${'login.day_close_default'.tr} ${pendingStatus?.businessDate ?? ''}.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'login.day_close_confirm'.tr,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => DayCloseModal(
                        openDraft: pendingStatus?.openDraft,
                        pendingBusinessDate: pendingStatus?.businessDate,
                        pendingOpeningTransactionId:
                            pendingStatus?.openingTransactionId,
                        pendingClosingTransactionId:
                            pendingStatus?.closingTransactionId,
                        onSuccess: () {
                          dayCloseSubmitted = true;
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => const MainScreen(),
                            ),
                          );
                        },
                      ),
                    ).then((_) {
                      if (mounted && !dayCloseSubmitted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const MainScreen(),
                          ),
                        );
                      }
                    });
                  },
                  child: Text('login.btn_yes'.tr),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const MainScreen(),
                      ),
                    );
                  },
                  child: Text('login.btn_no'.tr),
                ),
              ],
            ),
          );
        }
      }

      if (!mounted) return;
      if (shouldNavigateToMainScreen) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const MainScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'login.error_saving_store'.tr}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

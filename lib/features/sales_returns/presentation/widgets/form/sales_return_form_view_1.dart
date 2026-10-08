part of 'sales_return_form_view.dart';

extension _FormSection1 on SalesReturnFormSections {
  Widget _buildLoadingOverlay() {
    if (!initLoading) return const SizedBox.shrink();
    return Positioned.fill(
      child: Container(
        color: Colors.white.withOpacity(0.75),
        child: const Center(
          child: CircularProgressIndicator(
            color: ColorManager.kPrimaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildStepHint() {
    if (!isOrderSelected || initLoading) return const SizedBox.shrink();

    final hasDraft = draftReturnOrderId != null;
    final step2Ready = canCompleteReturn;

    return SalesReturnStepBar(
      steps: [
        _buildStepChip('1', 'sales_return_form.step_return_items'.tr,
            active: true, done: hasDraft),
        Icon(Icons.arrow_forward, size: 14, color: Colors.grey.shade400),
        _buildStepChip(
          '2',
          'sales_return_form.step_complete_return'.tr,
          active: step2Ready,
          done: false,
        ),
      ],
    );
  }

  Widget _buildStepChip(
    String number,
    String label, {
    required bool active,
    required bool done,
  }) {
    final color = done
        ? Colors.green
        : active
            ? ColorManager.kPrimaryColor
            : Colors.grey.shade400;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: color.withOpacity(0.15),
          child: done
              ? Icon(Icons.check, size: 12, color: color)
              : Text(
                  number,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s11,
            0.25,
            color,
          ),
        ),
      ],
    );
  }

  double _itemsTableHeight(int itemCount) {
    if (itemCount == 0) return 140;
    return (56.0 * itemCount + 52).clamp(160.0, 380.0);
  }

  Widget _buildView() {
    Size size = MediaQuery.of(context).size;

    final isPhone = salesReturnIsPhone(context);

    return SalesReturnScrollShell(
      onRefresh: refreshData,
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: isPhone ? 4 : 8,
              vertical: isPhone ? 8 : 12,
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBackButton(
                    onPressed: initLoading || isCompletingReturn
                        ? () {}
                        : () {
                            onBack();
                          },
                    text: 'sales_return_form.btn_back'.tr,
                  ),
                  const SizedBox(height: 8),
                  SalesReturnPageHeader(
                    title: 'sales_return_form.page_title'.tr,
                    subtitle: isOrderSelected
                        ? 'sales_return_form.subtitle_selected'.tr
                        : 'sales_return_form.subtitle_no_order'.tr,
                  ),
                ],
              ),
              const SizedBox(
                height: 5,
              ),
              const SizedBox(
                height: 8,
              ),
              _buildStepHint(),
              Builder(
                builder: (context) {
                  final orderProvider = controller;
                  List<ListOrderModelData> orders = orderProvider.orders;

                  if (isOrderSelected && orders.isNotEmpty) {
                    try {
                      final order = orders.firstWhere(
                        (order) =>
                            order.orderNumber.toString() == selectedOrderNumber,
                        orElse: () => orders.firstWhere(
                          (order) => order.id.toString() == selectedOrderId,
                          orElse: () => ListOrderModelData(
                            id: int.tryParse(selectedOrderId ?? "0"),
                            orderNumber: selectedOrderNumber,
                            orderDate: DateTime.now(),
                            customerName: "Order #$selectedOrderNumber",
                          ),
                        ),
                      );

                      return SalesReturnContentCard(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: EdgeInsetsDirectional.all(isPhone ? 14 : 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SalesReturnLabelPill(
                                    label:
                                        'sales_return_form.order_details_label'
                                            .tr),
                                const Spacer(),
                                Container(
                                  padding:
                                      const EdgeInsetsDirectional.symmetric(
                                          horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 14,
                                        color: Colors.green.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'sales_return_form.order_selected_badge'
                                            .tr,
                                        style: buildCustomStyle(
                                          FontWeightManager.medium,
                                          FontSize.s10,
                                          0.25,
                                          Colors.green.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SalesReturnDetailGrid(
                              children: [
                                _buildOrderDetailItem(
                                  'sales_return_form.field_order_number'.tr,
                                  '${order.orderNumber}',
                                  Icons.receipt_long,
                                ),
                                _buildOrderDetailItem(
                                  'sales_return_form.field_date'.tr,
                                  DateHelper.formatDate(
                                      order.orderDate ?? DateTime.now()),
                                  Icons.calendar_today,
                                ),
                                _buildOrderDetailItem(
                                  'sales_return_form.field_customer'.tr,
                                  order.customerName ??
                                      'sales_return_form.na'.tr,
                                  Icons.person,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    } catch (e) {
                      debugPrint('Error displaying selected order: $e');
                      return SalesReturnContentCard(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: EdgeInsetsDirectional.all(isPhone ? 14 : 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SalesReturnLabelPill(
                                label:
                                    'sales_return_form.order_details_label'.tr),
                            const SizedBox(height: 16),
                            SalesReturnDetailGrid(
                              children: [
                                _buildOrderDetailItem(
                                  'sales_return_form.field_order_number'.tr,
                                  '$selectedOrderNumber',
                                  Icons.receipt_long,
                                ),
                                _buildOrderDetailItem(
                                  'sales_return_form.field_date'.tr,
                                  DateHelper.formatDate(DateTime.now()),
                                  Icons.calendar_today,
                                ),
                                _buildOrderDetailItem(
                                  'sales_return_form.field_customer'.tr,
                                  'sales_return_form.order_ref'.trParams(
                                      {'number': '$selectedOrderNumber'}),
                                  Icons.person,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }
                  } else {
                    return SalesReturnContentCard(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: EdgeInsetsDirectional.all(isPhone ? 20 : 24),
                      color: Colors.grey.shade50,
                      child: Column(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'sales_return_form.no_order_title'.tr,
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s16,
                              0.27,
                              Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'sales_return_form.no_order_subtitle'.tr,
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s12,
                              0.25,
                              Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
              SalesReturnSectionTitle(
                  title: 'sales_return_form.section_order_items'.tr),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final useItemCards =
                      salesReturnUseItemCards(constraints.maxWidth);

                  return Builder(
                    builder: (context) {
                      final salesProvider = controller;
                      final itemCount = salesProvider.salesReturnItems.length;
                      if (useItemCards) {
                        return _buildOrderDetails(useItemCards: true);
                      }
                      return SizedBox(
                        height: _itemsTableHeight(itemCount),
                        child: _buildOrderDetails(useItemCards: false),
                      );
                    },
                  );
                },
              ),
              const SizedBox(
                height: 20,
              ),
              _buildSummarySection(),
              const SizedBox(
                height: 20,
              ),
              _buildPaymentDetailsSection(),
              const SizedBox(
                height: 20,
              ),
              _buildCompleteReturnButton(size),
              SizedBox(height: isPhone ? 12 : 20),
            ],
          ),
          _buildLoadingOverlay(),
        ],
      ),
    );
  }
}

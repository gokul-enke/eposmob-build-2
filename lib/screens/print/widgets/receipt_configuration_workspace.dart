import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/models/bluetooth_printer.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/bank_provider.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/screens/print/layouts/premium2_bilingual_receipt_layout.dart';
import 'package:pos_machine/screens/print/layouts/receipt_layout_params.dart';
import 'package:pos_machine/screens/print/widgets/printer_settings_responsive.dart';

enum _PreviewLanguage { english, arabic, bilingual }

class ReceiptConfigurationWorkspace extends StatefulWidget {
  final DocumentConfig? config;
  final String paperSize;
  final String themeName;
  final String themeId;
  final VoidCallback onResync;
  final bool isResyncing;

  const ReceiptConfigurationWorkspace({
    super.key,
    required this.config,
    required this.paperSize,
    required this.themeName,
    required this.themeId,
    required this.onResync,
    required this.isResyncing,
  });

  @override
  State<ReceiptConfigurationWorkspace> createState() =>
      _ReceiptConfigurationWorkspaceState();
}

class _ReceiptConfigurationWorkspaceState
    extends State<ReceiptConfigurationWorkspace> {
  String _selectedSection = 'store';
  late _PreviewLanguage _previewLanguage;

  @override
  void initState() {
    super.initState();
    _previewLanguage = _languageFromConfig(widget.config?.language);
  }

  @override
  void didUpdateWidget(covariant ReceiptConfigurationWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _previewLanguage = _languageFromConfig(widget.config?.language);
    }
  }

  static _PreviewLanguage _languageFromConfig(String? language) {
    switch (language?.trim().toLowerCase().replaceAll('-', '_')) {
      case 'en':
        return _PreviewLanguage.english;
      case 'ar':
        return _PreviewLanguage.arabic;
      default:
        return _PreviewLanguage.bilingual;
    }
  }

  static const _sections = <_ReceiptSection>[
    _ReceiptSection(
      id: 'store',
      label: 'Store',
      icon: Icons.storefront_outlined,
      description: 'Store identity and receipt heading',
      keys: [
        'showExtraHeading1',
        'showExtraHeading2',
        'showStoreName',
        'showDescription',
        'showStoreAddress',
        'showFssaiInfo',
        'showVatNumber',
        'showCRNumber',
        'showTel',
        'showEmail',
      ],
    ),
    _ReceiptSection(
      id: 'invoice',
      label: 'Invoice',
      icon: Icons.receipt_long_outlined,
      description: 'Document title, number, date and token',
      keys: [
        'showInvoiceTitle',
        'showInvoiceTitleB2b',
        'showInvoiceTitleB2B',
        'showInvoiceNumber',
        'showTokenNumber',
        'showDate',
        'showOrderNumberInFooter',
      ],
    ),
    _ReceiptSection(
      id: 'customer',
      label: 'Customer',
      icon: Icons.person_outline_rounded,
      description: 'Customer, payment and delivery labels',
      keys: [
        'showCustomerNameAndPhone',
        'showCustomerName',
        'showCustomerPhone',
        'showCustomerPhoneMasked',
        'showCustomerAddress',
        'showCustomerVatNumber',
        'showCustomerCrNumber',
        'showPaymentMethod',
        'showPayment',
        'showOrderComment',
        'showComment',
        'showDeliveryMethod',
        'showDeliveryPhone',
      ],
    ),
    _ReceiptSection(
      id: 'items',
      label: 'Items',
      icon: Icons.table_chart_outlined,
      description: 'Item-table columns and line details',
      keys: [
        'showSLNumber',
        'showParticulars',
        'showMRP',
        'showQty',
        'showRate',
        'showRateExcTax',
        'showUnit',
        'showTaxHeader',
        'showTotal',
        'showItemsCount',
        'showQuantityCount',
        'showWarranty',
      ],
    ),
    _ReceiptSection(
      id: 'totals',
      label: 'Totals & bank',
      icon: Icons.calculate_outlined,
      description: 'Calculated totals, balances and bank details',
      keys: [
        'showTotalMRP',
        'showMRPTotal',
        'showSubTotal',
        'showSaved',
        'showDiscount',
        'showTax',
        'showTaxableAmount',
        'showNetTotal',
        'showNetAmount',
        'showRoundOff',
        'showPaymentBreakdown',
        'showPaymentBreaked',
        'showAmountInWords',
        'showCustomerOldBalance',
        'showCustomerPrevBalance',
        'showCustomerCurrentBalance',
        'showCustomerBalance',
        'showPaidAmount',
        'showCustomerPaidAmount',
        'showBankDetails',
        'showBankInfo',
        'showBankName',
        'showBankAccountName',
        'showAccountName',
        'showBankAccountNumber',
        'showAccountNumber',
        'showBankIban',
        'showIBAN',
        'showBankSwiftCode',
        'showSwiftCode',
      ],
    ),
    _ReceiptSection(
      id: 'footer',
      label: 'Footer',
      icon: Icons.vertical_align_bottom_rounded,
      description: 'QR, tax footer and closing messages',
      keys: [
        'showQRCode',
        'showVATFooter',
        'showTerms',
        'showTermsConditions',
        'showThankYouMessage',
      ],
    ),
  ];

  Map<String, DisplayOption> get _options =>
      widget.config?.displayConfiguration?.options ?? const {};

  @override
  Widget build(BuildContext context) {
    final compact = printerIsCompact(context);
    final config = widget.config;
    final visibleCount =
        _options.values.where((option) => option.visible == true).length;

    return PrinterSettingsCard(
      padding: EdgeInsets.all(compact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrinterSectionHeader(
            icon: Icons.preview_outlined,
            title: 'Receipt Setup & Live Preview',
            subtitle: config == null
                ? 'No Bill document configuration is currently synced'
                : 'Review every synced label and understand what supplies its printed value',
            trailing: OutlinedButton.icon(
              onPressed: widget.isResyncing ? null : widget.onResync,
              icon: widget.isResyncing
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded, size: 18),
              label: Text(widget.isResyncing ? 'Syncing...' : 'Resync'),
            ),
          ),
          const SizedBox(height: 16),
          _buildNotice(config),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryChip(icon: Icons.straighten, text: widget.paperSize),
              _SummaryChip(
                  icon: Icons.palette_outlined, text: widget.themeName),
              _SummaryChip(
                icon: Icons.translate,
                text: _languageName(config?.language),
              ),
              _SummaryChip(
                icon: Icons.visibility_outlined,
                text: '$visibleCount/${_options.length} visible',
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildSectionSelector(),
          const SizedBox(height: 16),
          if (config == null)
            _buildEmptyState()
          else if (compact)
            Column(
              children: [
                _buildFieldsPanel(),
                const SizedBox(height: 16),
                _buildPreviewPanel(),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: _buildFieldsPanel()),
                const SizedBox(width: 18),
                Expanded(flex: 4, child: _buildPreviewPanel()),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildNotice(DocumentConfig? config) {
    final hasConfig = config != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: (hasConfig ? Colors.blue : Colors.orange).withValues(alpha: .07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              (hasConfig ? Colors.blue : Colors.orange).withValues(alpha: .20),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasConfig
                ? Icons.info_outline_rounded
                : Icons.warning_amber_rounded,
            size: 19,
            color: hasConfig ? Colors.blue.shade700 : Colors.orange.shade800,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasConfig
                  ? 'These are the current values from Document Configuration. Edit them in the Admin Panel, then press Resync. Sample amounts and customer details below are live-data examples, not saved labels.'
                  : 'Configure the Bill template in the Admin Panel, then press Resync Doc Config.',
              style: TextStyle(
                height: 1.35,
                fontSize: 12,
                color:
                    hasConfig ? Colors.blue.shade900 : Colors.orange.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _sections.map((section) {
          final selected = section.id == _selectedSection;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: selected,
              showCheckmark: false,
              avatar: Icon(
                section.icon,
                size: 17,
                color: selected ? Colors.white : ColorManager.kPrimaryColor,
              ),
              label: Text(section.label),
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade800,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
              selectedColor: ColorManager.kPrimaryColor,
              backgroundColor: Colors.grey.shade50,
              side: BorderSide(
                color: selected
                    ? ColorManager.kPrimaryColor
                    : Colors.grey.shade300,
              ),
              onSelected: (_) => setState(() => _selectedSection = section.id),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFieldsPanel() {
    final section =
        _sections.firstWhere((section) => section.id == _selectedSection);
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  section.description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          if (!printerIsCompact(context)) _buildDesktopColumnHeader(),
          ...section.keys.map((key) => _buildFieldRow(key, _options[key])),
        ],
      ),
    );
  }

  Widget _buildFieldRow(String key, DisplayOption? option) {
    final available = option != null;
    final visible = option?.visible == true;
    final english = _clean(option?.defaultValue);
    final arabic = _clean(option?.value);
    final source = _fieldSource(key);

    if (!printerIsCompact(context)) {
      return Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Icon(
              !available
                  ? Icons.remove_circle_outline
                  : visible
                      ? Icons.check_circle_rounded
                      : Icons.visibility_off_outlined,
              size: 17,
              color: !available
                  ? Colors.grey.shade400
                  : visible
                      ? Colors.green.shade600
                      : Colors.grey.shade500,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 155,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _friendlyName(key),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 8.5,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _compactValue(english, available)),
            const SizedBox(width: 8),
            Expanded(child: _compactValue(arabic, available, rtl: true)),
            const SizedBox(width: 8),
            SizedBox(width: 82, child: _SourceBadge(source: source)),
            Tooltip(
              message: _fieldHelp(key, source),
              child: Padding(
                padding: const EdgeInsets.only(left: 7),
                child: Icon(Icons.info_outline_rounded,
                    size: 16, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                !available
                    ? Icons.remove_circle_outline
                    : visible
                        ? Icons.check_circle_rounded
                        : Icons.visibility_off_outlined,
                size: 18,
                color: !available
                    ? Colors.grey.shade400
                    : visible
                        ? Colors.green.shade600
                        : Colors.grey.shade500,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _friendlyName(key),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _SourceBadge(source: source),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            key,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10.5,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _valueBox('English', english, available)),
              const SizedBox(width: 10),
              Expanded(
                child: _valueBox('Arabic', arabic, available, rtl: true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _fieldHelp(key, source),
            style: TextStyle(
              fontSize: 11,
              height: 1.3,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopColumnHeader() {
    final labelStyle = TextStyle(
      color: Colors.grey.shade600,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          const SizedBox(width: 25),
          SizedBox(width: 163, child: Text('Field', style: labelStyle)),
          Expanded(child: Text('English', style: labelStyle)),
          const SizedBox(width: 8),
          Expanded(
            child:
                Text('Arabic', textAlign: TextAlign.right, style: labelStyle),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 105, child: Text('Source', style: labelStyle)),
        ],
      ),
    );
  }

  Widget _compactValue(String value, bool available, {bool rtl = false}) {
    final display = !available
        ? 'Not supplied'
        : value.isEmpty
            ? 'Empty'
            : value;
    return Container(
      height: 34,
      alignment: rtl ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        display,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        style: TextStyle(
          fontSize: 10.5,
          color: available && value.isNotEmpty
              ? Colors.grey.shade900
              : Colors.grey.shade500,
          fontStyle: available && value.isNotEmpty
              ? FontStyle.normal
              : FontStyle.italic,
        ),
      ),
    );
  }

  Widget _valueBox(String language, String value, bool available,
      {bool rtl = false}) {
    return Column(
      crossAxisAlignment:
          rtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          language,
          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            !available
                ? 'Not supplied by API'
                : value.isEmpty
                    ? 'Empty'
                    : value,
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            style: TextStyle(
              fontSize: 12,
              color: available && value.isNotEmpty
                  ? Colors.grey.shade900
                  : Colors.grey.shade500,
              fontStyle: available && value.isNotEmpty
                  ? FontStyle.normal
                  : FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewPanel() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfff1f3f7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.themeId == 'premium2_bilingual'
                      ? 'Exact renderer output'
                      : 'Sample output',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                widget.paperSize,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<_PreviewLanguage>(
            segments: const [
              ButtonSegment(
                value: _PreviewLanguage.english,
                label: Text('EN'),
              ),
              ButtonSegment(
                value: _PreviewLanguage.arabic,
                label: Text('AR'),
              ),
              ButtonSegment(
                value: _PreviewLanguage.bilingual,
                label: Text('EN + AR'),
              ),
            ],
            selected: {_previewLanguage},
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11)),
            ),
            onSelectionChanged: (selection) {
              setState(() => _previewLanguage = selection.first);
            },
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: widget.paperSize == '58mm' ? 260 : 310,
              padding: const EdgeInsets.fromLTRB(15, 18, 15, 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: _ExactReceiptPreview(
                config: widget.config!,
                paperSize: widget.paperSize,
                themeId: widget.themeId,
                options: _options,
                language: _previewLanguage,
                section: _selectedSection,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.themeId == 'premium2_bilingual'
                ? 'The real Premium 2 renderer is used with controlled sample order data.'
                : 'Sample order data is used so labels can be understood before printing.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 38, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          const Text(
            'Bill configuration not found',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Press Resync after configuring the document template.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  static String _clean(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  static String _languageName(String? language) {
    switch (language?.toLowerCase().replaceAll('-', '_')) {
      case 'en':
        return 'English config';
      case 'ar':
        return 'Arabic config';
      case 'en_ar':
      case 'ar_en':
      case 'bilingual':
        return 'Bilingual config';
      default:
        return language?.trim().isNotEmpty == true
            ? language!
            : 'Language not set';
    }
  }

  static String _friendlyName(String key) {
    final raw = key.replaceFirst(RegExp(r'^show'), '');
    return raw
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .replaceAll('VAT', 'VAT')
        .replaceAll('QRCode', 'QR Code')
        .replaceAll('Fssai', 'FSSAI')
        .trim();
  }

  static _FieldSource _fieldSource(String key) {
    if (const {
      'showCustomerName',
      'showCustomerPhone',
      'showCustomerAddress',
      'showCustomerVatNumber',
      'showCustomerCrNumber',
      'showPaymentMethod',
      'showPayment',
      'showOrderComment',
      'showComment',
      'showDeliveryMethod',
      'showDeliveryPhone',
      'showInvoiceNumber',
      'showTokenNumber',
      'showDate',
      'showWarranty',
    }.contains(key)) {
      return _FieldSource.order;
    }
    if (key.startsWith('showBank') ||
        const {
          'showAccountName',
          'showAccountNumber',
          'showIBAN',
          'showSwiftCode',
        }.contains(key)) {
      return _FieldSource.bank;
    }
    if (const {
      'showTotalMRP',
      'showMRPTotal',
      'showSubTotal',
      'showSaved',
      'showDiscount',
      'showTax',
      'showTaxableAmount',
      'showNetTotal',
      'showNetAmount',
      'showRoundOff',
      'showPaymentBreakdown',
      'showPaymentBreaked',
      'showAmountInWords',
      'showCustomerOldBalance',
      'showCustomerPrevBalance',
      'showCustomerCurrentBalance',
      'showCustomerBalance',
      'showPaidAmount',
      'showCustomerPaidAmount',
      'showItemsCount',
      'showQuantityCount',
    }.contains(key)) {
      return _FieldSource.calculated;
    }
    if (const {
      'showStoreAddress',
      'showVatNumber',
      'showCRNumber',
      'showTel',
      'showEmail',
    }.contains(key)) {
      return _FieldSource.store;
    }
    return _FieldSource.label;
  }

  static String _fieldHelp(String key, _FieldSource source) {
    if (key == 'showDeliveryPhone') {
      return 'Enter only the translated label. The phone number comes from delivery_phone, order properties, or alternate phone.';
    }
    if (key == 'showWarranty') {
      return 'Enter only the translated label. It prints when the order item has warranty_enabled.';
    }
    if (key == 'showVATFooter') {
      return 'Enter the translated footer label. The registered VAT number is appended independently of the QR code.';
    }
    switch (source) {
      case _FieldSource.order:
        return 'Configure the label here; the value is supplied by the current order.';
      case _FieldSource.store:
        return 'Configure the label here; the value is supplied by the active store or tax profile.';
      case _FieldSource.bank:
        return 'Configure the label here; the value is supplied by the selected store bank account.';
      case _FieldSource.calculated:
        return 'Configure the label here; the amount or count is calculated from the order.';
      case _FieldSource.label:
        return 'This configured text is printed directly when the option is visible.';
    }
  }
}

class _ExactReceiptPreview extends StatefulWidget {
  final DocumentConfig config;
  final String paperSize;
  final String themeId;
  final Map<String, DisplayOption> options;
  final _PreviewLanguage language;
  final String section;

  const _ExactReceiptPreview({
    required this.config,
    required this.paperSize,
    required this.themeId,
    required this.options,
    required this.language,
    required this.section,
  });

  @override
  State<_ExactReceiptPreview> createState() => _ExactReceiptPreviewState();
}

class _ExactReceiptPreviewState extends State<_ExactReceiptPreview> {
  Future<Uint8List>? _previewFuture;

  bool get _supportsExactPreview =>
      widget.themeId.toLowerCase() == 'premium2_bilingual';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_supportsExactPreview) _previewFuture ??= _render();
  }

  @override
  void didUpdateWidget(covariant _ExactReceiptPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_supportsExactPreview &&
        (oldWidget.config != widget.config ||
            oldWidget.paperSize != widget.paperSize ||
            oldWidget.themeId != widget.themeId ||
            oldWidget.language != widget.language)) {
      _previewFuture = _render();
    }
  }

  String get _languageCode => switch (widget.language) {
        _PreviewLanguage.english => 'en',
        _PreviewLanguage.arabic => 'ar',
        _PreviewLanguage.bilingual => 'en_ar',
      };

  Future<Uint8List> _render() async {
    final configJson = widget.config.toJson();
    configJson['language'] = _languageCode;
    final previewConfig = DocumentConfig.fromJson(configJson);
    final appSettings = context.read<AppSettingsProvider>().appSettings;
    final banks = context.read<BankProvider>().banks;
    final store = context.read<StoreSessionProvider>().activeStore;
    final preferences = SharedPreferenceProvider();
    final zatcaVatNumber = await preferences.getZatcaVatNumber();
    final zatcaCrNumber = await preferences.getZatcaCrNumber();
    final zatcaCompanyName = await preferences.getZatcaCompanyName();
    if (!mounted) throw StateError('Preview was disposed');

    final params = ReceiptLayoutParams(
      context: context,
      selectedPrinter: BluetoothPrinter.development(),
      cartItems: const [
        {
          'productName': 'Premium Coffee Beans',
          'product_name': 'Premium Coffee Beans',
          'names': {'en': 'Premium Coffee Beans', 'ar': 'حبوب قهوة فاخرة'},
          'mrp': '28.00',
          'quantity': '2',
          'product_unit': 'PCS',
          'unitPrice': '25.00',
          'unit_price': '25.00',
          'totalPrice': '50.00',
          'total_price': '50.00',
          'tax_amount': '6.52',
          'warranty_enabled': true,
        },
      ],
      formattedTotal: '50.00',
      savedTotal: '6.00',
      discountAmount: '2.00',
      orderDate: '2026-08-19T10:45:00Z',
      orderNumber: 'INV-010428',
      tokenNumber: '42',
      isFromLocalStorage: false,
      selectedPaperSize: widget.paperSize,
      billDocumentConfig: previewConfig,
      customerCareNumber: appSettings?.customerCarePhone ?? '',
      customerCareEmail: appSettings?.customerCareEmail ?? '',
      customerName: 'Sample Customer',
      customerPhone: '+966 50 111 2233',
      customerEmail: 'customer@example.com',
      customerAddress: 'Riyadh, Saudi Arabia',
      customerOldBalance: 100,
      customerCurrentBalance: 120,
      paidAmount: 30,
      orderComment: 'Sample order comment',
      deliveryMethod: 'Home delivery',
      deliveryPhone: '+966 50 123 4567',
      customerAlternatePhone: '+966 50 123 4567',
      paymentMethod: 'Cash',
      paymentBreakdown: const {'Cash': 30.0, 'Card': 20.0},
      customerVatNumber: '310000000000003',
      customerCrNumber: '1010123456',
      customerType: 'B2C',
      zatcaVatNumber: zatcaVatNumber ?? '310000000000003',
      zatcaCrNumber: zatcaCrNumber ?? '1010123456',
      zatcaCompanyName: zatcaCompanyName ?? 'CloudPOS Store',
      netExcTax: '43.48',
      bankDetails: banks,
      storeName: store?.storeName ?? 'CloudPOS Store',
      storeLocation: store?.location ?? 'Riyadh, Saudi Arabia',
      storePhone: store?.phone ?? '+966 11 000 0000',
      storeEmail: store?.email ?? 'store@example.com',
      apiTotalTax: 6.52,
    );
    return Premium2BilingualReceiptLayout().renderPreviewPng(params);
  }

  @override
  Widget build(BuildContext context) {
    if (!_supportsExactPreview) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 10),
            color: Colors.amber.shade50,
            child: Text(
              'Exact preview support is being migrated for this template.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.amber.shade900),
            ),
          ),
          _ReceiptSample(
            options: widget.options,
            language: widget.language,
            section: widget.section,
          ),
        ],
      );
    }

    return FutureBuilder<Uint8List>(
      future: _previewFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 70),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 35, horizontal: 8),
            child: Column(
              children: [
                Icon(Icons.error_outline_rounded,
                    color: Colors.red.shade400, size: 30),
                const SizedBox(height: 9),
                Text(
                  'Exact preview could not be rendered.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10.5, color: Colors.red.shade700),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _previewFuture = _render();
                  }),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry preview'),
                ),
              ],
            ),
          );
        }
        return Image.memory(
          snapshot.data!,
          fit: BoxFit.fitWidth,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
        );
      },
    );
  }
}

class _ReceiptSample extends StatelessWidget {
  final Map<String, DisplayOption> options;
  final _PreviewLanguage language;
  final String section;

  const _ReceiptSample({
    required this.options,
    required this.language,
    required this.section,
  });

  static const _aliases = <String, List<String>>{
    'showTotalMRP': ['showMRPTotal'],
    'showTaxableAmount': ['showSubTotal'],
    'showNetTotal': ['showNetAmount'],
    'showPaymentBreakdown': ['showPaymentBreaked'],
    'showCustomerOldBalance': ['showCustomerPrevBalance'],
    'showCustomerCurrentBalance': ['showCustomerBalance'],
    'showPaidAmount': ['showCustomerPaidAmount'],
    'showBankDetails': ['showBankInfo'],
    'showBankAccountName': ['showAccountName'],
    'showBankAccountNumber': ['showAccountNumber'],
    'showBankIban': ['showIBAN'],
    'showBankSwiftCode': ['showSwiftCode'],
    'showTerms': ['showTermsConditions'],
  };

  DisplayOption? _option(String key) {
    final direct = options[key];
    if (direct != null) return direct;
    for (final alias in _aliases[key] ?? const <String>[]) {
      final option = options[alias];
      if (option != null) return option;
    }
    return null;
  }

  bool _visible(String key) => _option(key)?.visible == true;

  String _label(String key, String english, String arabic) {
    final option = _option(key);
    final en = option?.defaultValue?.trim().isNotEmpty == true
        ? option!.defaultValue!.trim()
        : english;
    final ar = option?.value?.toString().trim().isNotEmpty == true
        ? option!.value.toString().trim()
        : arabic;
    switch (language) {
      case _PreviewLanguage.english:
        return en;
      case _PreviewLanguage.arabic:
        return ar;
      case _PreviewLanguage.bilingual:
        return '$ar\n$en';
    }
  }

  TextDirection get _direction => language == _PreviewLanguage.english
      ? TextDirection.ltr
      : TextDirection.rtl;

  TextAlign get _align =>
      language == _PreviewLanguage.english ? TextAlign.left : TextAlign.right;

  @override
  Widget build(BuildContext context) {
    const line = BorderSide(color: Colors.black54, width: .7);
    return DefaultTextStyle(
      style: const TextStyle(
        fontFamily: 'monospace',
        color: Colors.black,
        fontSize: 10.5,
        height: 1.25,
      ),
      child: Directionality(
        textDirection: _direction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_visible('showStoreName'))
              Text(
                _label('showStoreName', 'CLOUDPOS STORE', 'متجر كلاود بوس'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15, height: 1.15),
              ),
            if (_visible('showDescription')) ...[
              const SizedBox(height: 4),
              Text(
                _label('showDescription', 'Fresh food & daily needs',
                    'مواد غذائية واحتياجات يومية'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            if (_visible('showStoreAddress')) ...[
              const SizedBox(height: 4),
              Text(
                _label('showStoreAddress', 'Riyadh, Saudi Arabia',
                    'الرياض، المملكة العربية السعودية'),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 9),
            if (_visible('showInvoiceTitle'))
              Text(
                _label('showInvoiceTitle', 'TAX INVOICE', 'فاتورة ضريبية'),
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: const BoxDecoration(
                border: Border(top: line, bottom: line),
              ),
              child: Column(
                children: [
                  if (_visible('showInvoiceNumber'))
                    _sampleRow(
                      _label(
                          'showInvoiceNumber', 'Invoice No.', 'رقم الفاتورة'),
                      '10428',
                    ),
                  if (_visible('showDate'))
                    _sampleRow(
                      _label('showDate', 'Date', 'التاريخ'),
                      '19-08-2026  10:45',
                    ),
                  if (_visible('showCustomerName'))
                    _sampleRow(
                      _label('showCustomerName', 'Customer', 'العميل'),
                      language == _PreviewLanguage.english
                          ? 'Sample Customer'
                          : 'عميل تجريبي',
                    ),
                  if (_visible('showDeliveryPhone'))
                    _sampleRow(
                      _label('showDeliveryPhone', 'Delivery Phone',
                          'هاتف التوصيل'),
                      '+966 50 123 4567',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            _itemHeader(line),
            const SizedBox(height: 5),
            Text(
              language == _PreviewLanguage.english
                  ? '1. Premium Coffee Beans'
                  : language == _PreviewLanguage.arabic
                      ? '١. حبوب قهوة فاخرة'
                      : '١. حبوب قهوة فاخرة\n1. Premium Coffee Beans',
              textAlign: _align,
            ),
            const SizedBox(height: 4),
            _sampleRow('2 × 25.00', '50.00'),
            if (_visible('showWarranty'))
              Text(
                _label('showWarranty', 'Warranty', 'الضمان'),
                textAlign: _align,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 7),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: const BoxDecoration(
                border: Border(top: line, bottom: line),
              ),
              child: Column(
                children: [
                  if (_visible('showTaxableAmount'))
                    _sampleRow(
                      _label('showTaxableAmount', 'Taxable Amount',
                          'المبلغ الخاضع للضريبة'),
                      '43.48',
                    ),
                  if (_visible('showTax'))
                    _sampleRow(
                      _label('showTax', 'VAT', 'الضريبة'),
                      '6.52',
                    ),
                  if (_visible('showNetTotal'))
                    _sampleRow(
                      _label('showNetTotal', 'NET TOTAL', 'الإجمالي الصافي'),
                      '50.00 SAR',
                      bold: true,
                    ),
                ],
              ),
            ),
            if (_visible('showBankDetails') && section == 'totals') ...[
              const SizedBox(height: 7),
              Text(
                _label('showBankDetails', 'BANK DETAILS', 'تفاصيل البنك'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              _sampleRow(
                _label('showBankName', 'Bank', 'البنك'),
                'Sample Bank',
              ),
              _sampleRow(
                _label('showBankIban', 'IBAN', 'آيبان'),
                'SA00 0000 0000 0000',
              ),
            ],
            if (_visible('showQRCode')) ...[
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 66,
                  height: 66,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: const Icon(Icons.qr_code_2, size: 56),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _label('showQRCode', 'Scan invoice QR', 'امسح رمز الفاتورة'),
                textAlign: TextAlign.center,
              ),
            ],
            if (_visible('showVATFooter')) ...[
              const SizedBox(height: 5),
              Text(
                '${_label('showVATFooter', 'VAT', 'الرقم الضريبي')}: 310000000000003',
                textAlign: TextAlign.center,
              ),
            ],
            if (_visible('showThankYouMessage')) ...[
              const SizedBox(height: 8),
              Text(
                _label('showThankYouMessage', 'Thank you for shopping!',
                    'شكراً لتسوقكم معنا!'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _itemHeader(BorderSide line) {
    final item =
        _label('showParticulars', 'ITEM', 'الصنف').replaceAll('\n', ' / ');
    final qty = _label('showQty', 'QTY', 'الكمية').replaceAll('\n', ' / ');
    final total =
        _label('showTotal', 'TOTAL', 'الإجمالي').replaceAll('\n', ' / ');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(border: Border(bottom: line)),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text(item, textAlign: _align)),
          if (_visible('showQty'))
            Expanded(flex: 2, child: Text(qty, textAlign: TextAlign.center)),
          if (_visible('showTotal'))
            Expanded(flex: 3, child: Text(total, textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _sampleRow(String label, String value, {bool bold = false}) {
    final style =
        TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w400);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label.replaceAll('\n', ' / '), style: style)),
          const SizedBox(width: 8),
          Text(value, style: style, textDirection: TextDirection.ltr),
        ],
      ),
    );
  }
}

class _ReceiptSection {
  final String id;
  final String label;
  final IconData icon;
  final String description;
  final List<String> keys;

  const _ReceiptSection({
    required this.id,
    required this.label,
    required this.icon,
    required this.description,
    required this.keys,
  });
}

enum _FieldSource { label, order, store, calculated, bank }

class _SourceBadge extends StatelessWidget {
  final _FieldSource source;

  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (source) {
      _FieldSource.label => ('Custom text', Colors.purple),
      _FieldSource.order => ('Order data', Colors.blue),
      _FieldSource.store => ('Store data', Colors.teal),
      _FieldSource.calculated => ('Calculated', Colors.orange),
      _FieldSource.bank => ('Bank data', Colors.indigo),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color.shade700,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SummaryChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: ColorManager.kPrimaryColor),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 11.5)),
        ],
      ),
    );
  }
}

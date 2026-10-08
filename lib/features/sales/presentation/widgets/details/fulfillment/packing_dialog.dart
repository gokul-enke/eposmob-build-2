import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/models/order_fulfillment.dart';
import 'package:pos_machine/providers/order_fulfillment_provider.dart';

import 'fulfillment_dialog_frame.dart';
import 'fulfillment_fields.dart';
import 'fulfillment_form_values.dart';
import 'packing_photo_thumbnail.dart';

class PackingDialog extends StatefulWidget {
  final String orderNumber;
  final String accessToken;
  final OrderDetailsModelDataPacking? packing;

  const PackingDialog({
    required this.orderNumber,
    required this.accessToken,
    this.packing,
  });

  @override
  State<PackingDialog> createState() => _PackingDialogState();
}

class _PackingDialogState extends State<PackingDialog> {
  static const _maxPhotoBytes = 20 * 1024 * 1024;
  static const _maxVideoBytes = 100 * 1024 * 1024;

  final _api = OrderFulfillmentProvider();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _packerName;
  late final TextEditingController _packedAt;
  late final String? _originalPackedAt;
  bool _packedAtChanged = false;
  List<PackingStaff> _staff = const [];
  int? _selectedStaffId;
  List<PlatformFile> _newPhotos = [];
  PlatformFile? _newVideo;
  final Set<String> _photosToDelete = <String>{};
  bool _loading = true;
  bool _submitting = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _packerName =
        TextEditingController(text: widget.packing?.packedByName ?? '');
    _originalPackedAt = widget.packing?.packedAt?.trim();
    _packedAt = TextEditingController(
        text: fulfillmentDateTimeDisplay(_originalPackedAt));
    _selectedStaffId = widget.packing?.packedByUserId;
    _loadStaff();
  }

  @override
  void dispose() {
    _packerName.dispose();
    _packedAt.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final staff =
          await _api.fetchPackingStaff(accessToken: widget.accessToken);
      if (!mounted) return;
      setState(() {
        _staff = staff;
        if (_staff.every((person) => person.id != _selectedStaffId)) {
          _selectedStaffId = null;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPackedAt() async {
    final existing = parseFulfillmentPackedAt(_packedAt.text) ??
        DateHelper.nowInConfiguredTimeZone();
    final date = await showDatePicker(
      context: context,
      initialDate: existing,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(existing),
    );
    if (time == null || !mounted) return;
    final result =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      _packedAt.text = fulfillmentDateTimeInput(result);
      _packedAtChanged = true;
    });
  }

  Future<void> _choosePhotos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null || !mounted) return;
    final oversized = result.files.where((file) => file.size > _maxPhotoBytes);
    if (oversized.isNotEmpty) {
      showFulfillmentMessage(
          context, 'sales_order_details.msg_photo_size_limit'.tr,
          isError: true);
      return;
    }
    setState(() => _newPhotos = [..._newPhotos, ...result.files]);
  }

  Future<void> _chooseVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp4', 'mov', 'webm'],
    );
    final file =
        result != null && result.files.isNotEmpty ? result.files.first : null;
    if (file == null || !mounted) return;
    if (file.size > _maxVideoBytes) {
      showFulfillmentMessage(
          context, 'sales_order_details.msg_video_size_limit'.tr,
          isError: true);
      return;
    }
    setState(() => _newVideo = file);
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    final packedAtInput = parseFulfillmentPackedAt(_packedAt.text);
    final packedAt = !_packedAtChanged &&
            _originalPackedAt != null &&
            _originalPackedAt!.isNotEmpty
        ? _originalPackedAt
        : DateHelper.configuredDateTimeToUtcIso(_packedAt.text);
    if (packedAtInput == null || packedAt == null) {
      showFulfillmentMessage(
          context, 'sales_order_details.msg_packed_at_required'.tr,
          isError: true);
      return;
    }
    if (_selectedStaffId == null && _packerName.text.trim().isEmpty) {
      showFulfillmentMessage(
          context, 'sales_order_details.msg_packer_required'.tr,
          isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await _api.savePacking(
        accessToken: widget.accessToken,
        orderNumber: widget.orderNumber,
        packedByUserId: _selectedStaffId,
        packedByName: _packerName.text,
        packedAt: packedAt,
        photos: _newPhotos,
        video: _newVideo,
        photosToDelete: _photosToDelete.toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted)
        showFulfillmentMessage(context, error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FulfillmentDialogFrame(
      title: 'sales_order_details.title_packing'.tr,
      canDismiss: !_submitting,
      footer: _loading || _loadError != null
          ? null
          : FulfillmentDialogActions(
              submitting: _submitting,
              submitLabel: 'sales_order_details.btn_save_packing'.tr,
              onSubmit: _submit,
            ),
      child: _loading
          ? const SizedBox(
              height: 180, child: Center(child: CircularProgressIndicator()))
          : _loadError != null
              ? FulfillmentLoadFailure(
                  message: _loadError!, onRetry: _loadStaff)
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FulfillmentFormGrid(children: [
                        fulfillmentDropdown<PackingStaff>(
                          label: 'sales_order_details.label_packed_by_staff'.tr,
                          value: _staff.any(
                                  (person) => person.id == _selectedStaffId)
                              ? _staff.firstWhere(
                                  (person) => person.id == _selectedStaffId)
                              : null,
                          items: _staff,
                          itemLabel: (person) => person.name,
                          onChanged: (staff) {
                            setState(() {
                              // `packed_by_name` is reserved for a manually
                              // entered alternate packer, not the staff label.
                              _selectedStaffId = staff?.id;
                            });
                          },
                        ),
                        fulfillmentTextField(
                          controller: _packerName,
                          label: 'sales_order_details.label_packer_name'.tr,
                        ),
                        fulfillmentDateField(
                          controller: _packedAt,
                          label:
                              'sales_order_details.label_packed_date_time'.tr,
                          onTap: _pickPackedAt,
                          required: true,
                        ),
                      ]),
                      const SizedBox(height: 12),
                      fulfillmentFilePickerCard(
                        title:
                            'sales_order_details.label_add_packing_photos'.tr,
                        buttonLabel: 'sales_order_details.btn_choose_photos'.tr,
                        icon: Icons.add_photo_alternate_outlined,
                        onPick: _choosePhotos,
                        files: _newPhotos,
                        showImagePreviews: true,
                        onRemove: (index) =>
                            setState(() => _newPhotos.removeAt(index)),
                      ),
                      if ((widget.packing?.packingPhotoPaths ?? const [])
                          .isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _existingPhotos(),
                      ],
                      const SizedBox(height: 12),
                      fulfillmentFilePickerCard(
                        title: 'sales_order_details.label_packing_video'.tr,
                        buttonLabel: 'sales_order_details.btn_choose_video'.tr,
                        icon: Icons.video_file_outlined,
                        onPick: _chooseVideo,
                        files: _newVideo == null ? const [] : [_newVideo!],
                        onRemove: (_) => setState(() => _newVideo = null),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _existingPhotos() {
    final storedPaths = widget.packing?.packingPhotoPaths ?? const <String>[];
    final displayUrls = widget.packing?.packingPhotos ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('sales_order_details.label_existing_packing_photos'.tr,
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        ...storedPaths.asMap().entries.map(
          (entry) {
            final displayUrl =
                entry.key < displayUrls.length ? displayUrls[entry.key] : null;
            return CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text((displayUrl ?? entry.value).split('/').last),
              secondary: RemotePackingPhotoThumbnail(imageUrl: displayUrl),
              value: _photosToDelete.contains(entry.value),
              onChanged: (selected) => setState(() {
                if (selected == true) {
                  _photosToDelete.add(entry.value);
                } else {
                  _photosToDelete.remove(entry.value);
                }
              }),
              controlAffinity: ListTileControlAffinity.leading,
            );
          },
        ),
        Text('sales_order_details.msg_select_photos_to_delete'.tr,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

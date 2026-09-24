# Translation review — Arabic & Malayalam

Every Arabic and Malayalam string added or changed on this branch, with its English source. These were produced during the i18n alignment work and have **not** been reviewed by a native speaker.

Baseline: `f4089e93`. Placeholders such as `@count` must survive unchanged in the translation — the test suite enforces this, so if you reword a line, keep every `@name` token.

## Arabic (`ar.json`) — 839 added, 1 changed

- **562 newly translated** — written during this work. **These are the ones that need review.**
- **277 copied** from the translation this locale already used for the identical English string. Lower risk, but worth a skim for context: a word that fits one screen may not fit another.
- **0 recovered** — existing translations that were already in the file but unreachable, because a duplicate of their namespace shadowed them. Not new work; listed only for completeness.

### Changed (existing strings replaced)

| Key | English | Was | Now | Placeholders |
|---|---|---|---|---|
| `product_detail.status_out_of_stock` | Out of Stock | نفدت الكمية | نفاد المخزون |  |

### Newly translated — needs review

| Key | English | Arabic | Placeholders |
|---|---|---|---|
| `add_customer.payment_type` | Payment Type | نوع الدفع |  |
| `add_customer.to_pay` | To Pay | مستحق الدفع |  |
| `add_customer.to_receive` | To Receive | مستحق القبض |  |
| `add_customer.validator_email_invalid` | Enter a valid email address | أدخل عنوان بريد إلكتروني صالح |  |
| `add_customer.validator_phone_invalid` | Enter a valid phone number | أدخل رقم هاتف صالح |  |
| `add_supplier.error_adding_supplier` | Error adding supplier: @error | خطأ في إضافة المورد: @error | @error |
| `add_supplier.product_property_number` | Product Property must be a number. | يجب أن تكون خاصية المنتج رقمًا. |  |
| `billing.active_orders` | Active Orders | الطلبات النشطة |  |
| `billing.add_items_to_quote_first` | Please add items to quote first. | يرجى إضافة عناصر إلى عرض السعر أولاً. |  |
| `billing.add_payment` | Add Payment | إضافة دفعة |  |
| `billing.add_product_custom` | Add product with custom price and quantity | إضافة منتج بسعر وكمية مخصصين |  |
| `billing.add_product_to_cart` | Add product to cart | إضافة المنتج إلى السلة |  |
| `billing.add_remaining_to_account` | Add remaining amount to customer account | إضافة المبلغ المتبقي إلى حساب العميل |  |
| `billing.additional_purchase_tax` | Additional Purchase Tax | ضريبة شراء إضافية |  |
| `billing.amount_due` | (Amount Due) | (المبلغ المستحق) |  |
| `billing.amount_due_added` | Amount Due (will be added to customer account) | المبلغ المستحق (سيُضاف إلى حساب العميل) |  |
| `billing.amount_due_recorded` | Amount Due (will be recorded as due) | المبلغ المستحق (سيُسجل كمستحق) |  |
| `billing.auto_calculated` | (Auto calculated) | (محسوب تلقائيًا) |  |
| `billing.balance_amount` | Balance Amount | المبلغ المتبقي |  |
| `billing.barcode` | Barcode | الباركود |  |
| `billing.barcode_generation_error` | Error generating barcode: | خطأ في إنشاء الباركود: |  |
| `billing.base_unit` | Base Unit | الوحدة الأساسية |  |
| `billing.billing` | Billing | الفوترة |  |
| `billing.card_posted` | Card Posted: | المسجل بالبطاقة: |  |
| `billing.cart_empty_or_data_unavailable` | Cart is empty or data not available | السلة فارغة أو البيانات غير متوفرة |  |
| `billing.cash_balance_label` | Cash Balance: | الرصيد النقدي: |  |
| `billing.cash_posted` | Cash Posted: | المسجل نقدًا: |  |
| `billing.choose_variant_to_cart` | Choose a variant to add to cart | اختر نوعًا لإضافته إلى السلة |  |
| `billing.clear_cart_failed` | Failed to clear cart. Please try again. | فشل إفراغ السلة. يرجى المحاولة مرة أخرى. |  |
| `billing.cod_posted` | COD Posted: | المسجل عند الاستلام: |  |
| `billing.compact_view` | Compact view | عرض مضغوط |  |
| `billing.confirm_stock_submission` | Confirm Stock Submission | تأكيد إرسال المخزون |  |
| `billing.confirm_submit` | Confirm & Submit | تأكيد وإرسال |  |
| `billing.coupon_apply_failed` | Failed to Apply Coupon | فشل تطبيق القسيمة |  |
| `billing.credit_amount_stored` | @currency @amount will be stored as customer account credit. | سيتم حفظ @currency @amount كرصيد في حساب العميل. | @currency @amount |
| `billing.current_supplier_balance` | Current Supplier Balance | رصيد المورد الحالي |  |
| `billing.customer_credit_posted` | To Customer Credit: | إلى رصيد العميل: |  |
| `billing.customer_prefix` | Customer:  | العميل:  |  |
| `billing.customer_purchase_history` | Customer purchase history | سجل مشتريات العميل |  |
| `billing.data_synced_successfully` | Data synced successfully! | تمت مزامنة البيانات بنجاح! |  |
| `billing.delete_saved_order` | Delete saved order | حذف الطلب المحفوظ |  |
| `billing.discount_applied_successfully` | Discount applied successfully | تم تطبيق الخصم بنجاح |  |
| `billing.discount_cleared` | Discount cleared | تم مسح الخصم |  |
| `billing.enter_customer_credit_amount` | Enter amount to add as customer credit | أدخل المبلغ لإضافته كرصيد للعميل |  |
| `billing.enter_name_in_language` | Enter name in @language | أدخل الاسم بـ @language | @language |
| `billing.enter_or_generate_barcode` | Enter or generate | أدخل أو أنشئ |  |
| `billing.enter_received_amounts` | Enter received amounts | أدخل المبالغ المستلمة |  |
| `billing.enter_transaction_reference` | Enter transaction reference number | أدخل رقم مرجع المعاملة |  |
| `billing.enter_values_before_adding` | Enter values before adding to cart | أدخل القيم قبل الإضافة إلى السلة |  |
| `billing.error_occurred_try_again` | Error Occurred! Try Again | حدث خطأ! حاول مرة أخرى |  |
| `billing.excess_amount` | Excess Amount | المبلغ الزائد |  |
| `billing.excess_returned_as_change` | @currency @amount will be returned as change unless customer credit is enabled. | سيتم إرجاع @currency @amount كباقٍ ما لم يتم تفعيل رصيد العميل. | @currency @amount |
| `billing.excess_to_account_credit` | Will be created as customer account credit | سيتم إنشاؤه كرصيد في حساب العميل |  |
| `billing.expiry_before_quotation` | Expiry date cannot be before quotation date. | لا يمكن أن يكون تاريخ الانتهاء قبل تاريخ عرض السعر. |  |
| `billing.extra_payment_method` | Extra | إضافي |  |
| `billing.finalize_order` | Finalize Order | إنهاء الطلب |  |
| `billing.grid_view` | Grid view | عرض شبكي |  |
| `billing.if_any` | (if any) | (إن وجد) |  |
| `billing.included_purchase_tax` | Included Purchase Tax | ضريبة الشراء المضمنة |  |
| `billing.item_quantity_updated` | Item quantity updated successfully | تم تحديث كمية العنصر بنجاح |  |
| `billing.item_removed_successfully` | Item removed successfully | تمت إزالة العنصر بنجاح |  |
| `billing.items_in_cart` | @count items in cart | @count عناصر في السلة | @count |
| `billing.items_to_be_submitted` | @count item(s) to be submitted | @count عنصر سيتم إرساله | @count |
| `billing.last_purchases` | Last @count Purchase@plural: | آخر @count عملية شراء@plural: | @count @plural |
| `billing.list_view` | List view | عرض قائمة |  |
| `billing.low_stock` | Low stock | مخزون منخفض |  |
| `billing.market` | Market | السوق |  |
| `billing.new_order_reset` | New order started | تم بدء طلب جديد |  |
| `billing.no_customers_found` | No customers found | لم يتم العثور على عملاء |  |
| `billing.no_excess_collected` | No excess collected | لم يتم تحصيل مبلغ زائد |  |
| `billing.no_internet_sync` | No internet connection available for sync. | لا يوجد اتصال بالإنترنت للمزامنة. |  |
| `billing.no_items_in_cart_to_save` | No items in cart to save | لا توجد عناصر في السلة للحفظ |  |
| `billing.no_other_languages` | No other languages available. | لا توجد لغات أخرى متاحة. |  |
| `billing.no_permission_view_details` | No permission to view product details | لا توجد صلاحية لعرض تفاصيل المنتج |  |
| `billing.no_purchase_history` | No purchase history found for this product | لم يتم العثور على سجل شراء لهذا المنتج |  |
| `billing.nothing_remaining` | Nothing remaining — fully covered | لا يوجد متبقٍ — تمت التغطية بالكامل |  |
| `billing.old_supplier_balance` | Old Supplier Balance | رصيد المورد السابق |  |
| `billing.open_cash_drawer` | Open cash drawer | فتح درج النقد |  |
| `billing.optional` | Optional | اختياري |  |
| `billing.order` | Order | الطلب |  |
| `billing.out_of_stock` | Out of stock | غير متوفر في المخزون |  |
| `billing.paid_with_pine_labs` | Paid with Pine Labs ✓ | تم الدفع عبر Pine Labs ✓ |  |
| `billing.pay_with_pine_labs` | Pay with Pine Labs | الدفع عبر Pine Labs |  |
| `billing.pine_labs_payment_successful` | Pine Labs payment successful | تم الدفع عبر Pine Labs بنجاح |  |
| `billing.please_wait` | Please wait. | يرجى الانتظار. |  |
| `billing.price_quantity` | Price × Qty | السعر × الكمية |  |
| `billing.print_saved_order` | Print saved order | طباعة الطلب المحفوظ |  |
| `billing.proceed_to_payment` | Proceed to Payment | المتابعة إلى الدفع |  |
| `billing.processing` | Processing... | جارٍ المعالجة... |  |
| `billing.product_fetch_error` | Error fetching product: | خطأ في جلب المنتج: |  |
| `billing.product_prefix` | Product:  | المنتج:  |  |
| `billing.products_loading` | Please wait while products are being loaded. | يرجى الانتظار أثناء تحميل المنتجات. |  |
| `billing.purchase_history_default_customer` | Purchase history is not shown for the default customer | لا يتم عرض سجل الشراء للعميل الافتراضي |  |
| `billing.purchase_history_disabled` | Customer purchase history is disabled | سجل مشتريات العميل معطل |  |
| `billing.purchase_history_load_failed` | Unable to load purchase history | تعذر تحميل سجل الشراء |  |
| `billing.quotation_created` | Quotation created successfully! | تم إنشاء عرض السعر بنجاح! |  |
| `billing.ready_for_pickup` | Ready for Pickup | جاهز للاستلام |  |
| `billing.record_unpaid_due` | Record the unpaid amount as due | تسجيل المبلغ غير المدفوع كمستحق |  |
| `billing.remaining_amount` | Remaining Amount | المبلغ المتبقي |  |
| `billing.remove_item` | Remove item | إزالة العنصر |  |
| `billing.scan_or_enter_barcode` | Scan or enter barcode | امسح أو أدخل الباركود |  |
| `billing.search_products` | Search products | البحث عن المنتجات |  |
| `billing.select_customer_for_credit` | Select a customer to store account credit | اختر عميلاً لحفظ رصيد الحساب |  |
| `billing.select_customer_purchase_history` | Select a customer to view purchase history | اختر عميلاً لعرض سجل الشراء |  |
| `billing.select_delivery_method` | Select Delivery Method | اختر طريقة التوصيل |  |
| `billing.select_or_enter_customer_quote` | Please select or enter a customer before creating quotation. | يرجى اختيار أو إدخال عميل قبل إنشاء عرض السعر. |  |
| `billing.select_price_for` | Select Price for | اختر السعر لـ |  |
| `billing.select_variant` | Select variant | اختر النوع |  |
| `billing.sell_on_credit` | Sell on Credit | البيع بالآجل |  |
| `billing.set_price_quantity` | Set Price & Quantity | تعيين السعر والكمية |  |
| `billing.submit_without_payment` | Submit Without Payment? | إرسال بدون دفع؟ |  |
| `billing.submitting_without_payment` | Submitting without payment. Full amount will be recorded as balance due. | جارٍ الإرسال بدون دفع. سيتم تسجيل المبلغ الكامل كرصيد مستحق. |  |
| `billing.total_paid_amount` | Total Paid Amount | إجمالي المبلغ المدفوع |  |
| `billing.total_purchase_tax` | Total Purchase + Tax | إجمالي الشراء + الضريبة |  |
| `billing.translate_from_english` | Translate from English | الترجمة من الإنجليزية |  |
| `billing.unable_change_cart_unit` | Unable to change unit for this cart item. | تعذر تغيير الوحدة لهذا العنصر في السلة. |  |
| `billing.updated_local_draft` | Updated local draft | تم تحديث المسودة المحلية |  |
| `billing.upi_posted` | UPI Posted: | المسجل عبر UPI: |  |
| `billing.use_current_price` | Use Current Price | استخدام السعر الحالي |  |
| `billing.use_this` | Use This | استخدام هذا |  |
| `billing.warranty_accept_hint` | The customer accepts the warranty terms for this item | يقبل العميل شروط الضمان لهذا العنصر |  |
| `billing.warranty_condition` | Warranty condition: @condition | شرط الضمان: @condition | @condition |
| `billing.yes_submit` | Yes, Submit | نعم، إرسال |  |
| `billing_mobile_errors.pine_labs_payment_successful` | Pine Labs payment successful | تم الدفع عبر Pine Labs بنجاح |  |
| `calendar.custom_date` | Custom Date | تاريخ مخصص |  |
| `calendar.date_must_be_between` | Date must be between @from and @to | يجب أن يكون التاريخ بين @from و @to | @from @to |
| `calendar.invalid_date_format` | Invalid date. Try: 20250205 or 2025-02-05 or 05-02-2025 | تاريخ غير صالح. جرّب: 20250205 أو 2025-02-05 أو 05-02-2025 |  |
| `calendar.one_week` | 1 Week | أسبوع واحد |  |
| `calendar.quick_date_selection` | Quick Date Selection | اختيار سريع للتاريخ |  |
| `calendar.select_time` | Select Time | اختر الوقت |  |
| `cancel_order_modal.description` | Select a payment method and refund amount for this order. | اختر طريقة دفع ومبلغ استرداد لهذا الطلب. |  |
| `cancel_order_modal.original_total` | Original total: @amount | الإجمالي الأصلي: @amount | @amount |
| `cancel_order_modal.refund_amount` | Refund Amount | مبلغ الاسترداد |  |
| `cancel_order_modal.refund_amount_exceeds_total` | Refund amount cannot exceed the original total | لا يمكن أن يتجاوز مبلغ الاسترداد الإجمالي الأصلي |  |
| `cancel_order_modal.refund_amount_positive` | Refund amount must be greater than 0 | يجب أن يكون مبلغ الاسترداد أكبر من 0 |  |
| `category.category_icon` | Category Icon: | أيقونة الفئة: |  |
| `category.category_image` | Category Image: | صورة الفئة: |  |
| `category.enter_name_before_translating` | Please enter Category Name before translating. | يرجى إدخال اسم الفئة قبل الترجمة. |  |
| `category.name` | Name | الاسم |  |
| `category.parent_category` | Parent Category | الفئة الأصلية |  |
| `category.product_property_number` | Product Property must be a number. | يجب أن تكون خاصية المنتج رقمًا. |  |
| `category.select_parent_optional` | Select Parent Category (optional) | اختر الفئة الأصلية (اختياري) |  |
| `change_order_status.delivery_logistics` | Delivery Logistics | لوجستيات التوصيل |  |
| `change_order_status.refund_amount` | Refund Amount | مبلغ الاسترداد |  |
| `change_order_status.refund_exceeds_total` | Refund amount cannot exceed order total (@total) | لا يمكن أن يتجاوز مبلغ الاسترداد إجمالي الطلب (@total) | @total |
| `change_order_status.refund_payment_method` | Refund Payment Method | طريقة دفع الاسترداد |  |
| `change_order_status.title` | Update Order Status | تحديث حالة الطلب |  |
| `change_order_status.update_status` | Update Status | تحديث الحالة |  |
| `change_payment_status.order_total` | Order Total: @amount | إجمالي الطلب: @amount | @amount |
| `change_payment_status.title` | Update Payment Status | تحديث حالة الدفع |  |
| `change_payment_status.update_payment` | Update Payment | تحديث الدفع |  |
| `checkout_modal.confirm_payment_selection` | Confirm Payment Selection | تأكيد اختيار الدفع |  |
| `checkout_modal.label_balance` | Balance | الرصيد |  |
| `checkout_modal.msg_expiry_before_quotation` | Expiry date cannot be before quotation date | لا يمكن أن يكون تاريخ الانتهاء قبل تاريخ عرض السعر |  |
| `checkout_modal.msg_select_customer_before_confirm` | Please select a customer before confirming | يرجى اختيار عميل قبل التأكيد |  |
| `checkout_modal.msg_select_customer_for_quotation` | Please select a customer before creating quotation | يرجى اختيار عميل قبل إنشاء عرض السعر |  |
| `checkout_modal.msg_unable_to_create_quotation` | Unable to create quotation | تعذر إنشاء عرض السعر |  |
| `checkout_modal.title_finalize_order` | Finalize Order | إنهاء الطلب |  |
| `common.confirm_location` | Confirm Location | تأكيد الموقع |  |
| `common.items_count` | (@count) items | (@count) عناصر | @count |
| `common.loading_map_picker` | Loading map picker... | جارٍ تحميل محدد الخريطة... |  |
| `common.location_picker_asset_missing` | Error: Location picker asset template missing. | خطأ: قالب محدد الموقع مفقود. |  |
| `common.no_location_selected` | No location selected yet. Search an address or tap/drag the map pin. | لم يتم اختيار موقع بعد. ابحث عن عنوان أو اضغط على دبوس الخريطة أو اسحبه. |  |
| `common.no_store_selected` | No store selected | لم يتم اختيار متجر |  |
| `common.pick_customer_location` | Pick Customer Location | اختر موقع العميل |  |
| `common.search_customer` | Search customer... | البحث عن عميل... |  |
| `common.states_provinces` | States / Provinces | الولايات / المحافظات |  |
| `company_admin.inventory` | Inventory | المخزون |  |
| `company_admin.new_sale` | New Sale | عملية بيع جديدة |  |
| `company_admin.payment_cash` | Cash | نقدًا |  |
| `company_admin.payment_other` | Other | أخرى |  |
| `company_admin.payment_upi` | UPI | UPI |  |
| `confirmed_orders.quantity_prefix` | Qty:  | الكمية:  |  |
| `confirmed_orders.subtitle` | Manage and track your confirmed orders | إدارة وتتبع طلباتك المؤكدة |  |
| `confirmed_orders.successfully_synced` | Successfully synced @count orders! | تمت مزامنة @count طلبات بنجاح! | @count |
| `confirmed_orders.sync_wait` | Please wait while we sync your data. | يرجى الانتظار بينما تتم مزامنة بياناتك. |  |
| `coupon.apply_discount` | Apply Discount | تطبيق الخصم |  |
| `coupon.applying` | Applying... | جارٍ التطبيق... |  |
| `coupon.discount_amount` | Discount Amount: | مبلغ الخصم: |  |
| `coupon.discount_and_coupon` | Discount & Coupon | الخصم والقسيمة |  |
| `coupon.empty_cart_hint` | Cart is empty. Add products before applying discounts. | السلة فارغة. أضف منتجات قبل تطبيق الخصومات. |  |
| `coupon.flat_discount_negative` | Flat discount cannot be negative | لا يمكن أن يكون الخصم الثابت سالبًا |  |
| `coupon.invalid_selected` | Cannot apply @name: Coupon is not valid | تعذر تطبيق @name: القسيمة غير صالحة | @name |
| `coupon.net_total` | Net Total: | الإجمالي الصافي: |  |
| `coupon.percentage_discount` | Percentage Discount (%) | الخصم بالنسبة المئوية (%) |  |
| `coupon.percentage_discount_negative` | Percentage discount cannot be negative | لا يمكن أن يكون الخصم بالنسبة المئوية سالبًا |  |
| `coupon.search_by_code_or_name` | Search by code or name... | البحث بالرمز أو الاسم... |  |
| `coupon.search_or_select` | Search or select a discount | ابحث أو اختر خصمًا |  |
| `coupon.select_coupon` | Select Coupon | اختر قسيمة |  |
| `coupon.total_after_discount` | Total after Discount: | الإجمالي بعد الخصم: |  |
| `customer.label_states` | States / Provinces | الولايات / المحافظات |  |
| `customer.payment_type` | Payment Type | نوع الدفع |  |
| `customer.states_provinces` | States / Provinces | الولايات / المحافظات |  |
| `customer.to_pay` | To Pay | مستحق الدفع |  |
| `customer.to_receive` | To Receive | مستحق القبض |  |
| `customer_profile.error_update_failed` | Failed to update customer | فشل تحديث العميل |  |
| `customer_profile.error_update_retry` | Failed to update customer. Please try again. | فشل تحديث العميل. يرجى المحاولة مرة أخرى. |  |
| `customer_profile.updated_successfully` | Customer updated successfully | تم تحديث العميل بنجاح |  |
| `customer_transaction_report.discount` | Discount: | الخصم: |  |
| `customer_transaction_report.net_total` | Net Total: | الإجمالي الصافي: |  |
| `customer_transaction_report.print_transaction_report` | Print Transaction Report | طباعة تقرير المعاملات |  |
| `customer_transaction_report.total_amount` | Total Amount: | المبلغ الإجمالي: |  |
| `customer_transaction_report.total_transactions` | Total Transactions: | إجمالي المعاملات: |  |
| `customer_transaction_report.you_saved` | You Saved: | لقد وفرت: |  |
| `daily_sales_close.generated_on` | Generated on: @time | تم الإنشاء في: @time | @time |
| `daily_sales_close.kot_sent_to_printer` | KOT sent to @printer | تم إرسال KOT إلى @printer | @printer |
| `daily_sales_close.mrp` | MRP | السعر الأقصى للبيع |  |
| `daily_sales_close.note` | Note | ملاحظة |  |
| `daily_sales_close.order` | Order | الطلب |  |
| `daily_sales_close.paid` | Paid | مدفوع |  |
| `daily_sales_close.sales_summary` | Sales Summary | ملخص المبيعات |  |
| `daily_sales_close.sent_to_printer` | Daily Close sent to @printer | تم إرسال الإغلاق اليومي إلى @printer | @printer |
| `daily_sales_close.token` | Token | الرمز |  |
| `daily_sales_close.total_expenses` | Total Expenses | إجمالي المصروفات |  |
| `daily_sales_close.total_refunds` | Total Refunds | إجمالي المبالغ المستردة |  |
| `daily_sales_close.total_returns` | Total Returns | إجمالي المرتجعات |  |
| `dining.available_soon` | Available soon | متاح قريبًا |  |
| `dining.filled` | Filled | ممتلئ |  |
| `dining.indoor` | Indoor | داخلي |  |
| `dining.outdoor` | Outdoor | خارجي |  |
| `dining.reserved` | Reserved | محجوز |  |
| `dining.table_list` | Table List | قائمة الطاولات |  |
| `general.action` | Action | الإجراء |  |
| `general.action_failed` | Action failed | فشل الإجراء |  |
| `general.add_more` | Add More | إضافة المزيد |  |
| `general.authentication_failed` | Authentication failed | فشل المصادقة |  |
| `general.card_upi_not_allowed_together` | Card and UPI cannot be used together | لا يمكن استخدام البطاقة و UPI معًا |  |
| `general.cash` | Cash | نقدًا |  |
| `general.category_added_successfully` | Category added successfully | تمت إضافة الفئة بنجاح |  |
| `general.collapse_sidebar` | Collapse Sidebar | طي الشريط الجانبي |  |
| `general.confirm_and_print` | Confirm & Print | تأكيد وطباعة |  |
| `general.confirm_delete_item` | Are you sure you want to delete '@item'? | هل أنت متأكد أنك تريد حذف '@item'؟ | @item |
| `general.customer_prefix` | Customer:  | العميل:  |  |
| `general.data_synced_successfully` | Data synced successfully! | تمت مزامنة البيانات بنجاح! |  |
| `general.default_name` | Default Name | الاسم الافتراضي |  |
| `general.delete_item` | Delete Item | حذف العنصر |  |
| `general.delete_warning` | This action cannot be undone. | لا يمكن التراجع عن هذا الإجراء. |  |
| `general.enter_mobile_number` | Enter mobile number | أدخل رقم الجوال |  |
| `general.enter_password` | Please enter password | يرجى إدخال كلمة المرور |  |
| `general.enter_password_for` | Enter password for @name | أدخل كلمة المرور لـ @name | @name |
| `general.enter_payment_amount` | Enter @method Amount | أدخل مبلغ @method | @method |
| `general.error_occurred_try_again` | Error Occurred! Try Again | حدث خطأ! حاول مرة أخرى |  |
| `general.error_prefix` | Error: | خطأ: |  |
| `general.expand_sidebar` | Expand Sidebar | توسيع الشريط الجانبي |  |
| `general.expected` | Expected | المتوقع |  |
| `general.failed` | Failed | فشل |  |
| `general.failed_to_add_category` | Failed to add category | فشل إضافة الفئة |  |
| `general.failed_to_load_graph_data` | Failed to load graph data: @error | فشل تحميل بيانات الرسم البياني: @error | @error |
| `general.items_count` | Items: @count | العناصر: @count | @count |
| `general.keyboard_shortcuts` | Keyboard Shortcuts | اختصارات لوحة المفاتيح |  |
| `general.logged_out_locally` | Logged out locally | تم تسجيل الخروج محليًا |  |
| `general.logged_out_successfully` | Logged out successfully | تم تسجيل الخروج بنجاح |  |
| `general.no_current_store_access` | @name doesn't have access to current store. Please logout and try. | @name ليس لديه صلاحية الوصول إلى المتجر الحالي. يرجى تسجيل الخروج والمحاولة مرة أخرى. | @name |
| `general.no_email` | No email | لا يوجد بريد إلكتروني |  |
| `general.no_expiry` | No expiry | لا يوجد تاريخ انتهاء |  |
| `general.no_store_permission` | @name has no permission to any store. Please contact your administrator. | @name ليس لديه صلاحية لأي متجر. يرجى الاتصال بالمسؤول. | @name |
| `general.not_authenticated` | Not Authenticated | غير مصادق عليه |  |
| `general.numeric_keyboard` | Numeric Keyboard | لوحة مفاتيح رقمية |  |
| `general.optional` | Optional | اختياري |  |
| `general.overpaid` | Overpaid | مدفوع بالزيادة |  |
| `general.please_wait` | Please wait... | يرجى الانتظار... |  |
| `general.price_below_minimum` | Price is below the minimum sale price of @price | السعر أقل من الحد الأدنى لسعر البيع @price | @price |
| `general.print_customer_copy` | Print customer copy? | طباعة نسخة العميل؟ |  |
| `general.print_customer_copy_prompt` | Do you want to print a customer copy now? | هل تريد طباعة نسخة العميل الآن؟ |  |
| `general.product_prefix` | Product:  | المنتج:  |  |
| `general.quantity_prefix` | Qty:  | الكمية:  |  |
| `general.remaining` | Remaining | المتبقي |  |
| `general.resume` | Resume | استئناف |  |
| `general.select` | Select | اختر |  |
| `general.sell_anyway` | Sell anyway | البيع على أي حال |  |
| `general.show_less` | Show less | عرض أقل |  |
| `general.show_more_items` | Show @count more | عرض @count عناصر إضافية | @count |
| `general.skip` | Skip | تخطي |  |
| `general.stock_mismatch` | Stock mismatch | عدم تطابق المخزون |  |
| `general.success` | Success | نجاح |  |
| `general.switch` | Switch | تبديل |  |
| `general.switch_user` | Switch User | تبديل المستخدم |  |
| `general.switched_successfully` | Successfully switched to @name | تم التبديل بنجاح إلى @name | @name |
| `general.total_entered` | Total Entered | إجمالي المُدخل |  |
| `general.unable_open_cash_drawer` | Unable to open cash drawer | تعذر فتح درج النقد |  |
| `general.unable_prepare_print` | Unable to prepare this order for printing | تعذر تجهيز هذا الطلب للطباعة |  |
| `general.upi` | UPI | UPI |  |
| `general.valid_quantity_required` | Enter a valid quantity | أدخل كمية صالحة |  |
| `general.virtual_keyboard` | Virtual Keyboard | لوحة مفاتيح افتراضية |  |
| `general.yes_print` | Yes, print | نعم، اطبع |  |
| `invoice.amount_prefix` | Amount: @amount | المبلغ: @amount | @amount |
| `invoice.date_format` | DD/MM/YYYY | DD/MM/YYYY |  |
| `invoice.date_prefix` | Invoice: @date | الفاتورة: @date | @date |
| `invoice.due_prefix` | Due: @date | الاستحقاق: @date | @date |
| `invoice.name` | Name | الاسم |  |
| `invoice.selected_count` | @count selected | @count محدد | @count |
| `invoice.sync_not_sent` | Sync Not Sent | لم تتم المزامنة |  |
| `invoice.type_prefix` | Type: @type | النوع: @type | @type |
| `invoice.yes_print` | Yes, print | نعم، اطبع |  |
| `invoice_pdf.company_address` | Your Company Address | عنوان شركتك |  |
| `invoice_pdf.company_email` | Email: Your Email | البريد الإلكتروني: بريدك الإلكتروني |  |
| `invoice_pdf.company_name` | Your Company Name | اسم شركتك |  |
| `invoice_pdf.company_phone` | Phone: Your Phone | الهاتف: هاتفك |  |
| `invoice_pdf.customer_details` | Customer Details: | تفاصيل العميل: |  |
| `invoice_pdf.delivery_status` | Delivery Status | حالة التوصيل |  |
| `invoice_pdf.discount` | Discount | الخصم |  |
| `invoice_pdf.error_generating_pdf` | Error generating PDF: @error | خطأ في إنشاء ملف PDF: @error | @error |
| `invoice_pdf.fetching_order_details` | Fetching order details... | جارٍ جلب تفاصيل الطلب... |  |
| `invoice_pdf.gst_registration_no` | GST Registration No: Your GST | رقم التسجيل الضريبي: رقمك |  |
| `invoice_pdf.name` | Name | الاسم |  |
| `invoice_pdf.net_total` | Net Total | الإجمالي الصافي |  |
| `invoice_pdf.original_for_recipient` | (Original for Recipient) | (النسخة الأصلية للمستلم) |  |
| `invoice_pdf.pan_no` | PAN NO: Your PAN | رقم PAN: رقمك |  |
| `invoice_pdf.share_subject` | Order PDF | ملف PDF للطلب |  |
| `invoice_pdf.share_text` | Here is your order details PDF | إليك ملف PDF بتفاصيل طلبك |  |
| `invoice_pdf.sold_by` | Sold By: | تم البيع بواسطة: |  |
| `invoice_pdf.thank_you` | Thank you for your order! | شكرًا لطلبك! |  |
| `keyboard.add_product_modal` | Add Product Modal | نافذة إضافة منتج |  |
| `keyboard.billing_restaurant` | Billing (Restaurant) | الفوترة (مطعم) |  |
| `keyboard.billing_standard` | Billing (Standard) | الفوترة (قياسي) |  |
| `keyboard.cart_restaurant` | Cart (Restaurant) | السلة (مطعم) |  |
| `keyboard.cart_standard` | Cart (Standard) | السلة (قياسي) |  |
| `keyboard.checkout_modal` | Checkout Modal | نافذة الدفع |  |
| `keyboard.global` | Global | عام |  |
| `keyboard.shared` | Shared | مشترك |  |
| `keyboard.show` | Show | إظهار |  |
| `nav.section_accounts` | Accounts | الحسابات |  |
| `nav.section_directory` | Directory | الدليل |  |
| `nav.section_inventory` | Inventory | المخزون |  |
| `nav.section_main` | Main | الرئيسية |  |
| `order_panel.add_comment` | Add Comment | إضافة تعليق |  |
| `order_panel.add_products_to_start` | Add products from the menu ⏎ to start a new order | أضف منتجات من القائمة ⏎ لبدء طلب جديد |  |
| `order_panel.balance` | Balance | الرصيد |  |
| `order_panel.bill` | BILL | الفاتورة |  |
| `order_panel.comment` | Comment | تعليق |  |
| `order_panel.finalize_order` | Finalize Order | إنهاء الطلب |  |
| `order_panel.kot` | KOT | KOT |  |
| `order_panel.mark_served` | Mark Served | تحديد كمُقدَّم |  |
| `order_panel.net_amount` | Net Amount | المبلغ الصافي |  |
| `order_panel.no_items_in_order` | No items in this order | لا توجد عناصر في هذا الطلب |  |
| `order_panel.pre_bill` | Pre-Bill | فاتورة مبدئية |  |
| `order_panel.save_offline_order` | Save Offline Order | حفظ الطلب دون اتصال |  |
| `order_panel.serve` | Serve | تقديم |  |
| `order_panel.total_paid` | Total Paid | إجمالي المدفوع |  |
| `order_panel.total_payable` | Total Payable | إجمالي المستحق |  |
| `pagination.next_page` | Next page | الصفحة التالية |  |
| `pagination.previous_page` | Previous page | الصفحة السابقة |  |
| `print.add_on_kot_printed_successfully` | Add-on KOT printed successfully! | تمت طباعة KOT الإضافي بنجاح! |  |
| `print.cancel_kot_printed_successfully` | Cancel KOT printed successfully! | تمت طباعة KOT الإلغاء بنجاح! |  |
| `print.daily_close_pdf_generated_successfully` | Daily Close PDF generated successfully! | تم إنشاء ملف PDF للإغلاق اليومي بنجاح! |  |
| `print.daily_close_print_failed` | Failed to print: @error | فشلت الطباعة: @error | @error |
| `print.development_print_saved` | Development print saved to @path | تم حفظ طباعة التطوير في @path | @path |
| `print.error_printing` | Error printing: @error | خطأ في الطباعة: @error | @error |
| `print.generating_daily_close_pdf` | Generating Daily Close PDF... | جارٍ إنشاء ملف PDF للإغلاق اليومي... |  |
| `print.generating_kot_pdf` | Generating KOT PDF... | جارٍ إنشاء ملف PDF لـ KOT... |  |
| `print.include_transaction_details_prompt` | Do you want to include transaction details in this print? | هل تريد تضمين تفاصيل المعاملة في هذه الطباعة؟ |  |
| `print.job_sent_successfully` | Print job sent successfully | تم إرسال مهمة الطباعة بنجاح |  |
| `print.kot_disabled` | KOT printing is disabled in document configuration. | طباعة KOT معطلة في إعدادات المستند. |  |
| `print.kot_pdf_generated_successfully` | KOT PDF generated successfully! | تم إنشاء ملف PDF لـ KOT بنجاح! |  |
| `print.kot_pdf_generation_failed` | Failed to generate KOT PDF: @error | فشل إنشاء ملف PDF لـ KOT: @error | @error |
| `print.kot_pdf_opened` | KOT PDF opened | تم فتح ملف PDF لـ KOT |  |
| `print.kot_pdf_shared` | KOT PDF shared | تمت مشاركة ملف PDF لـ KOT |  |
| `print.kot_print_failed` | Failed to print KOT: @error | فشلت طباعة KOT: @error | @error |
| `print.kot_printed_successfully` | KOT printed successfully! | تمت طباعة KOT بنجاح! |  |
| `print.pdf_generation_failed` | Error generating PDF: @error | خطأ في إنشاء ملف PDF: @error | @error |
| `print.pdf_opened` | PDF opened | تم فتح ملف PDF |  |
| `print.pdf_saved` | PDF saved: @path | تم حفظ ملف PDF: @path | @path |
| `print.pdf_saved_could_not_open` | PDF saved but could not be opened: @path | تم حفظ ملف PDF ولكن تعذر فتحه: @path | @path |
| `print.pdf_saved_could_not_share` | PDF saved but could not be shared: @path | تم حفظ ملف PDF ولكن تعذرت مشاركته: @path | @path |
| `print.pdf_shared` | PDF shared | تمت مشاركة ملف PDF |  |
| `print.print_daily_close` | Print Daily Close | طباعة الإغلاق اليومي |  |
| `print.print_dialog_opened` | Print dialog opened | تم فتح نافذة الطباعة |  |
| `print.print_report` | Print Report | طباعة التقرير |  |
| `printer_settings.bill_configuration_not_found` | Bill configuration not found | لم يتم العثور على إعدادات الفاتورة |  |
| `printer_settings.btn_resync` | Resync | إعادة المزامنة |  |
| `printer_settings.configure_bill_template` | Configure the Bill template in the Admin Panel, then Resync. | قم بإعداد قالب الفاتورة في لوحة الإدارة، ثم أعد المزامنة. |  |
| `printer_settings.empty` | Empty | فارغ |  |
| `printer_settings.exact_document_size_hint` | Enable only when the printer driver is configured for the exact document size. | فعّل هذا فقط عندما يكون برنامج تشغيل الطابعة مُعدًّا لحجم المستند الدقيق. |  |
| `printer_settings.field` | Field | الحقل |  |
| `printer_settings.field_reference` | Field reference | مرجع الحقول |  |
| `printer_settings.field_reference_subtitle` | Every synced label and what supplies its value | كل تسمية متزامنة ومصدر قيمتها |  |
| `printer_settings.live_preview` | Live preview | معاينة مباشرة |  |
| `printer_settings.live_preview_subtitle` | Render a sample receipt using the current settings | عرض إيصال نموذجي باستخدام الإعدادات الحالية |  |
| `printer_settings.not_supplied` | Not supplied | غير متوفر |  |
| `printer_settings.not_supplied_by_api` | Not supplied by API | غير متوفر من واجهة البرمجة |  |
| `printer_settings.preserve_pdf_size_hint` | Recommended for normal invoices because it preserves the PDF page size and helps prevent cropping. | موصى به للفواتير العادية لأنه يحافظ على حجم صفحة PDF ويساعد على منع الاقتصاص. |  |
| `printer_settings.press_resync_after_configuration` | Press Resync after configuring the document template. | اضغط على إعادة المزامنة بعد إعداد قالب المستند. |  |
| `printer_settings.preview_notice` | @theme is selected. This shared preview shows configured visibility and language using sample order data; the selected template's styling and spacing may differ. | تم اختيار @theme. تعرض هذه المعاينة المشتركة الظهور واللغة المُعدَّين باستخدام بيانات طلب نموذجية؛ وقد يختلف تنسيق القالب المحدد وتباعده. | @theme |
| `printer_settings.save_failed` | Could not save printer setting | تعذر حفظ إعداد الطابعة |  |
| `printer_settings.section_customer_description` | Customer, payment and delivery labels | تسميات العميل والدفع والتوصيل |  |
| `printer_settings.section_footer` | Footer | التذييل |  |
| `printer_settings.section_footer_description` | QR, tax footer and closing messages | رمز QR وتذييل الضريبة ورسائل الختام |  |
| `printer_settings.section_invoice` | Invoice | الفاتورة |  |
| `printer_settings.section_invoice_description` | Document title, number, date and token | عنوان المستند ورقمه وتاريخه والرمز |  |
| `printer_settings.section_items` | Items | العناصر |  |
| `printer_settings.section_items_description` | Item-table columns and line details | أعمدة جدول العناصر وتفاصيل السطور |  |
| `printer_settings.section_store_description` | Store identity and receipt heading | هوية المتجر وعنوان الإيصال |  |
| `printer_settings.section_totals` | Totals & bank | الإجماليات والبنك |  |
| `printer_settings.section_totals_description` | Calculated totals, balances and bank details | الإجماليات المحسوبة والأرصدة وتفاصيل البنك |  |
| `printer_settings.source` | Source | المصدر |  |
| `printer_settings.values_from_document_config` | Values come from Document Configuration. Edit them in the Admin Panel, then Resync. | القيم تأتي من إعدادات المستند. عدّلها في لوحة الإدارة، ثم أعد المزامنة. |  |
| `product.confirm_delete_item` | Are you sure you want to delete '@item'? | هل أنت متأكد أنك تريد حذف '@item'؟ | @item |
| `product.delete_item` | Delete Item | حذف العنصر |  |
| `product.delete_warning` | This action cannot be undone. | لا يمكن التراجع عن هذا الإجراء. |  |
| `product.overpaid` | Overpaid | مدفوع بالزيادة |  |
| `product.product` | Product | المنتج |  |
| `product.remaining` | Remaining | المتبقي |  |
| `product.sku_prefix` | SKU:  | رمز التخزين:  |  |
| `product.total_entered` | Total Entered | إجمالي المُدخل |  |
| `product_barcode.default_printer` | Barcode printer | طابعة الباركود |  |
| `product_barcode.invalid_barcode_for` | Invalid barcode for @product: @error | باركود غير صالح لـ @product: @error | @product @error |
| `product_barcode.no_quantity_to_print` | Nothing to print. Enter a quantity for at least one item. | لا يوجد شيء للطباعة. أدخل كمية لعنصر واحد على الأقل. |  |
| `product_barcode.no_stocks_selected` | No stocks selected to print. | لم يتم اختيار مخزون للطباعة. |  |
| `product_barcode.nothing_to_print` | Nothing to print | لا يوجد شيء للطباعة |  |
| `product_barcode.pdf_opened` | Barcode PDF opened | تم فتح ملف PDF للباركود |  |
| `product_barcode.pdf_shared` | PDF shared | تمت مشاركة ملف PDF |  |
| `product_barcode.printing_barcodes` | Printing barcodes... (PDF fallback enabled) | جارٍ طباعة الباركود... (تم تفعيل البديل PDF) |  |
| `product_barcode.sent_to_printer` | Sent to printer: @name | تم الإرسال إلى الطابعة: @name | @name |
| `product_barcode.stickers` | Barcode Stickers | ملصقات الباركود |  |
| `product_barcode.stickers_pdf` | Barcode Stickers PDF | ملف PDF لملصقات الباركود |  |
| `product_barcode.too_many_labels` | This job contains @count labels. Reduce it to 2000 or fewer. | تحتوي هذه المهمة على @count ملصق. قلّلها إلى 2000 أو أقل. | @count |
| `product_detail.add_value` | Add value | إضافة قيمة |  |
| `product_detail.barcode_generation_error` | Error generating barcode: | خطأ في إنشاء الباركود: |  |
| `product_detail.base_unit` | Base Unit | الوحدة الأساسية |  |
| `product_detail.enter_name_before_translating` | Please enter Category Name before translating. | يرجى إدخال اسم الفئة قبل الترجمة. |  |
| `product_detail.enter_name_in_language` | Enter name in @language | أدخل الاسم بـ @language | @language |
| `product_detail.enter_or_generate_barcode` | Enter or generate | أدخل أو أنشئ |  |
| `product_detail.expiry` | Expiry | تاريخ الانتهاء |  |
| `product_detail.item_code` | Item Code | رمز الصنف |  |
| `product_detail.localization` | Localization | الترجمة |  |
| `product_detail.no_other_languages` | No other languages available. | لا توجد لغات أخرى متاحة. |  |
| `product_detail.no_permission_view_details` | No permission to view product details | لا توجد صلاحية لعرض تفاصيل المنتج |  |
| `product_detail.product_fetch_error` | Error fetching product: | خطأ في جلب المنتج: |  |
| `product_detail.save_add_another` | Save & Add Another | حفظ وإضافة آخر |  |
| `product_detail.save_product` | Save Product | حفظ المنتج |  |
| `product_detail.scan_or_enter_barcode` | Scan or enter barcode | امسح أو أدخل الباركود |  |
| `product_detail.select_option` | Select option | اختر خيارًا |  |
| `product_detail.select_product_category` | Please select a Product Category. | يرجى اختيار فئة المنتج. |  |
| `product_detail.stock_id` | Stock ID | معرّف المخزون |  |
| `product_detail.translate_from_english` | Translate from English | الترجمة من الإنجليزية |  |
| `product_detail.type_value_enter` | Type value + Enter | اكتب القيمة ثم اضغط Enter |  |
| `product_detail.variants_and_stock` | Variants & Variant Stock | الأنواع ومخزون الأنواع |  |
| `product_form.localization` | Localization | الترجمة |  |
| `product_form.save_add_another` | Save & Add Another | حفظ وإضافة آخر |  |
| `product_form.save_product` | Save Product | حفظ المنتج |  |
| `product_form.select_product_category` | Please select a Product Category. | يرجى اختيار فئة المنتج. |  |
| `product_media.alt` | Alt | نص بديل |  |
| `product_media.attachment` | Attachment | مرفق |  |
| `product_media.file` | File | ملف |  |
| `product_media.is_primary` | Is Primary | أساسي |  |
| `product_media.title` | Title | العنوان |  |
| `product_sale_unit.remove_sale_unit` | Remove sale unit | إزالة وحدة البيع |  |
| `proforma_invoice.card_upi_not_allowed_together` | Card and UPI cannot be used together | لا يمكن استخدام البطاقة و UPI معًا |  |
| `proforma_invoice.price_below_minimum` | Price is below the minimum sale price of @price | السعر أقل من الحد الأدنى لسعر البيع @price | @price |
| `proforma_invoice.valid_quantity_required` | Enter a valid quantity | أدخل كمية صالحة |  |
| `purchase.permission_required_view_details` | Purchase permission is required to view details. | مطلوب صلاحية الشراء لعرض التفاصيل. |  |
| `purchase_order.selected_item` | Selected item | العنصر المحدد |  |
| `restaurant.error_mark_served` | Error marking items as served: @error | خطأ في تحديد العناصر كمُقدَّمة: @error | @error |
| `restaurant.failed_clear_cart` | Failed to clear cart: @error | فشل إفراغ السلة: @error | @error |
| `restaurant.failed_confirm_counter_order` | Failed to confirm counter order: @error | فشل تأكيد طلب الكاونتر: @error | @error |
| `restaurant.failed_confirm_order` | Failed to confirm order: @error | فشل تأكيد الطلب: @error | @error |
| `restaurant.failed_mark_served` | Failed to mark items as served: @message | فشل تحديد العناصر كمُقدَّمة: @message | @message |
| `restaurant.failed_print_bill` | Failed to print bill: @error | فشلت طباعة الفاتورة: @error | @error |
| `restaurant.failed_print_order_summary` | Failed to print order summary: @error | فشلت طباعة ملخص الطلب: @error | @error |
| `restaurant.failed_remove_item` | Failed to remove item: @error | فشلت إزالة العنصر: @error | @error |
| `restaurant.failed_save_local_draft` | Failed to save local draft: @error | فشل حفظ المسودة المحلية: @error | @error |
| `restaurant.failed_save_offline_order` | Failed to save offline order: @error | فشل حفظ الطلب دون اتصال: @error | @error |
| `restaurant.failed_update_cart_item` | Failed to update cart item: @error | فشل تحديث عنصر السلة: @error | @error |
| `restaurant.failed_update_quantity` | Failed to update quantity: @error | فشل تحديث الكمية: @error | @error |
| `restaurant.loading_menu_items` | Loading menu items... | جارٍ تحميل عناصر القائمة... |  |
| `restaurant.pdf_created_successfully` | PDF created successfully | تم إنشاء ملف PDF بنجاح |  |
| `restaurant.preparing_document` | Preparing @paperSize document for printing... | جارٍ تجهيز مستند @paperSize للطباعة... | @paperSize |
| `restaurant.saved_local_draft` | Saved local draft @orderNumber | تم حفظ المسودة المحلية @orderNumber | @orderNumber |
| `restaurant.view_order_items` | View @count items | عرض @count عناصر | @count |
| `sales.select_payment_method` | Please select a payment method | يرجى اختيار طريقة دفع |  |
| `sales.select_payment_status` | Please select a payment status | يرجى اختيار حالة الدفع |  |
| `sales.select_refund_payment_method` | Please select a refund payment method | يرجى اختيار طريقة دفع الاسترداد |  |
| `sales.valid_amount_minimum_zero` | Please enter a valid amount (minimum 0) | يرجى إدخال مبلغ صالح (الحد الأدنى 0) |  |
| `sales.valid_refund_amount` | Please enter a valid refund amount | يرجى إدخال مبلغ استرداد صالح |  |
| `sales_order_details.validator_email_invalid` | Enter a valid email address | أدخل عنوان بريد إلكتروني صالح |  |
| `sales_order_details.validator_phone_invalid` | Enter a valid phone number | أدخل رقم هاتف صالح |  |
| `sales_return.amount_in_words` | Amount in Words: | المبلغ كتابةً: |  |
| `sales_return.final_summary` | FINAL SUMMARY | الملخص النهائي |  |
| `sales_return.net_total` | Net Total | الإجمالي الصافي |  |
| `sales_return.return_summary` | RETURN SUMMARY | ملخص المرتجع |  |
| `sales_return.total_purchase` | Total Purchase | إجمالي الشراء |  |
| `sales_return.total_return` | Total Return | إجمالي المرتجع |  |
| `sales_return_form.cash` | Cash | نقدًا |  |
| `sales_return_form.enter_payment_amount` | Enter @method Amount | أدخل مبلغ @method | @method |
| `sales_return_form.expected` | Expected | المتوقع |  |
| `sales_return_form.upi` | UPI | UPI |  |
| `security_key.input_label` | 4-digit security key | مفتاح أمان مكون من 4 أرقام |  |
| `security_key.instruction` | Enter the 4-digit security key to @action. | أدخل مفتاح الأمان المكون من 4 أرقام لـ @action. | @action |
| `security_key.title` | Security Key Required | مطلوب مفتاح أمان |  |
| `share_helper.opt_send_whatsapp_to_number` | Send via WhatsApp to @phone | إرسال عبر واتساب إلى @phone | @phone |
| `share_helper.receipt_sent_via_whatsapp` | Receipt sent via WhatsApp to @phone | تم إرسال الإيصال عبر واتساب إلى @phone | @phone |
| `share_helper.share_to_email_with_address` | Share to Email (@email) | مشاركة عبر البريد الإلكتروني (@email) | @email |
| `share_helper.share_via_whatsapp_with_phone` | Share via WhatsApp (@phone) | مشاركة عبر واتساب (@phone) | @phone |
| `share_helper.supplier_voucher_sent_via_whatsapp` | Supplier Voucher sent via WhatsApp to @phone | تم إرسال سند المورد عبر واتساب إلى @phone | @phone |
| `share_helper.voucher_sent_via_whatsapp` | Voucher sent via WhatsApp to @phone | تم إرسال السند عبر واتساب إلى @phone | @phone |
| `share_helper.wa_connect_prompt` | WhatsApp bot is not connected. Would you like to connect now? ⏎  ⏎ Status: @status | روبوت واتساب غير متصل. هل تريد الاتصال الآن؟ ⏎  ⏎ الحالة: @status | @status |
| `stock.available_quantity_prefix` | Available Quantity:  | الكمية المتاحة:  |  |
| `stock.expiry_date_prefix` | Expiry Date:  | تاريخ الانتهاء:  |  |
| `stock.from_entries` | From @count stock entries | من @count إدخالات مخزون | @count |
| `stock.individual_details` | Individual Stock Details | تفاصيل المخزون الفردية |  |
| `stock.mrp_prefix` | MRP:  | السعر الأقصى للبيع:  |  |
| `stock.multiple_options_available` | Multiple Stock Options Available | تتوفر خيارات مخزون متعددة |  |
| `stock.price_prefix` | Price:  | السعر:  |  |
| `stock.product_prefix` | Product:  | المنتج:  |  |
| `stock.quantity_prefix` | Qty:  | الكمية:  |  |
| `stock.stock_id_prefix` | Stock ID:  | معرّف المخزون:  |  |
| `stock.update_failed` | Failed to update stock | فشل تحديث المخزون |  |
| `stock.updated_successfully` | Stock updated successfully | تم تحديث المخزون بنجاح |  |
| `supplier.search_supplier` | Search Supplier | البحث عن مورد |  |
| `supplier_details.numeric_keyboard` | Numeric Keyboard | لوحة مفاتيح رقمية |  |
| `supplier_details.please_wait` | Please wait... | يرجى الانتظار... |  |
| `supplier_details.sell_anyway` | Sell anyway | البيع على أي حال |  |
| `supplier_details.stock_mismatch` | Stock mismatch | عدم تطابق المخزون |  |
| `supplier_details.virtual_keyboard` | Virtual Keyboard | لوحة مفاتيح افتراضية |  |
| `supplier_transaction_report.print_supplier_transaction_report` | Print Supplier Transaction Report | طباعة تقرير معاملات المورد |  |
| `supplier_transaction_report.share_supplier_transaction_report` | Share Supplier Transaction Report | مشاركة تقرير معاملات المورد |  |
| `sync.no_internet_sync_tooltip` | No internet connection available for sync. | لا يوجد اتصال بالإنترنت للمزامنة. |  |
| `sync.offline_sync_tooltip` | Offline Mode is enabled. Disable it in Settings to sync. | وضع عدم الاتصال مُفعَّل. عطّله من الإعدادات للمزامنة. |  |
| `ui_chrome.select_print_option` | Select Print Option | اختر خيار الطباعة |  |
| `voucher_print.billing_address` | Billing Address | عنوان الفوترة |  |
| `voucher_print.customer_details` | Customer Details | تفاصيل العميل |  |
| `voucher_print.customer_title` | Print Customer Voucher | طباعة سند العميل |  |
| `voucher_print.customer_voucher_printed` | Customer Voucher printed successfully | تمت طباعة سند العميل بنجاح |  |
| `voucher_print.document_config_missing` | Document configurations not loaded. Please wait. | لم يتم تحميل إعدادات المستند. يرجى الانتظار. |  |
| `voucher_print.document_config_not_loaded` | Document configuration not loaded. Please wait or try again. | لم يتم تحميل إعدادات المستند. يرجى الانتظار أو المحاولة مرة أخرى. |  |
| `voucher_print.document_config_not_loaded_retry` | Document configuration not loaded. Please try again. | لم يتم تحميل إعدادات المستند. يرجى المحاولة مرة أخرى. |  |
| `voucher_print.dummy_thermal_receipt` | Dummy Thermal Receipt | إيصال حراري تجريبي |  |
| `voucher_print.error_generating_pdf` | Error generating PDF: @error | خطأ في إنشاء ملف PDF: @error | @error |
| `voucher_print.error_generating_pdf_for_sharing` | Error generating PDF for sharing | خطأ في إنشاء ملف PDF للمشاركة |  |
| `voucher_print.error_loading_document_config` | Error loading document configurations: @error | خطأ في تحميل إعدادات المستند: @error | @error |
| `voucher_print.error_printing` | Error printing: @error | خطأ في الطباعة: @error | @error |
| `voucher_print.error_sharing_pdf` | Error sharing PDF: @error | خطأ في مشاركة ملف PDF: @error | @error |
| `voucher_print.have_a_great_day` | Have a great day! | نتمنى لك يومًا سعيدًا! |  |
| `voucher_print.item` | Item | الصنف |  |
| `voucher_print.load_document_config_failed` | Failed to load document configuration | فشل تحميل إعدادات المستند |  |
| `voucher_print.loading_document_config` | Loading document configuration... | جارٍ تحميل إعدادات المستند... |  |
| `voucher_print.loading_printer_config` | Loading printer and configuration... | جارٍ تحميل الطابعة والإعدادات... |  |
| `voucher_print.name` | Name | الاسم |  |
| `voucher_print.pdf_created_successfully` | PDF created successfully | تم إنشاء ملف PDF بنجاح |  |
| `voucher_print.pdf_opened_for_printing` | PDF opened for printing | تم فتح ملف PDF للطباعة |  |
| `voucher_print.pdf_shared_open_to_print` | PDF shared. Please open it to print | تمت مشاركة ملف PDF. يرجى فتحه للطباعة |  |
| `voucher_print.preparing_document` | Preparing @paperSize document for printing... | جارٍ تجهيز مستند @paperSize للطباعة... | @paperSize |
| `voucher_print.preparing_return_document` | Preparing @paperSize Return Bill document for printing... | جارٍ تجهيز مستند فاتورة المرتجع @paperSize للطباعة... | @paperSize |
| `voucher_print.print_job_sent` | Print job sent successfully | تم إرسال مهمة الطباعة بنجاح |  |
| `voucher_print.print_receipt` | Print Receipt | طباعة الإيصال |  |
| `voucher_print.print_return_bill` | Print Return Bill | طباعة فاتورة المرتجع |  |
| `voucher_print.printer_selected` | @name Printer Selected | تم اختيار طابعة @name | @name |
| `voucher_print.report_sent_to` | Report sent to @printer | تم إرسال التقرير إلى @printer | @printer |
| `voucher_print.return_bill_pdf_generated` | Return Bill PDF generated successfully | تم إنشاء ملف PDF لفاتورة المرتجع بنجاح |  |
| `voucher_print.return_bill_printed` | Return Bill printed successfully | تمت طباعة فاتورة المرتجع بنجاح |  |
| `voucher_print.scan` | Scan | بحث |  |
| `voucher_print.scan_for_printers` | Scan for printers | البحث عن الطابعات |  |
| `voucher_print.scan_printers` | Scan Printers | البحث عن الطابعات |  |
| `voucher_print.select` | Select | اختر |  |
| `voucher_print.select_printer` | Select Printer | اختر الطابعة |  |
| `voucher_print.supplier_details` | Supplier Details | تفاصيل المورد |  |
| `voucher_print.supplier_title` | Print Supplier Voucher | طباعة سند المورد |  |
| `voucher_print.supplier_voucher_printed` | Supplier Voucher printed successfully | تمت طباعة سند المورد بنجاح |  |
| `voucher_print.tap_refresh_to_scan` | Tap the refresh button to scan for printers | اضغط على زر التحديث للبحث عن الطابعات |  |
| `voucher_print.thank_you_purchase` | Thank you for your purchase! | شكرًا لشرائك! |  |
| `voucher_print.voucher_number` | Voucher # | رقم السند |  |
| `voucher_print.voucher_sent_to_printer` | Voucher sent to @printer | تم إرسال السند إلى @printer | @printer |

### Copied from an existing translation of the same English string

| Key | English | Arabic | Placeholders |
|---|---|---|---|
| `add_customer.validator_phone_required` | Phone number is required | رقم الهاتف مطلوب |  |
| `billing.add` | Add | إضافة |  |
| `billing.apply` | Apply | تطبيق |  |
| `billing.auth_token_missing` | Authentication token not found. | لم يتم العثور على رمز المصادقة. |  |
| `billing.auth_token_missing_login` | Authentication token not found. Please log in again. | لم يتم العثور على رمز المصادقة. الرجاء تسجيل الدخول مرة أخرى. |  |
| `billing.barcode_generated` | Barcode generated | تم إنشاء الباركود |  |
| `billing.barcode_generated_unique` | Barcode generated and incremented to keep it unique | تم إنشاء الباركود وزيادته للحفاظ على تفرده |  |
| `billing.barcode_generation_failed` | Failed to generate barcode | فشل إنشاء الباركود |  |
| `billing.barcode_product_not_found` | Product with barcode "@barcode" not found | لم يتم العثور على منتج بالباركود "@barcode" | @barcode |
| `billing.base_unit_required` | Base unit is required before adding additional sale units. | الوحدة الأساسية مطلوبة قبل إضافة وحدات بيع إضافية. |  |
| `billing.edit_permission_denied` | You do not have permission to edit this product. | ليس لديك إذن لتعديل هذا المنتج. |  |
| `billing.edit_stock` | Edit Stock | تعديل المخزون |  |
| `billing.enter_paid_amount` | Enter Paid Amount Here: | أدخل المبلغ المدفوع هنا: |  |
| `billing.enter_value` | Enter @label | أدخل @label | @label |
| `billing.error_multi_sale_disabled` | Multi sale units are disabled for this store. | وحدات البيع المتعدد معطلة لهذا المتجر. |  |
| `billing.font_prefix` | Font:  | الخط:  |  |
| `billing.keyboard_shortcuts` | Keyboard Shortcuts (Ctrl+H) | اختصارات لوحة المفاتيح (Ctrl+H) |  |
| `billing.multi_sale_unit` | Multi Sale Unit | وحدة بيع متعددة |  |
| `billing.no_stock_information` | No stock information available | لا توجد معلومات مخزون متاحة |  |
| `billing.order_no` | Order No | رقم الطلب |  |
| `billing.payable` | Payable | المبلغ المستحق |  |
| `billing.payment_breakdown` | Payment Breakdown | تفصيل الدفعات |  |
| `billing.payment_method` | Payment Method | طريقة الدفع |  |
| `billing.price` | Price | السعر |  |
| `billing.quotation_create_failed` | Failed to create quotation | فشل إنشاء الفاتورة |  |
| `billing.quotation_print_details_failed` | Quotation created, but details could not be loaded for printing. | تم إنشاء الفاتورة، لكن لم يتمكن من تحميل التفاصيل للطباعة. |  |
| `billing.quotation_print_missing_id` | Quotation created, but print failed because the API response did not include quotation id. | تم إنشاء الفاتورة، لكن فشلت الطباعة لأن استجابة API لم تتضمن معرف الفاتورة. |  |
| `billing.reference_number` | Reference number | رقم المرجع |  |
| `billing.removed_from_cart` | Removed From Cart | تمت الإزالة من السلة |  |
| `billing.required` | Required | مطلوب |  |
| `billing.sale_unit` | Sale Unit | وحدة البيع |  |
| `billing.sale_unit_index` | Sale Unit @n | وحدة البيع @n | @n |
| `billing.section_order_items` | Order Items | عناصر الطلب |  |
| `billing.select_unit_first` | Select the product unit first to activate this section. | اختر وحدة المنتج أولاً لتفعيل هذا القسم. |  |
| `billing.stock_id_missing_edit` | Stock id missing. Unable to edit this row. | معرف المخزون مفقود. لا يمكن تعديل هذا الصف. |  |
| `billing.sync_failed` | Sync failed | فشلت المزامنة |  |
| `billing.tax_percent` | Tax % | الضريبة % |  |
| `billing.total_items` | Total Items | إجمالي العناصر |  |
| `billing.total_purchase_amount` | Total Purchase Amount | إجمالي مبلغ الشراء |  |
| `billing.total_quantity` | Total Quantity | إجمالي الكمية |  |
| `billing.transaction_reference_no` | Transaction Reference No: | رقم مرجع المعاملة: |  |
| `calendar.one_month` | 1 Month | شهر واحد |  |
| `calendar.one_year` | 1 Year | سنة واحدة |  |
| `calendar.six_months` | 6 Months | 6 أشهر |  |
| `calendar.three_months` | 3 Months | 3 أشهر |  |
| `cancel_order_modal.delivery_charge_refundable` | Delivery Charge Refundable | رسوم التوصيل قابلة للاسترداد |  |
| `cancel_order_modal.delivery_charge_refundable_hint` | Turn off to exclude the delivery charge from the refund. | أوقف التشغيل لاستبعاد رسوم التوصيل من المبلغ المُسترد. |  |
| `cancel_order_modal.title` | Cancel Order | إلغاء الطلب |  |
| `category.description` | Description | الوصف |  |
| `category.no_taxes_available` | No taxes available | لا توجد ضرائب متاحة |  |
| `category.slug` | Slug | الرابط المختصر |  |
| `category.translated_to` | Translated to @language | تمت الترجمة إلى @language | @language |
| `category.translation_failed` | Translation failed. Please try again. | فشلت الترجمة. حاول مرة أخرى. |  |
| `change_order_status.delivery_charge_refundable` | Delivery Charge Refundable | رسوم التوصيل قابلة للاسترداد |  |
| `change_order_status.status` | Status | الحالة |  |
| `change_payment_status.amount` | Amount | المبلغ |  |
| `change_payment_status.status` | Status | الحالة |  |
| `checkout_modal.msg_saved_customer_required` | Create or select a saved customer before confirming | يرجى إنشاء أو تحديد عميل محفوظ قبل التأكيد |  |
| `common.district_city` | District / City | المنطقة / المدينة |  |
| `common.search_district` | Search District... | ابحث عن المقاطعة... |  |
| `common.search_state` | Search State... | ابحث عن المنطقة... |  |
| `common.select_district` | Select District | اختر المنطقة |  |
| `common.select_payment_type` | Please select a payment type | يرجى تحديد نوع الدفع |  |
| `common.select_state` | Select State | اختر المنطقة |  |
| `company_admin.payment_card` | Card | بطاقة |  |
| `company_admin.payment_methods` | Payment Methods | طرق الدفع |  |
| `company_admin.quick_actions` | Quick Actions | إجراءات سريعة |  |
| `company_admin.recent_transactions` | Recent Transactions | المعاملات الأخيرة |  |
| `company_admin.reports` | Reports | التقارير |  |
| `company_admin.settings` | Settings | الإعدادات |  |
| `company_admin.top_products` | Top Products | أهم المنتجات |  |
| `confirmed_orders.select_payment_method` | Select Payment Method | اختر طريقة الدفع |  |
| `coupon.empty_cart` | Cannot apply discount to empty cart | لا يمكن تطبيق الخصم على سلة فارغة |  |
| `coupon.flat_discount` | Flat Discount | خصم ثابت |  |
| `coupon.flat_discount_exceeds_total` | Flat discount cannot exceed cart total | لا يمكن للخصم الثابت أن يتجاوز إجمالي السلة |  |
| `coupon.percentage_discount_max` | Percentage discount cannot exceed 100% | لا يمكن أن يتجاوز الخصم النسبي 100% |  |
| `customer.district_city` | District / City | المنطقة / المدينة |  |
| `customer.hint_no_districts` | No districts available | لا توجد مناطق متاحة |  |
| `customer.hint_no_pincodes` | No pincodes available | لا توجد رموز بريدية متاحة |  |
| `customer.hint_select_district` | Select District | اختر المنطقة |  |
| `customer.hint_select_district_first` | Select District First | اختر المقاطعة أولاً |  |
| `customer.hint_select_pincode` | Select Pincode | اختر الرمز البريدي |  |
| `customer.hint_select_state` | Select State | اختر المنطقة |  |
| `customer.hint_select_state_first` | Select State First | اختر المنطقة أولاً |  |
| `customer.hint_street_address` | Street name, area, locality | اسم الشارع، المنطقة، المحلية |  |
| `customer.label_district` | District / City | المنطقة / المدينة |  |
| `customer.label_pincode` | Pincode | الرمز البريدي |  |
| `customer.search_district` | Search District... | ابحث عن المقاطعة... |  |
| `customer.search_state` | Search State... | ابحث عن المنطقة... |  |
| `customer.select_district` | Select District | اختر المنطقة |  |
| `customer.select_payment_type` | Please select a payment type | يرجى تحديد نوع الدفع |  |
| `customer.select_state` | Select State | اختر المنطقة |  |
| `daily_sales_close.amount` | Amount | المبلغ |  |
| `daily_sales_close.order_items` | Order Items | عناصر الطلب |  |
| `daily_sales_close.particulars` | Particulars | التفاصيل |  |
| `daily_sales_close.payment_breakdown` | Payment Breakdown | تفصيل الدفعات |  |
| `daily_sales_close.qty` | Qty | الكمية |  |
| `daily_sales_close.rate` | Rate | السعر |  |
| `daily_sales_close.table` | Table | طاولة |  |
| `daily_sales_close.total` | Total | الإجمالي |  |
| `daily_sales_close.transactions` | Transactions | المعاملات |  |
| `daily_sales_close.type` | Type | النوع |  |
| `dining.available` | Available | متوفر |  |
| `dining.no_tables_available` | No tables available | لا توجد طاولات متاحة |  |
| `general.apply` | Apply | تطبيق |  |
| `general.auth_token_missing` | Authentication token is missing | رمز المصادقة مفقود |  |
| `general.back` | Back | رجوع |  |
| `general.card` | Card | بطاقة |  |
| `general.clear` | Clear | مسح |  |
| `general.clear_all` | Clear all | مسح الكل |  |
| `general.confirm` | Confirm | تأكيد |  |
| `general.date` | Date | التاريخ |  |
| `general.delete` | Delete | حذف |  |
| `general.done` | Done | تم |  |
| `general.fill_required_fields` | Please fill all required fields correctly | الرجاء تعبئة جميع الحقول المطلوبة بشكل صحيح |  |
| `general.image_title` | Image Title | عنوان الصورة |  |
| `general.new_order` | New Order | طلب جديد |  |
| `general.next` | Next | التالي |  |
| `general.no_items_found` | No items found | لا توجد عناصر |  |
| `general.no_payment_methods_available` | No payment methods available | لا توجد طرق دفع متاحة |  |
| `general.not_available` | Not available | غير متاح |  |
| `general.order_no` | Order No | رقم الطلب |  |
| `general.order_number_hash` | Order # | رقم الطلب |  |
| `general.password` | Password | كلمة المرور |  |
| `general.preview` | Preview | معاينة |  |
| `general.previous` | Previous | السابق |  |
| `general.product_name` | Product Name | اسم المنتج |  |
| `general.quantity_short` | Qty | الكمية |  |
| `general.remove` | Remove | إزالة |  |
| `general.required` | Required | مطلوب |  |
| `general.search` | Search | بحث |  |
| `general.select_icon` | Select Icon | اختر أيقونة |  |
| `general.select_image` | Select Image | اختر صورة |  |
| `general.select_payment_method` | Select Payment Method | اختر طريقة الدفع |  |
| `general.submit` | Submit | إرسال |  |
| `general.sync_failed` | Sync failed | فشلت المزامنة |  |
| `general.total` | Total | الإجمالي |  |
| `general.translate` | Translate | ترجمة |  |
| `general.unknown_error_occurred` | An unknown error occurred | حدث خطأ غير معروف |  |
| `general.unknown_product` | Unknown Product | منتج غير معروف |  |
| `general.update` | Update | تحديث |  |
| `general.valid_price_required` | Enter a valid price | أدخل سعراً صحيحاً |  |
| `general.view_details` | View details | عرض التفاصيل |  |
| `invoice.adjust_search` | Try adjusting your search criteria | حاول تعديل معايير البحث |  |
| `invoice.create` | Create | إنشاء |  |
| `invoice.filters` | Filters | الفلاتر |  |
| `invoice.invoice_no` | Invoice No | رقم الفاتورة |  |
| `invoice.mobile_list_title` | Invoice List | قائمة الفواتير |  |
| `invoice.number_copied` | Invoice number copied to clipboard | تم نسخ رقم الفاتورة إلى الحافظة |  |
| `invoice.phone` | Phone | الهاتف |  |
| `invoice.search_email_hint` | Email | البريد الإلكتروني |  |
| `invoice.sync_all` | Sync ALL | مزامنة الكل |  |
| `invoice.sync_failed` | Sync Failed | مزامنة الفاشلة |  |
| `invoice.sync_selected` | Sync Selected | مزامنة المحددة |  |
| `invoice_pdf.customer_id` | Customer ID | معرّف العميل |  |
| `invoice_pdf.email` | Email | البريد الإلكتروني |  |
| `invoice_pdf.item_name` | Item Name | اسم العنصر |  |
| `invoice_pdf.order_date` | Order Date | تاريخ الطلب |  |
| `invoice_pdf.order_details` | Order Details | تفاصيل الطلب |  |
| `invoice_pdf.order_number` | Order Number | رقم الطلب |  |
| `invoice_pdf.order_status` | Order Status | حالة الطلب |  |
| `invoice_pdf.payment_status` | Payment Status | حالة الدفع |  |
| `invoice_pdf.phone` | Phone | الهاتف |  |
| `invoice_pdf.quantity` | Quantity | الكمية |  |
| `invoice_pdf.store_id` | Store ID | معرّف المتجر |  |
| `invoice_pdf.subtotal` | Subtotal | المجموع الفرعي |  |
| `invoice_pdf.tax` | Tax | الضريبة |  |
| `invoice_pdf.total_price` | Total Price | السعر الإجمالي |  |
| `invoice_pdf.unit_price` | Unit Price | سعر الوحدة |  |
| `keyboard.hide` | Hide | إخفاء |  |
| `nav.orders` | Orders | الطلبات |  |
| `nav.section_reports` | Reports | التقارير |  |
| `nav.section_sales` | Sales | المبيعات |  |
| `nav.section_settings` | Settings | الإعدادات |  |
| `order_panel.confirm` | Confirm | تأكيد |  |
| `order_panel.edit_order` | Edit Order | تعديل الطلب |  |
| `order_panel.no_orders_found` | No orders found | لا توجد طلبات |  |
| `order_panel.print_kot` | Print KOT | طباعة أمر المطبخ |  |
| `order_panel.save_and_print` | Save & Print | حفظ وطباعة |  |
| `order_panel.tax` | Tax | الضريبة |  |
| `print.daily_close_printed_successfully` | Daily Close Report printed successfully! | تم طباعة تقرير إغلاق اليوم بنجاح! |  |
| `print.print_kot` | Print KOT | طباعة أمر المطبخ |  |
| `printer_settings.arabic` | Arabic | العربية |  |
| `printer_settings.english` | English | الإنجليزية |  |
| `printer_settings.section_customer` | Customer | العميل |  |
| `printer_settings.section_store` | Store | المتجر |  |
| `product_detail.add_new_product` | Add New Product | إضافة منتج جديد |  |
| `product_detail.advanced` | Advanced | متقدم |  |
| `product_detail.auth_token_missing` | Authentication token not found. Please log in again. | لم يتم العثور على رمز المصادقة. الرجاء تسجيل الدخول مرة أخرى. |  |
| `product_detail.auth_token_missing_login` | Authentication token not found. Please log in again. | لم يتم العثور على رمز المصادقة. الرجاء تسجيل الدخول مرة أخرى. |  |
| `product_detail.barcode_generated_unique` | Barcode generated and incremented to keep it unique | تم إنشاء الباركود وزيادته للحفاظ على تفرده |  |
| `product_detail.barcode_generation_failed` | Failed to generate barcode | فشل إنشاء الباركود |  |
| `product_detail.barcode_product_not_found` | Product with barcode "@barcode" not found | لم يتم العثور على منتج بالباركود "@barcode" | @barcode |
| `product_detail.base_conversion_rate_must_be_positive` | Base unit conversion rate must be greater than 0. | يجب أن يكون معدل تحويل الوحدة الأساسية أكبر من 0. |  |
| `product_detail.base_conversion_rate_required` | Base unit conversion rate is required. | معدل تحويل الوحدة الأساسية مطلوب. |  |
| `product_detail.base_unit_required` | Base unit is required before adding additional sale units. | الوحدة الأساسية مطلوبة قبل إضافة وحدات بيع إضافية. |  |
| `product_detail.basic_information` | Basic Information | المعلومات الأساسية |  |
| `product_detail.continue_btn` | Continue | متابعة |  |
| `product_detail.conversion_rate` | Conversion Rate | معدل التحويل |  |
| `product_detail.duplicate_barcode_title` | Duplicate Barcode Found | تم العثور على باركود مكرر |  |
| `product_detail.edit_permission_denied` | You do not have permission to edit this product. | ليس لديك إذن لتعديل هذا المنتج. |  |
| `product_detail.error_adding_product` | Error adding product: @error | خطأ في إضافة المنتج: @error | @error |
| `product_detail.error_generating_barcode` | Error generating barcode: @error | خطأ في إنشاء الباركود: @error | @error |
| `product_detail.fill_required_fields` | Please fill all required fields correctly | الرجاء تعبئة جميع الحقول المطلوبة بشكل صحيح |  |
| `product_detail.inactive` | Inactive | غير نشط |  |
| `product_detail.max_sale_price_mrp` | Max Sale Price / MRP | أقصى سعر بيع / السعر الأقصى للبيع بالتجزئة |  |
| `product_detail.multi_sale_unit` | Multi Sale Unit | وحدة بيع متعددة |  |
| `product_detail.no_product_found_barcode` | No product found with barcode @barcode | لم يتم العثور على منتج بالباركود @barcode | @barcode |
| `product_detail.no_stock_information` | No stock information available | لا توجد معلومات مخزون متاحة |  |
| `product_detail.other_language_names` | Other Language Names | أسماء بلغات أخرى |  |
| `product_detail.product_added_success` | Product added successfully | تمت إضافة المنتج بنجاح |  |
| `product_detail.product_name_hint` | e.g. Premium Coffee Beans | اسم المنتج |  |
| `product_detail.product_unit` | Product Unit | وحدة المنتج |  |
| `product_detail.sale_unit` | Sale Unit | وحدة البيع |  |
| `product_detail.sale_unit_index` | Sale Unit @n | وحدة البيع @n | @n |
| `product_detail.select_product_copy_hint` | Select a product to copy its details into the form. | اختر منتجًا لنسخ تفاصيله إلى النموذج. |  |
| `product_detail.select_unit_first` | Select the product unit first to activate this section. | اختر وحدة المنتج أولاً لتفعيل هذا القسم. |  |
| `product_detail.selected` | Selected | محدد |  |
| `product_detail.selling_price` | Selling Price | سعر البيع |  |
| `product_detail.stock_id_missing_edit` | Stock id missing. Unable to edit this row. | معرف المخزون مفقود. لا يمكن تعديل هذا الصف. |  |
| `product_detail.view_details` | View details | عرض التفاصيل |  |
| `product_form.add_new_product` | Add New Product | إضافة منتج جديد |  |
| `product_form.auth_token_missing_login` | Authentication token not found. Please log in again. | لم يتم العثور على رمز المصادقة. الرجاء تسجيل الدخول مرة أخرى. |  |
| `product_form.basic_information` | Basic Information | المعلومات الأساسية |  |
| `proforma_invoice.clear_all` | Clear all | مسح الكل |  |
| `proforma_invoice.no_payment_methods_available` | No payment methods available | لا توجد طرق دفع متاحة |  |
| `proforma_invoice.product_name` | Product Name | اسم المنتج |  |
| `proforma_invoice.valid_price_required` | Enter a valid price | أدخل سعراً صحيحاً |  |
| `sales.error_preparing_return` | Error preparing order return. Please try again. | خطأ في تجهيز إرجاع الطلب. يرجى المحاولة مرة أخرى. |  |
| `sales_order_details.validator_phone_required` | Phone number is required | رقم الهاتف مطلوب |  |
| `sales_return.total_items` | Total Items | إجمالي العناصر |  |
| `sales_return.total_mrp` | Total MRP | إجمالي السعر المقترح |  |
| `sales_return_form.card` | Card | بطاقة |  |
| `share_helper.error_generating_pdf` | Error generating PDF. Please try again. | خطأ أثناء إنشاء الـ PDF. يرجى المحاولة مرة أخرى. |  |
| `share_helper.error_generating_receipt_pdf` | Error generating Receipt PDF. Please try again. | خطأ أثناء إنشاء ملف PDF للإيصال. يرجى المحاولة مرة أخرى. |  |
| `share_helper.failed_generate_pdf_whatsapp` | Failed to generate PDF for WhatsApp. | فشل إنشاء ملف PDF لواتساب. |  |
| `share_helper.failed_send_whatsapp` | Failed to send WhatsApp message: @error | فشل إرسال رسالة واتساب: @error | @error |
| `share_helper.invoice_sent_via_whatsapp` | Invoice sent via WhatsApp to @phone | تم إرسال الفاتورة عبر واتساب إلى @phone | @phone |
| `share_helper.receipt_pdf_shared` | Receipt PDF shared successfully! | تمت مشاركة ملف PDF للإيصال بنجاح! |  |
| `share_helper.share_invoice` | Share Invoice | مشاركة الفاتورة |  |
| `share_helper.share_receipt` | Share Receipt | مشاركة الإيصال |  |
| `share_helper.share_supplier_voucher` | Share Supplier Voucher | مشاركة قسيمة المورد |  |
| `share_helper.share_to_email` | Share to Email | مشاركة عبر البريد الإلكتروني |  |
| `share_helper.share_via_whatsapp` | Share via WhatsApp | مشاركة عبر واتساب |  |
| `share_helper.share_voucher` | Share Voucher | مشاركة القسيمة |  |
| `share_helper.supplier_phone_empty` | Supplier phone number is empty. | رقم هاتف المورد فارغ. |  |
| `share_helper.supplier_voucher_pdf_shared` | Supplier Voucher PDF shared successfully! | تمت مشاركة ملف PDF لقسيمة المورد بنجاح! |  |
| `share_helper.voucher_pdf_shared` | Voucher PDF shared successfully! | تمت مشاركة ملف PDF للقسيمة بنجاح! |  |
| `stock.edit_stock` | Edit Stock | تعديل المخزون |  |
| `stock.enter_value` | Enter @label | أدخل @label | @label |
| `stock.items_count` | @count items | @count عناصر | @count |
| `stock.no_products_found` | No products found | لم يتم العثور على منتجات |  |
| `stock.stock_prefix` | Stock | المخزون |  |
| `supplier_details.no_items_found` | No items found | لا توجد عناصر |  |
| `supplier_details.search` | Search... | بحث... |  |
| `voucher_print.amount` | Amount | المبلغ |  |
| `voucher_print.available_printers` | Available Printers | الطابعات المتاحة |  |
| `voucher_print.customer_information` | Customer Information | معلومات العميل |  |
| `voucher_print.customer_name` | Customer Name | اسم العميل |  |
| `voucher_print.date` | Date | التاريخ |  |
| `voucher_print.due_date` | Due Date | تاريخ الاستحقاق |  |
| `voucher_print.email` | Email | البريد الإلكتروني |  |
| `voucher_print.info_devices_found` | @count devices found | @count أجهزة تم العثور عليها | @count |
| `voucher_print.no_printers_found` | No printers found | لا توجد طابعات |  |
| `voucher_print.not_available` | Not available | غير متاح |  |
| `voucher_print.paper_size` | Paper Size | حجم الورق |  |
| `voucher_print.payment` | Payment | الدفع |  |
| `voucher_print.phone` | Phone | الهاتف |  |
| `voucher_print.printer_permissions_required` | This app needs Bluetooth and Location permissions to scan for printers. | يحتاج هذا التطبيق إلى أذونات Bluetooth والموقع للبحث عن الطابعات. |  |
| `voucher_print.printing` | Printing... | جاري الطباعة... |  |
| `voucher_print.qty` | Qty | الكمية |  |
| `voucher_print.scanning` | Scanning... | جارٍ البحث... |  |
| `voucher_print.select_printer_first` | Please select a printer first | يرجى اختيار طابعة أولاً |  |
| `voucher_print.selected` | Selected | محدد |  |
| `voucher_print.status` | Status | الحالة |  |
| `voucher_print.supplier_information` | Supplier Information | معلومات المورد |  |
| `voucher_print.unknown_device` | Unknown device | جهاز غير معروف |  |

## Malayalam (`ml.json`) — 259 added, 2 changed

- **55 newly translated** — written during this work. **These are the ones that need review.**
- **108 copied** from the translation this locale already used for the identical English string. Lower risk, but worth a skim for context: a word that fits one screen may not fit another.
- **96 recovered** — existing translations that were already in the file but unreachable, because a duplicate of their namespace shadowed them. Not new work; listed only for completeness.

### Changed (existing strings replaced)

| Key | English | Was | Now | Placeholders |
|---|---|---|---|---|
| `product_detail.status_out_of_stock` | Out of Stock |   സ്റ്റോക്ക് | സ്റ്റോക്ക് തീർന്നു |  |
| `stock.status_out_of_stock` | Out of Stock |   സ്റ്റോക്ക് | സ്റ്റോക്ക് തീർന്നു |  |

### Newly translated — needs review

| Key | English | Malayalam | Placeholders |
|---|---|---|---|
| `add_customer.validator_email_invalid` | Enter a valid email address | സാധുവായ ഇമെയിൽ വിലാസം നൽകുക |  |
| `billing.new_order_reset` | New order started | പുതിയ ഓർഡർ ആരംഭിച്ചു |  |
| `billing.warranty_accept_hint` | The customer accepts the warranty terms for this item | ഈ ഇനത്തിന്റെ വാറന്റി വ്യവസ്ഥകൾ ഉപഭോക്താവ് അംഗീകരിക്കുന്നു |  |
| `billing.warranty_condition` | Warranty condition: @condition | വാറന്റി വ്യവസ്ഥ: @condition | @condition |
| `common.no_store_selected` | No store selected | സ്റ്റോർ തിരഞ്ഞെടുത്തിട്ടില്ല |  |
| `common.select_payment_type` | Please select a payment type | ദയവായി ഒരു പേയ്‌മെന്റ് തരം തിരഞ്ഞെടുക്കുക |  |
| `confirmed_orders.select_payment_method` | Select Payment Method | പേയ്മെന്റ് രീതി തിരഞ്ഞെടുക്കുക |  |
| `customer.label_states` | States / Provinces | സംസ്ഥാനങ്ങൾ / പ്രവിശ്യകൾ |  |
| `customer.payment_type` | Payment Type | പേയ്‌മെന്റ് തരം |  |
| `customer.search_district` | Search District... | ജില്ല തിരയുക... |  |
| `customer.search_state` | Search State... | സംസ്ഥാനം തിരയുക... |  |
| `customer.select_payment_type` | Please select a payment type | ദയവായി ഒരു പേയ്‌മെന്റ് തരം തിരഞ്ഞെടുക്കുക |  |
| `customer.states_provinces` | States / Provinces | സംസ്ഥാനങ്ങൾ / പ്രവിശ്യകൾ |  |
| `customer.to_pay` | To Pay | നൽകാനുള്ളത് |  |
| `customer.to_receive` | To Receive | ലഭിക്കാനുള്ളത് |  |
| `dining.available_soon` | Available soon | ഉടൻ ലഭ്യമാകും |  |
| `dining.filled` | Filled | നിറഞ്ഞു |  |
| `dining.indoor` | Indoor | ഇൻഡോർ |  |
| `dining.outdoor` | Outdoor | ഔട്ട്ഡോർ |  |
| `dining.reserved` | Reserved | റിസർവ് ചെയ്തു |  |
| `dining.table_list` | Table List | ടേബിൾ പട്ടിക |  |
| `general.clear_all` | Clear all | എല്ലാം മായ്ക്കുക |  |
| `general.error_occurred_try_again` | Error Occurred! Try Again | പിശക് സംഭവിച്ചു! വീണ്ടും ശ്രമിക്കുക |  |
| `general.no_payment_methods_available` | No payment methods available | പേയ്‌മെന്റ് രീതികളൊന്നും ലഭ്യമല്ല |  |
| `general.product_name` | Product Name | ഉൽപ്പന്നത്തിന്റെ പേര് |  |
| `general.select_payment_method` | Select Payment Method | പേയ്‌മെന്റ് രീതി തിരഞ്ഞെടുക്കുക |  |
| `general.show_less` | Show less | കുറച്ച് കാണിക്കുക |  |
| `general.show_more_items` | Show @count more | @count എണ്ണം കൂടി കാണിക്കുക | @count |
| `general.sync_failed` | Sync failed | സമന്വയം പരാജയപ്പെട്ടു |  |
| `keyboard.show` | Show | കാണിക്കുക |  |
| `pagination.next_page` | Next page | അടുത്ത പേജ് |  |
| `pagination.previous_page` | Previous page | മുമ്പത്തെ പേജ് |  |
| `product.confirm_delete_item` | Are you sure you want to delete '@item'? | '@item' ഇല്ലാതാക്കണമെന്ന് ഉറപ്പാണോ? | @item |
| `product.delete_item` | Delete Item | ഇനം ഇല്ലാതാക്കുക |  |
| `product.delete_warning` | This action cannot be undone. | ഈ പ്രവർത്തനം പഴയപടിയാക്കാൻ കഴിയില്ല. |  |
| `product.overpaid` | Overpaid | അധികം അടച്ചത് |  |
| `product.remaining` | Remaining | ബാക്കി |  |
| `product.total_entered` | Total Entered | നൽകിയ ആകെ തുക |  |
| `product_detail.barcode_generated_unique` | Barcode generated and incremented to keep it unique | ബാർകോഡ് സൃഷ്ടിച്ചു, അതുല്യമായി നിലനിർത്താൻ വർധിപ്പിച്ചു |  |
| `product_detail.barcode_generation_failed` | Failed to generate barcode | ബാർകോഡ് സൃഷ്ടിക്കുന്നതിൽ പരാജയപ്പെട്ടു |  |
| `product_detail.barcode_product_not_found` | Product with barcode "@barcode" not found | "@barcode" ബാർകോഡുള്ള ഉൽപ്പന്നം കണ്ടെത്തിയില്ല | @barcode |
| `product_detail.base_unit_required` | Base unit is required before adding additional sale units. | അധിക വിൽപ്പന യൂണിറ്റുകൾ ചേർക്കുന്നതിന് മുമ്പ് അടിസ്ഥാന യൂണിറ്റ് ആവശ്യമാണ്. |  |
| `product_detail.basic_information` | Basic Information | അടിസ്ഥാന വിവരങ്ങൾ |  |
| `product_detail.edit_permission_denied` | You do not have permission to edit this product. | ഈ ഉൽപ്പന്നം എഡിറ്റ് ചെയ്യാൻ നിങ്ങൾക്ക് അനുമതിയില്ല. |  |
| `product_detail.no_stock_information` | No stock information available | സ്റ്റോക്ക് വിവരങ്ങളൊന്നും ലഭ്യമല്ല |  |
| `product_detail.sale_unit` | Sale Unit | വിൽപ്പന യൂണിറ്റ് |  |
| `product_detail.sale_unit_index` | Sale Unit @n | വിൽപ്പന യൂണിറ്റ് @n | @n |
| `product_detail.select_unit_first` | Select the product unit first to activate this section. | ഈ വിഭാഗം സജീവമാക്കാൻ ആദ്യം ഉൽപ്പന്ന യൂണിറ്റ് തിരഞ്ഞെടുക്കുക. |  |
| `product_detail.stock_id_missing_edit` | Stock id missing. Unable to edit this row. | സ്റ്റോക്ക് ഐഡി ലഭ്യമല്ല. ഈ വരി എഡിറ്റ് ചെയ്യാൻ കഴിയില്ല. |  |
| `restaurant.loading_menu_items` | Loading menu items... | മെനു ഇനങ്ങൾ ലോഡ് ചെയ്യുന്നു... |  |
| `restaurant.pdf_created_successfully` | PDF created successfully | PDF വിജയകരമായി സൃഷ്ടിച്ചു |  |
| `restaurant.preparing_document` | Preparing @paperSize document for printing... | പ്രിന്റിംഗിനായി @paperSize ഡോക്യുമെന്റ് തയ്യാറാക്കുന്നു... | @paperSize |
| `restaurant.view_order_items` | View @count items | @count ഇനങ്ങൾ കാണുക | @count |
| `stock.edit_stock` | Edit Stock | സ്റ്റോക്ക് എഡിറ്റ് ചെയ്യുക |  |
| `voucher_print.load_document_config_failed` | Failed to load document configuration | ഡോക്യുമെന്റ് കോൺഫിഗറേഷൻ ലോഡ് ചെയ്യുന്നതിൽ പരാജയപ്പെട്ടു |  |

### Copied from an existing translation of the same English string

| Key | English | Malayalam | Placeholders |
|---|---|---|---|
| `add_customer.validator_phone_invalid` | Enter a valid phone number | ശരിയായ ഫോൺ നമ്പർ നൽകുക |  |
| `add_customer.validator_phone_required` | Phone number is required | ഫോൺ നമ്പർ നിർബന്ധമാണ് |  |
| `billing.balance_amount` | Balance Amount | ബാലൻസ് തുക |  |
| `billing.clear_cart_failed` | Failed to clear cart. Please try again. | ക്ലിയർ കാർട്ട്. വീണ്ടും ശ്രമിക്കുക. പരാജയപ്പെട്ടു |  |
| `billing.pine_labs_payment_successful` | Pine Labs payment successful | Pine Labs പേയ്‌മെന്റ് വിജയകരമായി പൂർത്തിയായി |  |
| `billing.removed_from_cart` | Removed From Cart | കാർട്ടിൽ നിന്ന് നീക്കി |  |
| `billing.section_order_items` | Order Items | ഓർഡർ ഇനങ്ങൾ |  |
| `category.product_property_number` | Product Property must be a number. | പ്രോഡക്റ്റ് പ്രോപ്പർട്ടി ഒരു സംഖ്യയായിരിക്കണം. |  |
| `company_admin.payment_methods` | Payment Methods | പേയ്‌മെന്റ് രീതികൾ |  |
| `customer.district_city` | District / City | ജില്ല / നഗരം |  |
| `customer.hint_no_districts` | No districts available | ജില്ലകൾ ലഭ്യമല്ല |  |
| `customer.hint_no_pincodes` | No pincodes available | പിൻകോഡുകൾ ലഭ്യമല്ല |  |
| `customer.hint_select_district` | Select District | ജില്ല തിരഞ്ഞെടുക്കുക |  |
| `customer.hint_select_district_first` | Select District First | ജില്ല ആദ്യം തിരഞ്ഞെടുക്കുക |  |
| `customer.hint_select_pincode` | Select Pincode | പിൻകോഡ് തിരഞ്ഞെടുക്കുക |  |
| `customer.hint_select_state` | Select State | സംസ്ഥാനം തിരഞ്ഞെടുക്കുക |  |
| `customer.hint_select_state_first` | Select State First | സംസ്ഥാനം ആദ്യം തിരഞ്ഞെടുക്കുക |  |
| `customer.hint_street_address` | Street name, area, locality | സ്ട്രീറ്റ് പേര്, ഏരിയ, പ്രദേശം |  |
| `customer.label_district` | District / City | ജില്ല / നഗരം |  |
| `customer.label_pincode` | Pincode | പിൻകോഡ് |  |
| `customer.select_district` | Select District | ജില്ല തിരഞ്ഞെടുക്കുക |  |
| `customer.select_state` | Select State | സംസ്ഥാനം തിരഞ്ഞെടുക്കുക |  |
| `daily_sales_close.order_items` | Order Items | ഓർഡർ ഇനങ്ങൾ |  |
| `dining.available` | Available | ലഭ്യം |  |
| `dining.no_tables_available` | No tables available | ടേബിളുകൾ ലഭ്യമല്ല |  |
| `general.action` | Action | ആക്ഷൻ |  |
| `general.card` | Card | കാർഡ് |  |
| `general.card_upi_not_allowed_together` | Card and UPI cannot be used together | കാർഡും UPIയും ഒരുമിച്ച് ഉപയോഗിക്കാൻ കഴിയില്ല |  |
| `general.cash` | Cash | ക്യാഷ് |  |
| `general.confirm_delete_item` | Are you sure you want to delete '@item'? | '@item' ഇല്ലാതാക്കണമെന്ന് ഉറപ്പാണോ? | @item |
| `general.customer_prefix` | Customer:  | കസ്റ്റമർ:  |  |
| `general.data_synced_successfully` | Data synced successfully! | ഡാറ്റ വിജയകരമായി സിങ്ക് ചെയ്തു! |  |
| `general.delete` | Delete | ഡിലീറ്റ് |  |
| `general.delete_item` | Delete Item | ഇനം ഇല്ലാതാക്കുക |  |
| `general.delete_warning` | This action cannot be undone. | ഈ പ്രവർത്തനം പഴയപടിയാക്കാൻ കഴിയില്ല. |  |
| `general.done` | Done | പൂർത്തിയായി |  |
| `general.enter_mobile_number` | Enter mobile number | മൊബൈൽ നമ്പർ നൽകുക |  |
| `general.enter_payment_amount` | Enter @method Amount | @method തുക നൽകുക | @method |
| `general.expected` | Expected | പ്രതീക്ഷിക്കുന്നത് |  |
| `general.failed` | Failed | പരാജയം |  |
| `general.fill_required_fields` | Please fill all required fields correctly |  പൂരിപ്പിക്കുക എല്ലാ ആവശ്യമായ ഫീൽഡുകൾ ശരിയായി |  |
| `general.new_order` | New Order | പുതിയ ഓർഡർ |  |
| `general.no_items_found` | No items found | ഇനങ്ങൾ കണ്ടെത്തിയില്ല |  |
| `general.not_available` | Not available | ലഭ്യമല്ല |  |
| `general.numeric_keyboard` | Numeric Keyboard | സംഖ്യാ കീബോർഡ് |  |
| `general.optional` | Optional | ഓപ്ഷണൽ |  |
| `general.order_no` | Order No | ഓർഡർ നമ്പർ |  |
| `general.overpaid` | Overpaid | അധികം അടച്ചത് |  |
| `general.please_wait` | Please wait... | ദയവായി കാത്തിരിക്കുക... |  |
| `general.previous` | Previous | മുമ്പത്തേത് |  |
| `general.price_below_minimum` | Price is below the minimum sale price of @price | വില കുറഞ്ഞത് @price-നേക്കാൾ കുറവാണ് | @price |
| `general.product_prefix` | Product:  | ഉൽപ്പന്നം:  |  |
| `general.quantity_prefix` | Qty:  | അളവ്:  |  |
| `general.remaining` | Remaining | ബാക്കി |  |
| `general.search` | Search | തിരയുക |  |
| `general.sell_anyway` | Sell anyway | എന്തായാലും വിൽക്കുക |  |
| `general.stock_mismatch` | Stock mismatch | സ്റ്റോക്ക് പൊരുത്തക്കേട് |  |
| `general.submit` | Submit | സമർപ്പിക്കുക |  |
| `general.total` | Total | ആകെ |  |
| `general.total_entered` | Total Entered | നൽകിയ ആകെ തുക |  |
| `general.upi` | UPI | UPI |  |
| `general.valid_price_required` | Enter a valid price | ശരിയായ വില നൽകുക |  |
| `general.valid_quantity_required` | Enter a valid quantity | ശരിയായ അളവ് നൽകുക |  |
| `general.view_details` | View details | വിവരങ്ങൾ കാണുക |  |
| `general.virtual_keyboard` | Virtual Keyboard | വെർച്വൽ കീബോർഡ് |  |
| `general.yes_print` | Yes, print | അതെ, പ്രിന്റ് ചെയ്യുക |  |
| `keyboard.hide` | Hide | മറയ്ക്ക് |  |
| `product_barcode.pdf_shared` | PDF shared | PDF പങ്കിട്ടു |  |
| `product_detail.add_new_product` | Add New Product | പുതിയ ഉൽപ്പന്നം ചേർക്കുക |  |
| `product_detail.advanced` | Advanced | അഡ്വാൻസ്ഡ് |  |
| `product_detail.auth_token_missing` | Authentication token not found. Please log in again. | ഓതന്റിക്കേഷൻ ടോക്കൺ കണ്ടെത്തിയില്ല. വീണ്ടും ലോഗിൻ ചെയ്യുക. |  |
| `product_detail.auth_token_missing_login` | Authentication token not found. Please log in again. | ഓതന്റിക്കേഷൻ ടോക്കൺ കണ്ടെത്തിയില്ല. വീണ്ടും ലോഗിൻ ചെയ്യുക. |  |
| `product_detail.barcode_generation_error` | Error generating barcode: | ബാർകോഡ് സൃഷ്ടിക്കുന്നതിൽ പിഴവ്: |  |
| `product_detail.base_conversion_rate_must_be_positive` | Base unit conversion rate must be greater than 0. | ബേസ് യൂണിറ്റ് കൺവേർഷൻ നിരക്ക് കൂടുതൽ 0. |  |
| `product_detail.base_conversion_rate_required` | Base unit conversion rate is required. | ബേസ് യൂണിറ്റ് കൺവേർഷൻ നിരക്ക് നിർബന്ധം. |  |
| `product_detail.base_unit` | Base Unit | ബേസ് യൂണിറ്റ് |  |
| `product_detail.continue_btn` | Continue | തുടരുക |  |
| `product_detail.conversion_rate` | Conversion Rate | കൺവേർഷൻ നിരക്ക് |  |
| `product_detail.duplicate_barcode_title` | Duplicate Barcode Found | ഡ്യൂപ്ലിക്കേറ്റ് ബാർകോഡ് കണ്ടെത്തി |  |
| `product_detail.enter_name_before_translating` | Please enter Category Name before translating. | വിവർത്തനം ചെയ്യുന്നതിന് മുമ്പ് വിഭാഗത്തിന്റെ പേര് നൽകുക. |  |
| `product_detail.enter_name_in_language` | Enter name in @language | @language ഭാഷയിൽ പേര് നൽകുക | @language |
| `product_detail.enter_or_generate_barcode` | Enter or generate | നൽകുക അല്ലെങ്കിൽ സൃഷ്ടിക്കുക |  |
| `product_detail.error_adding_product` | Error adding product: @error | പിഴവ്: ചേർക്കുന്നു ഉൽപ്പന്നം: @error | @error |
| `product_detail.error_generating_barcode` | Error generating barcode: @error | പിഴവ്: ജനറേറ്റ് ചെയ്യുന്നു ബാർകോഡ്: @error | @error |
| `product_detail.fill_required_fields` | Please fill all required fields correctly |  പൂരിപ്പിക്കുക എല്ലാ ആവശ്യമായ ഫീൽഡുകൾ ശരിയായി |  |
| `product_detail.item_code` | Item Code | ഐറ്റം കോഡ് |  |
| `product_detail.localization` | Localization | ലോക്കലൈസേഷൻ |  |
| `product_detail.max_sale_price_mrp` | Max Sale Price / MRP | പരമാവധി സെയിൽ വില / MRP |  |
| `product_detail.multi_sale_unit` | Multi Sale Unit | മൾട്ടി സെയിൽ യൂണിറ്റ് |  |
| `product_detail.no_other_languages` | No other languages available. | മറ്റ് ഭാഷകൾ ലഭ്യമല്ല. |  |
| `product_detail.no_permission_view_details` | No permission to view product details | ഉൽപ്പന്ന വിശദാംശങ്ങൾ കാണാൻ അനുമതിയില്ല |  |
| `product_detail.no_product_found_barcode` | No product found with barcode @barcode | ഉൽപ്പന്നം കണ്ടെത്തി സഹിതം ബാർകോഡ് @barcode ഇല്ല | @barcode |
| `product_detail.other_language_names` | Other Language Names | മറ്റുള്ളവ ഭാഷ പേരുകൾ |  |
| `product_detail.product_added_success` | Product added successfully | ഉൽപ്പന്നം ചേർത്തു |  |
| `product_detail.product_fetch_error` | Error fetching product: | ഉൽപ്പന്നം ലഭ്യമാക്കുന്നതിൽ പിഴവ്: |  |
| `product_detail.product_name_hint` | e.g. Premium Coffee Beans | ഉദാ. പ്രീമിയം കോഫി ബീൻസ് |  |
| `product_detail.product_unit` | Product Unit | ഉൽപ്പന്നം യൂണിറ്റ് |  |
| `product_detail.save_add_another` | Save & Add Another | സേവ് ചെയ്ത് മറ്റൊന്ന് ചേർക്കുക |  |
| `product_detail.save_product` | Save Product | ഉൽപ്പന്നം സേവ് ചെയ്യുക |  |
| `product_detail.scan_or_enter_barcode` | Scan or enter barcode | ബാർകോഡ് സ്കാൻ ചെയ്യുക അല്ലെങ്കിൽ നൽകുക |  |
| `product_detail.select_product_category` | Please select a Product Category. | ഒരു ഉൽപ്പന്ന വിഭാഗം തിരഞ്ഞെടുക്കുക. |  |
| `product_detail.select_product_copy_hint` | Select a product to copy its details into the form. | ഉൽപ്പന്നം പകർത്തുക വിവരങ്ങൾ ഫോം. തിരഞ്ഞെടുക്കുക |  |
| `product_detail.selling_price` | Selling Price | വിൽക്കുന്ന വില |  |
| `product_detail.translate_from_english` | Translate from English | ഇംഗ്ലീഷിൽ നിന്ന് വിവർത്തനം ചെയ്യുക |  |
| `product_detail.view_details` | View details | വിവരങ്ങൾ കാണുക |  |
| `stock.enter_value` | Enter @label | @label നൽകുക | @label |
| `stock.no_products_found` | No products found | ഉൽപ്പന്നങ്ങൾ കണ്ടെത്തിയില്ല |  |
| `stock.stock_prefix` | Stock | സ്റ്റോക്ക് |  |

### Recovered from a shadowed namespace (pre-existing copy)

| Key | English | Malayalam | Placeholders |
|---|---|---|---|
| `category.category_icon` | Category Icon: | വിഭാഗം ഐക്കൺ: |  |
| `category.category_image` | Category Image: | വിഭാഗം ചിത്രം: |  |
| `category.enter_name_before_translating` | Please enter Category Name before translating. | വിവർത്തനം ചെയ്യുന്നതിന് മുമ്പ് വിഭാഗത്തിന്റെ പേര് നൽകുക. |  |
| `category.no_taxes_available` | No taxes available | ടാക്സുകൾ ലഭ്യമല്ല |  |
| `category.parent_category` | Parent Category | പാരന്റ് വിഭാഗം |  |
| `category.select_parent_optional` | Select Parent Category (optional) | പാരന്റ് വിഭാഗം തിരഞ്ഞെടുക്കുക (ഓപ്ഷണൽ) |  |
| `category.translated_to` | Translated to @language | @language ലേക്ക് വിവർത്തനം ചെയ്തു | @language |
| `category.translation_failed` | Translation failed. Please try again. | വിവർത്തനം പരാജയപ്പെട്ടു. വീണ്ടും ശ്രമിക്കുക. |  |
| `common.confirm_location` | Confirm Location | ലൊക്കേഷൻ സ്ഥിരീകരിക്കുക |  |
| `common.district_city` | District / City | ജില്ല / നഗരം |  |
| `common.items_count` | (@count) items | (@count) ഇനങ്ങൾ | @count |
| `common.loading_map_picker` | Loading map picker... | മാപ്പ് പിക്കർ ലോഡ് ചെയ്യുന്നു... |  |
| `common.location_picker_asset_missing` | Error: Location picker asset template missing. | പിഴവ്: ലൊക്കേഷൻ പിക്കർ അസറ്റ് ടെംപ്ലേറ്റ് ലഭ്യമല്ല. |  |
| `common.no_location_selected` | No location selected yet. Search an address or tap/drag the map pin. | ലൊക്കേഷൻ ഇതുവരെ തിരഞ്ഞെടുത്തിട്ടില്ല. വിലാസം തിരയുക അല്ലെങ്കിൽ മാപ്പിലെ പിൻ ടാപ്പ്/വലിച്ചുനീക്കുക. |  |
| `common.pick_customer_location` | Pick Customer Location | കസ്റ്റമറുടെ ലൊക്കേഷൻ തിരഞ്ഞെടുക്കുക |  |
| `common.search_customer` | Search customer... | കസ്റ്റമറെ തിരയുക... |  |
| `common.search_district` | Search District... | ജില്ല തിരയുക... |  |
| `common.search_state` | Search State... | സംസ്ഥാനം തിരയുക... |  |
| `common.select_district` | Select District | ജില്ല തിരഞ്ഞെടുക്കുക |  |
| `common.select_state` | Select State | സംസ്ഥാനം തിരഞ്ഞെടുക്കുക |  |
| `common.states_provinces` | States / Provinces | സംസ്ഥാനങ്ങൾ / പ്രവിശ്യകൾ |  |
| `confirmed_orders.applied_discounts` | Applied Discounts | പ്രയോഗിച്ച ഡിസ്കൗണ്ടുകൾ |  |
| `confirmed_orders.auth_token_not_found` | Authentication token not found. Please login again. | ഓതന്റിക്കേഷൻ ടോക്കൺ കണ്ടെത്തിയില്ല. വീണ്ടും ലോഗിൻ ചെയ്യുക. |  |
| `confirmed_orders.balance_amount` | Balance Amount | ബാലൻസ് തുക |  |
| `confirmed_orders.car_number` | Car Number | കാർ നമ്പർ |  |
| `confirmed_orders.close` | Close | അടയ്ക്കുക |  |
| `confirmed_orders.comment` | Comment | കമന്റ് |  |
| `confirmed_orders.completed_orders` | Completed @current out of @total | പൂർത്തിയായി @current @total | @current @total |
| `confirmed_orders.coupon_code` | Coupon Code | കൂപ്പൺ കോഡ് |  |
| `confirmed_orders.credit_applied` | Credit Applied | ക്രെഡിറ്റ് പ്രയോഗിച്ചു |  |
| `confirmed_orders.customer_phone` | Customer Phone | കസ്റ്റമർ ഫോൺ |  |
| `confirmed_orders.delete` | Delete | ഡിലീറ്റ് |  |
| `confirmed_orders.delete_message` | This confirmed order will be permanently removed from your local storage. This action cannot be undone. | ഈ കൺഫേം ചെയ്തു ഓർഡർ സ്ഥിരമായി നീക്കി ൽ നിന്ന് നിങ്ങളുടെ ലോക്കൽ സ്റ്റോറേജ്. ഈ ആക്ഷൻ സാധ്യമല്ല തിരികെയാക്കാൻ കഴിയില്ല. |  |
| `confirmed_orders.delete_success` | Confirmed order deleted successfully | കൺഫേം ചെയ്തു ഓർഡർ ഡിലീറ്റ് ചെയ്തു |  |
| `confirmed_orders.delete_title` | Delete Confirmed Order | ഡിലീറ്റ് കൺഫേം ചെയ്തു ഓർഡർ |  |
| `confirmed_orders.delivery_date` | Delivery Date | ഡെലിവറി തീയതി |  |
| `confirmed_orders.delivery_date_prefix` | Delivery Date:  | ഡെലിവറി തീയതി:  |  |
| `confirmed_orders.delivery_method` | Delivery Method | ഡെലിവറി രീതി |  |
| `confirmed_orders.delivery_time` | Delivery Time | ഡെലിവറി സമയം |  |
| `confirmed_orders.delivery_time_prefix` | Delivery Time:  | ഡെലിവറി സമയം:  |  |
| `confirmed_orders.discount_applied` | Discount Applied | ഡിസ്കൗണ്ട് പ്രയോഗിച്ചു |  |
| `confirmed_orders.failed_print` | Failed to print order. Please try again. | പ്രിന്റ് ഓർഡർ. വീണ്ടും ശ്രമിക്കുക. പരാജയപ്പെട്ടു |  |
| `confirmed_orders.flat_discount` | Flat Discount | ഫ്ലാറ്റ് ഡിസ്കൗണ്ട് |  |
| `confirmed_orders.items_prefix` | Items:  | ഇനങ്ങൾ:  |  |
| `confirmed_orders.method` | Method | രീതി |  |
| `confirmed_orders.msg_order_deleted` | Order @number deleted | ഓർഡർ @number ഡിലീറ്റ് ചെയ്തു | @number |
| `confirmed_orders.msg_printing_order` | Printing order @number... | പ്രിന്റ് ചെയ്യുന്നു ഓർഡർ @number... | @number |
| `confirmed_orders.na` | N/A | N/A |  |
| `confirmed_orders.no_orders_found` | No confirmed orders found | കൺഫേം ചെയ്തു ഓർഡറുകൾ കണ്ടെത്തിയില്ല |  |
| `confirmed_orders.no_orders_to_sync` | No confirmed orders to sync | കൺഫേം ചെയ്തു ഓർഡറുകൾ സിങ്ക് ഇല്ല |  |
| `confirmed_orders.order_info` | Order Information | ഓർഡർ വിവരം |  |
| `confirmed_orders.order_items` | Order Items | ഓർഡർ ഇനങ്ങൾ |  |
| `confirmed_orders.order_status` | Order Status | ഓർഡർ സ്റ്റാറ്റസ് |  |
| `confirmed_orders.payment_display` | @name Payment | @name പേയ്‌മെന്റ് | @name |
| `confirmed_orders.payment_hash` | Payment #@id | പേയ്‌മെന്റ് #@id | @id |
| `confirmed_orders.payment_method` | Payment Method | പേയ്‌മെന്റ് രീതി |  |
| `confirmed_orders.percentage_discount` | Percentage Discount | ശതമാനം ഡിസ്കൗണ്ട് |  |
| `confirmed_orders.print_order` | Print Order | ഓർഡർ പ്രിന്റ് |  |
| `confirmed_orders.product` | Product | ഉൽപ്പന്നം |  |
| `confirmed_orders.quantity_prefix` | Qty:  | അളവ്:  |  |
| `confirmed_orders.saving_orders` | Saving @current out of @total | സേവ് ചെയ്യുന്നു @current @total | @current @total |
| `confirmed_orders.subtitle` | Manage and track your confirmed orders | നിങ്ങളുടെ കൺഫേം ചെയ്ത ഓർഡറുകൾ നിയന്ത്രിക്കുകയും ട്രാക്ക് ചെയ്യുകയും ചെയ്യുക |  |
| `confirmed_orders.sync_btn` | Sync with Database | സിങ്ക് സഹിതം ഡാറ്റാബേസ് |  |
| `confirmed_orders.sync_failed_part` | , @count failed | , @count പരാജയം | @count |
| `confirmed_orders.sync_success` | Synced @count orders successfully | സിങ്ക് ചെയ്തു @count ഓർഡറുകൾ വിജയകരമായി | @count |
| `confirmed_orders.sync_wait` | Please wait while we sync your data. | നിങ്ങളുടെ ഡാറ്റ സിങ്ക് ചെയ്യുമ്പോൾ കാത്തിരിക്കുക... |  |
| `confirmed_orders.syncing_title` | Syncing Orders | സിങ്ക് ചെയ്യുന്നു ഓർഡറുകൾ |  |
| `confirmed_orders.time` | Time | സമയം |  |
| `confirmed_orders.title` | Confirmed Orders | കൺഫേം ചെയ്തു ഓർഡറുകൾ |  |
| `confirmed_orders.total_amount` | Total Amount | ആകെ തുക |  |
| `confirmed_orders.total_mrp` | Total MRP | ആകെ MRP |  |
| `confirmed_orders.transaction_id` | Transaction ID | ട്രാൻസാക്ഷൻ ഐഡി |  |
| `confirmed_orders.uploading_orders` | Uploading @count confirmed orders to the server. Please wait... | അപ്‌ലോഡ് ചെയ്യുന്നു @count കൺഫേം ചെയ്തു ഓർഡറുകൾ സെർവർ. കാത്തിരിക്കുക... | @count |
| `confirmed_orders.yes` | Yes | ഉണ്ട് |  |
| `confirmed_orders.you_saved` | You Saved | നിങ്ങൾ ലാഭിച്ചത് |  |
| `nav.section_accounts` | Accounts | അക്കൗണ്ടുകൾ |  |
| `nav.section_directory` | Directory | ഡയറക്ടറി |  |
| `nav.section_inventory` | Inventory | ഇൻവെന്ററി |  |
| `nav.section_main` | Main | പ്രധാന വിഭാഗം |  |
| `nav.section_reports` | Reports | റിപ്പോർട്ടുകൾ |  |
| `nav.section_sales` | Sales | വിൽപ്പന |  |
| `nav.section_settings` | Settings | ക്രമീകരണങ്ങൾ |  |
| `product_sale_unit.remove_sale_unit` | Remove sale unit | വിൽപ്പന യൂണിറ്റ് നീക്കം ചെയ്യുക |  |
| `stock.available_quantity_prefix` | Available Quantity:  | ലഭ്യമായ അളവ്:  |  |
| `stock.expiry_date_prefix` | Expiry Date:  | കാലാവധി തീയതി:  |  |
| `stock.from_entries` | From @count stock entries | @count സ്റ്റോക്ക് എൻട്രികളിൽ നിന്ന് | @count |
| `stock.individual_details` | Individual Stock Details | വ്യക്തിഗത സ്റ്റോക്ക് വിവരങ്ങൾ |  |
| `stock.items_count` | @count items | @count ഇനങ്ങൾ | @count |
| `stock.mrp_prefix` | MRP:  | MRP:  |  |
| `stock.multiple_options_available` | Multiple Stock Options Available | ഒന്നിലധികം സ്റ്റോക്ക് ഓപ്ഷനുകൾ ലഭ്യമാണ് |  |
| `stock.price_prefix` | Price:  | വില:  |  |
| `stock.product_prefix` | Product:  | ഉൽപ്പന്നം:  |  |
| `stock.quantity_prefix` | Qty:  | അളവ്:  |  |
| `stock.stock_id_prefix` | Stock ID:  | സ്റ്റോക്ക് ഐഡി:  |  |
| `stock.update_failed` | Failed to update stock | സ്റ്റോക്ക് അപ്‌ഡേറ്റ് ചെയ്യുന്നത് പരാജയപ്പെട്ടു |  |
| `stock.updated_successfully` | Stock updated successfully | സ്റ്റോക്ക് വിജയകരമായി അപ്‌ഡേറ്റ് ചെയ്തു |  |


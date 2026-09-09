import 'localization_service.dart';

/// Built-in recovery copy remains readable even before translation assets load.
String recoveryText(String text) =>
    LocalizationService.locale.languageCode == 'ar'
        ? (_arabic[text] ?? text)
        : text;

const _arabic = <String, String>{
  'Restart CloudPOS': 'إعادة تشغيل CloudPOS',
  'Restarting CloudPOS…': 'جارٍ إعادة تشغيل CloudPOS…',
  'Could not restart CloudPOS. Close it and open it again.':
      'تعذّرت إعادة تشغيل CloudPOS. أغلق التطبيق وافتحه مجددًا.',
  'Order confirmation wasn’t received. You can retry. The earlier attempt is saved in Sales → Orders to review.':
      'لم يصل تأكيد الطلب. يمكنك إعادة المحاولة. المحاولة السابقة محفوظة في المبيعات ← طلبات تحتاج إلى مراجعة.',
  'Remove review log': 'حذف سجل المراجعة',
  'Remove this log from this device? This does not delete or cancel the order in the admin panel. Remove it only after checking the order.':
      'هل تريد حذف هذا السجل من الجهاز؟ هذا لا يحذف الطلب أو يلغيه في لوحة الإدارة. احذفه فقط بعد التحقق من الطلب.',
  'Could not remove the log. Please try again.':
      'تعذّر حذف السجل. يرجى المحاولة مجددًا.',
  'Retrying may create a duplicate order. Compare these attempts with the admin panel and cancel any duplicate orders there.':
      'قد تؤدي إعادة المحاولة إلى إنشاء طلب مكرر. قارن هذه المحاولات بلوحة الإدارة وألغِ أي طلبات مكررة هناك.',
  'You can keep billing or retry an unconfirmed sale. Retrying may create duplicates. Compare these attempts with the admin panel.':
      'يمكنك متابعة البيع أو إعادة محاولة بيع غير مؤكد. قد تنشئ إعادة المحاولة طلبات مكررة. قارن هذه المحاولات بلوحة الإدارة.',
  'Order details': 'تفاصيل الطلب',
  'Review details': 'مراجعة التفاصيل',
  'Item': 'الصنف',
  'Items': 'الأصناف',
  'Qty': 'الكمية',
  'Unit price': 'سعر الوحدة',
  'No saved items.': 'لا توجد أصناف محفوظة.',
  'You can keep billing other customers. Check these orders before creating the same sale again.':
      'يمكنك متابعة البيع لعملاء آخرين. تحقّق من هذه الطلبات قبل إنشاء عملية البيع نفسها مجددًا.',
  'New orders that need checking will appear here.':
      'ستظهر هنا الطلبات الجديدة التي تحتاج إلى مراجعة.',
  'Orders to review': 'طلبات تحتاج إلى مراجعة',
  'Review': 'مراجعة',
  'Dismiss': 'إخفاء',
  'Order saved for review. You can start a new sale.':
      'حُفظ الطلب للمراجعة. يمكنك بدء عملية بيع جديدة.',
  'Start new sale': 'بدء عملية بيع جديدة',
  'Confirmation not received': 'لم يصل تأكيد الطلب',
  'No orders need review.': 'لا توجد طلبات تحتاج إلى مراجعة.',
  'These orders need checking. You can continue billing other customers. Do not create the same sale again until its result is verified.':
      'هذه الطلبات تحتاج إلى مراجعة. يمكنك متابعة البيع لعملاء آخرين. لا تنشئ عملية البيع نفسها مجددًا حتى يتم التحقق من نتيجتها.',
  'Keep this attempt in Orders to review and open an empty cart for your next customer? The previous order will not be sent again.':
      'هل تريد الاحتفاظ بهذه المحاولة في الطلبات التي تحتاج إلى مراجعة وفتح سلة فارغة للعميل التالي؟ لن يُرسَل الطلب السابق مجددًا.',
  'Could not prepare a new cart. Check local storage before continuing.':
      'تعذّر تجهيز سلة جديدة. تحقّق من التخزين المحلي قبل المتابعة.',
  'We haven’t received confirmation yet. This order may already be saved. Check its status before creating it again.':
      'لم نتلقَّ تأكيدًا بعد. قد يكون الطلب محفوظًا بالفعل. تحقّق من حالته قبل إنشائه مجددًا.',
  'An order is already being confirmed.': 'يجري تأكيد طلب بالفعل.',
  'An earlier order was confirmed. Review it before billing again.':
      'تم تأكيد طلب سابق. راجعه قبل إصدار فاتورة جديدة.',
  'We couldn’t save this order on your device. Nothing was sent. Check local storage before trying again.':
      'تعذّر حفظ الطلب على جهازك. لم يتم إرسال أي شيء. تحقّق من التخزين المحلي قبل المحاولة مجددًا.',
  'Order recovery data could not be loaded. Nothing was sent. Restart CloudPOS.':
      'تعذّر تحميل بيانات استعادة الطلب. لم يتم إرسال أي شيء. أعد تشغيل CloudPOS.',
  'The order was confirmed, but its local record could not be updated.':
      'تم تأكيد الطلب، لكن تعذّر تحديث سجله المحلي.',
  'The order was confirmed. Local cleanup needs attention; do not bill it again.':
      'تم تأكيد الطلب. يلزم مراجعة البيانات المحلية؛ لا تصدر فاتورته مجددًا.',
  'Time': 'الوقت',
  'Total': 'الإجمالي',
  'Details for support': 'تفاصيل للدعم',
  'Opening CloudPOS…': 'جارٍ فتح CloudPOS…',
  'Preparing CloudPOS…': 'جارٍ تجهيز CloudPOS…',
  'Getting your counter ready…': 'جارٍ تجهيز نقطة البيع…',
  'Still getting ready…': 'لا يزال التجهيز جاريًا…',
  'Opening your saved data…': 'جارٍ فتح بياناتك المحفوظة…',
  'Loading products and saved orders…':
      'جارٍ تحميل المنتجات والطلبات المحفوظة…',
  'Loading language settings…': 'جارٍ تحميل إعدادات اللغة…',
  'Loading your settings…': 'جارٍ تحميل إعداداتك…',
  'Please keep CloudPOS open while your saved data loads.':
      'يرجى إبقاء CloudPOS مفتوحًا أثناء تحميل بياناتك المحفوظة.',
  'CloudPOS couldn’t finish starting': 'تعذّر إكمال تشغيل CloudPOS',
  'We couldn’t load the data needed to open your counter. Close CloudPOS and open it again. If this continues, share the error details with support.':
      'تعذّر تحميل البيانات اللازمة لفتح نقطة البيع. أغلق CloudPOS وافتحه مجددًا. إذا استمرت المشكلة، شارك تفاصيل الخطأ مع الدعم.',
  'Error details': 'تفاصيل الخطأ',
  'Copy error details': 'نسخ تفاصيل الخطأ',
  'Close CloudPOS': 'إغلاق CloudPOS',
  'Confirming order…': 'جارٍ تأكيد الطلب…',
  'Still confirming…': 'لا يزال تأكيد الطلب جاريًا…',
  'We haven’t received confirmation yet': 'لم نتلقَّ تأكيدًا بعد',
  'The server is taking longer to respond. Please keep this order open.':
      'يستغرق الخادم وقتًا أطول للرد. يرجى إبقاء هذا الطلب مفتوحًا.',
  'This order may already be saved. Check its status before creating it again.':
      'قد يكون هذا الطلب محفوظًا بالفعل. تحقّق من حالته قبل إنشائه مجددًا.',
  'Order confirmed': 'تم تأكيد الطلب',
  'Saved order': 'طلب محفوظ',
  'View orders': 'عرض الطلبات',
  'Review saved attempt': 'مراجعة محاولة الحفظ',
  'Finish saved order': 'إكمال الطلب المحفوظ',
  'Keep for review': 'الاحتفاظ للمراجعة',
  'Close': 'إغلاق',
  'Clear this matching cart': 'مسح هذه السلة المطابقة',
  'The current cart matches the saved items. Confirm that this is the original sale before clearing it.':
      'تطابق السلة الحالية العناصر المحفوظة. تأكّد من أنها عملية البيع الأصلية قبل مسحها.',
  'The current cart differs from the saved attempt. It has been kept unchanged. Restore the original cart to finish this order.':
      'تختلف السلة الحالية عن محاولة الحفظ. تم الاحتفاظ بها دون تغيير. استعد السلة الأصلية لإكمال هذا الطلب.',
  'Your saved attempt is shown below. Compare it with your orders. A missing order in the list does not prove that it was not created. Contact support if you cannot verify the result.':
      'تظهر محاولة الحفظ أدناه. قارنها بطلباتك. عدم ظهور الطلب في القائمة لا يثبت أنه لم يُنشأ. تواصل مع الدعم إذا تعذّر التحقق من النتيجة.',
  'We couldn’t complete the checkout screen. Review the order status before billing again.':
      'تعذّر إكمال شاشة الدفع. راجع حالة الطلب قبل إصدار الفاتورة مجددًا.',
};

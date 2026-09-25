# Release Notes / ملاحظات الإصدار (v1.5.0+36)

<en-US>
* Supplementary Credit Cards: Add sub-cards linked to a main credit card. Supplementary cards inherit the main card's limit, currency, and owed balance.
* Unified Credit Card Liabilities: Transactions and payments made through a supplementary card update the main card liability without counting the same debt twice.
* Safer Card Changes: When archiving a main card, choose which supplementary card becomes standalone and keeps the existing balance; other supplementary cards become standalone with zero balance.
* Credit Card Transfers and Payments: Credit-card-to-credit-card transfers and payments now retain their correct card identities and remain transfers by default, with an explicit expense option when needed.
* Persistence and Sync: Credit-card relationships and balances are preserved across JSON backups, SQLite storage, cloud sync, restore, and distribution builds.
* Assets and Liabilities: Credit-card liabilities are consolidated in the Assets pages and excluded from duplicate totals.
* Responsiveness: Reduced unnecessary synchronization and database rewrites after settings-only changes, while preserving required reconciliation for transactions and savings.
* Smoother Navigation: Reduced visible lag in Smart Capture actions, entry saves, card interactions, currency selection, and dashboard page animations.
</en-US>

<ar>
* البطاقات الائتمانية الإضافية: إمكانية إضافة بطاقات فرعية مرتبطة ببطاقة ائتمانية رئيسية، مع وراثة الحد الائتماني والعملة والرصيد المستحق.
* توحيد التزامات البطاقات: تؤثر المعاملات والمدفوعات من البطاقة الفرعية على التزام البطاقة الرئيسية دون احتساب الدين مرتين.
* تغييرات أكثر أماناً على البطاقات: عند أرشفة البطاقة الرئيسية، يمكن اختيار البطاقة الفرعية التي تصبح مستقلة وتحتفظ بالرصيد الحالي، بينما تصبح البطاقات الأخرى مستقلة برصيد صفري.
* التحويلات والمدفوعات: الحفاظ على هوية البطاقات في التحويلات بين البطاقات والمدفوعات، مع جعل التحويل هو الخيار الافتراضي وإتاحة تسجيله كمصروف عند الحاجة.
* الحفظ والمزامنة: حفظ علاقات البطاقات وأرصدتها عبر نسخ JSON وقاعدة SQLite والمزامنة السحابية والاستعادة ونسخ التوزيع.
* الأصول والالتزامات: توحيد التزامات البطاقات في صفحات الأصول ومنع تكرارها في الإجماليات.
* سرعة الاستجابة: تقليل عمليات المزامنة وإعادة كتابة قاعدة البيانات غير الضرورية بعد تغييرات الإعدادات، مع الحفاظ على المصالحة المطلوبة للمعاملات والمدخرات.
* تنقل أكثر سلاسة: تقليل التأخير في إجراءات الالتقاط الذكي وحفظ الإدخالات والتفاعل مع البطاقات واختيار العملة وحركات لوحة التحكم.
</ar>

---

# Release Notes / ملاحظات الإصدار (v1.4.0+32)

<en-US>
* Unified Other Assets: Added Cars (with depreciation) and Liabilities (reducing Net Worth).
* Net Worth Focus: Dashboard main card now shows Net Worth instead of Total Wealth.
* Type Constraints: Auto-filters asset type dropdown when adding from a specific category.
* Arabic Layout Fixes: Formatted Zakat date with Latin digits (RTL format).
</en-US>

<ar>
* الأصول الأخرى: إضافة السيارات (مع احتساب الاستهلاك) والالتزامات (تُخصم من صافي الثروة).
* التركيز على صافي الثروة: عرض صافي الثروة كمؤشر رئيسي في لوحة التحكم.
* تقييد نوع الأصل: تحديد نوع الأصل تلقائياً عند الإضافة من شاشات التفاصيل.
* تحسين التاريخ بالعربية: تنسيق تاريخ الزكاة بالأرقام اللاتينية من اليمين لليسار.
</ar>

---

# Release Notes / ملاحظات الإصدار (v1.3.2+30)

<en-US>
* Corrected Currency Exchange on Activity Screen: Fixed an issue where the activity summary cards (total Income, Expenses, and Transfers) would not apply exchange rate conversions when changing the main display currency.
* Built-in optimizations and bug fixes to enhance general stability.
</en-US>

<ar>
* تصحيح تحويل العملات في شاشة النشاط: تم إصلاح مشكلة عدم تطبيق تحويلات أسعار الصرف لبطاقات ملخص الأنشطة (إجمالي الدخل، المصروفات، والتحويلات) عند تغيير العملة الرئيسية للتطبيق.
* تحسينات عامة وإصلاح للأخطاء لزيادة استقرار التطبيق.
</ar>

---

# Release Notes / ملاحظات الإصدار (v1.2.0+16)

<en-US>
* Zakat Calculation Guide: Added an interactive explanation screen inside the Account screen clarifying how Monthly/Hawl and Annual calculation methods work with real-world examples.
* Redesigned Policy and Support pages: Privacy Policy, Terms of Service, and Support & Feedback are now redesigned with clean card-based layouts.
* New About Zakah Wealth screen: Dedicated About page displaying core app principles (data privacy, drive backups, bank notifications) and version details.
</en-US>

<ar>
* دليل حساب الزكاة: إضافة شاشة توضيحية تفاعلية داخل شاشة الحساب توضح طريقتي الحساب الشهري والسنوي بالتفصيل ومع أمثلة تطبيقية.
* إعادة تصميم صفحات السياسات والدعم: تحديث شاشات سياسة الخصوصية، شروط الخدمة، والدعم والملاحظات إلى بطاقات منسقة وأنيقة.
* صفحة جديدة عن التطبيق: شاشة مخصصة لعرض مبادئ التطبيق (خصوصية البيانات، النسخ الاحتياطي، إشعارات البنوك) وتفاصيل الإصدار.
</ar>

---

# Release Notes / ملاحظات الإصدار (v1.1.0+15)

<en-US>
* Compact Layouts for Assets: Redesigned Cash, Gold, and Silver cards to fit all info cleanly on smaller devices.
* Unified Gold/Silver Icons: Upgraded metal asset icons to a premium stacked-ingots design.
* Direct Swipe Actions: Removed the 3-dots menu button and placed Sell actions inside the swipe menu.
</en-US>

<ar>
* تصاميم مدمجة للأصول: إعادة تصميم بطاقات النقد والذهب والفضة لتناسب الشاشات الصغيرة وتمنع تداخل النصوص.
* أيقونات موحدة للذهب والفضة: تحديث أيقونات المعادن إلى تصميم سبائك مميز ومنسق.
* إجراءات سحب مباشرة: إزالة زر النقاط الثلاث وتضمين إجراءات البيع ضمن قائمة السحب الجانبية مباشرة.
</ar>

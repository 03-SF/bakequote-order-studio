import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocaleController extends Notifier<Locale> {
  @override
  Locale build() => const Locale('en');
  void toggle() => state = Locale(state.languageCode == 'en' ? 'ur' : 'en');
}

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

class AppStrings {
  AppStrings(this.locale);
  final Locale locale;
  static AppStrings of(BuildContext context) =>
      AppStrings(Localizations.localeOf(context));
  String t(String key) =>
      locale.languageCode == 'ur' ? (_urdu[key] ?? key) : key;
  static const _urdu = {
    'Home': 'ہوم',
    'Orders': 'آرڈرز',
    'Messages': 'پیغامات',
    'Account': 'اکاؤنٹ',
    'Today': 'آج',
    'Calendar': 'کیلنڈر',
    'Customer': 'گاہک',
    'Baker': 'بیکر',
    'Language': 'زبان',
    'Development preview': 'ترقیاتی پیش نظارہ',
    'Phase 1 • Sample data only. Accounts and ordering are not connected.':
        'مرحلہ ۱ • صرف نمونہ ڈیٹا۔ اکاؤنٹس اور آرڈر ابھی منسلک نہیں ہیں۔',
    'Made with care. Ordered with confidence.': 'محبت سے تیار، اعتماد سے آرڈر۔',
    'A little sweetness, thoughtfully planned.':
        'کچھ مٹھاس، سوچ سمجھ کر منصوبہ بندی کے ساتھ۔',
    'Explore customer preview': 'گاہک کا پیش نظارہ دیکھیں',
    'Explore baker preview': 'بیکر کا پیش نظارہ دیکھیں',
    'Switch preview role': 'پیش نظارے کا کردار بدلیں',
    'Your bakery': 'آپ کی بیکری',
    'Sample bakery': 'نمونہ بیکری',
    'Bakery code': 'بیکری کوڈ',
    'F-10, Islamabad': 'ایف ۱۰، اسلام آباد',
    'Custom cakes & cupcakes, baked at home.':
        'گھر کے بنے حسبِ پسند کیک اور کپ کیک۔',
    'Find a bakery': 'بیکری تلاش کریں',
    'Bakery access is planned for Phase 4.':
        'بیکری تک رسائی مرحلہ ۴ میں آئے گی۔',
    'Preview menu': 'نمونہ مینو',
    'Chocolate cake': 'چاکلیٹ کیک',
    'Cupcakes': 'کپ کیکس',
    'From PKR 1,800': 'قیمت ۱۸۰۰ روپے سے',
    'From PKR 1,500': 'قیمت ۱۵۰۰ روپے سے',
    'Sample orders': 'نمونہ آرڈرز',
    'View quotation': 'قیمت کی تفصیل دیکھیں',
    'Pending': 'زیر التوا',
    'Baking': 'تیاری جاری',
    '2 lb chocolate birthday cake': 'دو پاؤنڈ چاکلیٹ سالگرہ کیک',
    'Quotation v2': 'قیمت نامہ ورژن ۲',
    'Base cake': 'بنیادی کیک',
    'Buttercream': 'بٹر کریم',
    'Topper': 'ٹاپر',
    'Delivery': 'ڈیلیوری',
    'Custom design': 'خصوصی ڈیزائن',
    'Total': 'کل',
    'Advance recorded': 'درج شدہ پیشگی رقم',
    'Balance due': 'باقی رقم',
    'Sample amounts • payments received outside the app.':
        'نمونہ رقوم • ادائیگی ایپ سے باہر وصول کی جاتی ہے۔',
    'Agreement and confirmation arrive in Phase 6.':
        'رضامندی اور تصدیق مرحلہ ۶ میں آئیں گی۔',
    'Close': 'بند کریں',
    'Order agenda': 'آرڈر کا ایجنڈا',
    'Calendar rules and date editing arrive in Phase 4.':
        'کیلنڈر کے قواعد اور تاریخ میں تبدیلی مرحلہ ۴ میں آئیں گے۔',
    'No live conversations yet': 'ابھی کوئی حقیقی گفتگو نہیں',
    'Order messaging arrives in Phase 8. Chat never confirms an order.':
        'آرڈر کے پیغامات مرحلہ ۸ میں آئیں گے۔ گفتگو سے آرڈر کی تصدیق نہیں ہوتی۔',
    'Preview profile': 'نمونہ پروفائل',
    'Real accounts arrive in Phase 2. No session is signed in.':
        'حقیقی اکاؤنٹس مرحلہ ۲ میں آئیں گے۔ کوئی صارف سائن اِن نہیں ہے۔',
    'Backend not connected': 'بیک اینڈ منسلک نہیں',
    'Configuration supplied • integration deferred to Phase 2':
        'ترتیب مہیا ہے • انضمام مرحلہ ۲ میں ہوگا',
    'Page not found': 'صفحہ نہیں ملا',
    'Back to welcome': 'ابتدا پر واپس',
  };
}

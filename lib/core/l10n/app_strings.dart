import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocaleController extends Notifier<Locale> {
  @override
  Locale build() => const Locale('en');
  void setLanguage(String language) {
    if ({'en', 'ur'}.contains(language)) state = Locale(language);
  }

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
    'Restoring your session': 'آپ کا سیشن بحال ہو رہا ہے',
    'Account unavailable': 'اکاؤنٹ دستیاب نہیں',
    'Account data is hidden until your session can be checked.':
        'سیشن کی جانچ تک اکاؤنٹ کا ڈیٹا ظاہر نہیں ہوگا۔',
    'Retry': 'دوبارہ کوشش کریں',
    'Log out': 'لاگ آؤٹ',
    'Verify your email': 'اپنے ای میل کی تصدیق کریں',
    'Open the verification email on this device, or verify then sign in.':
        'اسی آلے پر تصدیقی ای میل کھولیں، یا تصدیق کے بعد سائن اِن کریں۔',
    'Resend verification': 'تصدیقی ای میل دوبارہ بھیجیں',
    'Sign in after verification': 'تصدیق کے بعد سائن اِن کریں',
    'Create account': 'اکاؤنٹ بنائیں',
    'Set new password': 'نیا پاس ورڈ مقرر کریں',
    'Reset password': 'پاس ورڈ دوبارہ مقرر کریں',
    'Sign in': 'سائن اِن',
    'Configure the development backend before signing in.':
        'سائن اِن سے پہلے ترقیاتی بیک اینڈ کی ترتیب مکمل کریں۔',
    'Full name': 'پورا نام',
    'Email': 'ای میل',
    'Password': 'پاس ورڈ',
    'Show or hide password': 'پاس ورڈ دکھائیں یا چھپائیں',
    'Enter your password': 'اپنا پاس ورڈ درج کریں',
    'Confirm password': 'پاس ورڈ کی تصدیق',
    'Passwords do not match': 'پاس ورڈ یکساں نہیں ہیں',
    'Send recovery email': 'بحالی کی ای میل بھیجیں',
    'Forgot password?': 'پاس ورڈ بھول گئے؟',
    'Back to sign in': 'سائن اِن پر واپس',
    'Cancel and sign out': 'منسوخ کرکے سائن آؤٹ کریں',
    'Complete your identity': 'اپنی شناخت مکمل کریں',
    'Choose your initial experience': 'اپنا ابتدائی کردار منتخب کریں',
    'Experience': 'کردار',
    'Phone (optional)': 'فون (اختیاری)',
    'Business name': 'کاروبار کا نام',
    'This creates a private draft. Full bakery setup arrives in Phase 3.':
        'یہ نجی مسودہ بناتا ہے۔ بیکری کا مکمل سیٹ اپ مرحلہ ۳ میں آئے گا۔',
    'Saving...': 'محفوظ ہو رہا ہے…',
    'Continue': 'جاری رکھیں',
    'Your account is connected. Ordering and bakery operations arrive in later phases.':
        'آپ کا اکاؤنٹ منسلک ہے۔ آرڈر اور بیکری کی سہولیات بعد کے مراحل میں آئیں گی۔',
    'Save profile': 'پروفائل محفوظ کریں',
    'Public business image': 'کاروبار کی عوامی تصویر',
    'Private profile image': 'پروفائل کی نجی تصویر',
    'Image could not be loaded': 'تصویر لوڈ نہیں ہو سکی',
    'Choose image': 'تصویر منتخب کریں',
    'Images: JPEG, PNG or WebP, up to 5 MB. Business images are public.':
        'تصاویر: جے پیگ، پی این جی یا ویب پی، زیادہ سے زیادہ ۵ ایم بی۔ کاروبار کی تصاویر عوامی ہیں۔',
    'Invalid app mode': 'ایپ کا موڈ درست نہیں',
    'Invalid backend configuration': 'بیک اینڈ کی ترتیب درست نہیں',
    'Privileged keys are forbidden': 'خصوصی اختیارات والی کلیدیں ممنوع ہیں',
    'Use a public publishable key': 'عوامی پبلش ایبل کلید استعمال کریں',
    'Enter a valid email': 'درست ای میل درج کریں',
    'Use at least 8 characters': 'کم از کم ۸ حروف استعمال کریں',
    'Enter 1 to 100 characters': '۱ سے ۱۰۰ حروف درج کریں',
    'Choose an image up to 5 MB': '۵ ایم بی تک کی تصویر منتخب کریں',
    'Choose a JPEG, PNG or WebP image':
        'جے پیگ، پی این جی یا ویب پی تصویر منتخب کریں',
    'Business identity is required': 'کاروباری شناخت درکار ہے',
    'This link is invalid or expired. Request a new email.':
        'یہ لنک درست نہیں یا ختم ہو چکا ہے۔ نئی ای میل منگوائیں۔',
    'This link belongs to a different authentication flow.':
        'یہ لنک تصدیق کے دوسرے عمل سے متعلق ہے۔',
    'Email or password is incorrect': 'ای میل یا پاس ورڈ درست نہیں',
    'Verify your email before signing in':
        'سائن اِن سے پہلے ای میل کی تصدیق کریں',
    'Use a stronger password': 'زیادہ مضبوط پاس ورڈ استعمال کریں',
    'Please wait before trying again': 'دوبارہ کوشش سے پہلے انتظار کریں',
    'Could not complete this action. Check your connection and try again.':
        'یہ عمل مکمل نہیں ہوا۔ کنکشن چیک کرکے دوبارہ کوشش کریں۔',
    'Account data could not be verified': 'اکاؤنٹ کے ڈیٹا کی تصدیق نہیں ہو سکی',
    'Check your email to verify your account':
        'اکاؤنٹ کی تصدیق کے لیے ای میل دیکھیں',
    'Verification email sent if eligible':
        'اہلیت کی صورت میں تصدیقی ای میل بھیج دی گئی ہے',
    'Recovery email sent if an account exists':
        'اکاؤنٹ موجود ہونے کی صورت میں بحالی کی ای میل بھیج دی گئی ہے',
    'Open a valid recovery link first': 'پہلے درست بحالی کا لنک کھولیں',
    'Password updated. Sign in with your new password.':
        'پاس ورڈ تبدیل ہوگیا۔ نئے پاس ورڈ سے سائن اِن کریں۔',
    'Profile saved': 'پروفائل محفوظ ہوگئی',
    'Image uploaded': 'تصویر اپ لوڈ ہوگئی',
    'Preview mode never connects to live accounts':
        'پیش نظارہ حقیقی اکاؤنٹس سے کبھی منسلک نہیں ہوتا',
    'Invalid callback configuration': 'واپسی کے لنک کی ترتیب درست نہیں',
  };
}

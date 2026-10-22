/// Sorani (ckb) UI strings — mirrored from Asset Kit `localization/ckb.json`.
abstract final class L10n {
  static const welcome = 'بەخێربێی کاک بەختوور';
  static const subtitle = 'کۆنترۆڵی چوار ئامێر بە پەیام';
  static const letsGo = 'دەبا بڕۆین';
  static const hello = 'سڵاو';
  static const saved = 'پاشەکەوت کرا';
  static const savedBody =
      'ژمارەی کیت پاشەکەوت کرا. ئێستا دەتوانیت فەنەکان کۆنترۆڵ بکەیت.';
  static const ok = 'باشە';
  static const cancel = 'دواتر';
  static const allow = 'ڕێگەبدە';
  static const openSettings = 'کردنەوەی ڕێکخستن';
  static const smsPermissionTitle = 'دەسەڵاتی ناردنی پەیام';
  static const smsPermissionBody =
      'بۆ کۆنترۆڵی کیت، ئەم ئەپە پێویستی بە ناردنی SMS هەیە. ڕێگە دەدەیت؟';
  static const smsDeniedTitle = 'دەسەڵاتی SMS نییە';
  static const smsDeniedBody =
      '١) ڕێکخستنی ئەپ → سێ خاڵ → «Allow restricted settings / اجازه تنظیمات محدود»\n'
      '٢) دەسەڵاتەکان → پیامک → اجازه دادن\n'
      'ئەگەر «اجازه دادن» خاکستری بوو، هەمان هەنگاوی ١ پێویستە.';
  static const smsUnavailableIos =
      'ئەم ئامێرە ناتوانێت SMS بنێرێت. سیم‌کارت و ئەپی Messages پێویستە (لەسەر Simulator کار ناکات).';
  static const smsCancelled = 'ناردن هەڵوەشایەوە';
  static const iosSmsNote =
      'لەسەر ئاایفۆن فەرمان لە Messages دەردەکەوێت و دەبێت Send لێ بدەیت.';
  static const syncing = 'هاوکاتکردن لەگەڵ کیت…';
  static const synced = 'دۆخی فەنەکان نوێ کرایەوە';
  static const syncLocal = 'دۆخی پاشەکەوتکراو (بێ وەڵامی کیت)';
  static const smsHideNote =
      'شاردنەوەی تەواوی SMS تەنها کاتێک دەکرێت ئەپ SMSی سەرەکی بێت؛ هەوڵی سڕینەوە دەدرێت.';
  static const saveFailed = 'پاشەکەوتکردن سەرکەوتوو نەبوو';
  static const passwordHint = '٤ ژمارە (بۆ نموونە 0000)';
  static const devices = 'ئامێرەکان';
  static const fan1 = 'فەن ١';
  static const fan2 = 'فەن ٢';
  static const fan3 = 'فەن ٣';
  static const fan4 = 'فەن ٤';
  static const turnOn = 'کردنەوە';
  static const turnOff = 'خاموشکردنەوە';
  static const stateOn = 'چالاکە';
  static const stateOff = 'کوژاوەتەوە';
  static const settings = 'ڕێکخستن';
  static const log = 'تۆمار';
  static const send = 'ناردن';
  static const sent = 'نێردرا';
  static const sendError = 'هەڵە لە ناردن';
  static const noSignal = 'هێمای نییە';
  static const allOff = 'هەموو خاموش';
  static const phoneNumber = 'ژمارەی مۆبایل';
  static const password = 'وشەی نهێنی';
  static const silentSend = 'ناردنی بێدەنگ';
  static const silentHelper = 'ناردنی SMS بەبێ دەنگ';
  static const testConnection = 'تاقیکردنەوە';
  static const connection = 'پەیوەندی';
  static const deviceNames = 'ناوی ئامێرەکان';
  static const reply = 'وەڵام';
  static const sending = 'لە ناردندایە';
  static const awaitingReply = 'چاوەڕێی وەڵامی ئامێر';
  static const pendingConfirm =
      'پەیام نێردرا؛ دۆخی ئامێر تا وەڵامی کیت پشتڕاست نەکراوە';
  static const pwaSmsNote =
      'لە وێبدا پەیامەکە لە ئەپی SMS دەکرێتەوە. دەبێت خۆت Send لێ بدەیت. وەڵامی کیت لێرە وەرناگیرێت.';
  static const commandTimeout = 'کاتەکە تەواو بوو — وەڵامی کیت نەهات';
  static const unknown = 'دۆخەکە دیار نییە';
  static const emptyTitle = 'هێشتا پەیامێک نییە';
  static const emptyBody = 'پەیامەکان لێرە دەردەکەون';
  static const emptyLog = 'تۆماری بەتاڵ';
  static const lastReply = 'دوايين وەڵام';
  static const setupNeeded = 'ژمارەی کیت ڕێک نەخراوە — کلیک بکە';
  static const save = 'پاشەکەوتکردن';
  static const all = 'ھەموو';
  static const filterSent = 'نێردرا';
  static const filterError = 'ھەڵە';
  static const gsm = 'GSM';
  static const demo = 'DEMO';
  static const configure = 'ڕێکخە';

  static String sentTo(String code) => 'نێردرا بۆ $code';

  static const defaultNames = [fan1, fan2, fan3, fan4];
}

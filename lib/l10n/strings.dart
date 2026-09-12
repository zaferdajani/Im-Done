import 'package:flutter/widgets.dart';

/// Every user-facing string, in English and Arabic. The app never hardcodes
/// text in widgets; it reads `L10n.of(context)`.
class L10n {
  const L10n({
    required this.appName,
    required this.tagline,
    required this.today,
    required this.later,
    required this.doneToday,
    required this.nothingToday,
    required this.holdToSpeak,
    required this.listening,
    required this.releaseToFinish,
    required this.typeInstead,
    required this.newTask,
    required this.editTask,
    required this.titleLabel,
    required this.titleHint,
    required this.kindLabel,
    required this.kindPersonal,
    required this.kindShared,
    required this.kindSharedHint,
    required this.frequencyLabel,
    required this.freqOnce,
    required this.freqDaily,
    required this.freqWeekdays,
    required this.freqWeekly,
    required this.freqEveryNDays,
    required this.everyNDaysLabel,
    required this.weekdayShort,
    required this.timeLabel,
    required this.periodLabel,
    required this.periodStart,
    required this.periodEnd,
    required this.periodNone,
    required this.dateLabel,
    required this.nagLabel,
    required this.nagOff,
    required this.nagEvery,
    required this.nagTimes,
    required this.nagHint,
    required this.noteLabel,
    required this.save,
    required this.cancel,
    required this.delete,
    required this.deleteTaskConfirm,
    required this.markDone,
    required this.undo,
    required this.done,
    required this.awaitingConfirmation,
    required this.confirmDone,
    required this.notDone,
    required this.claimedBy,
    required this.confirmedBy,
    required this.members,
    required this.you,
    required this.creator,
    required this.invite,
    required this.inviteMessage,
    required this.inviteHint,
    required this.copyLink,
    required this.linkCopied,
    required this.joinTask,
    required this.joining,
    required this.joined,
    required this.joinFailed,
    required this.signInTitle,
    required this.signInWhy,
    required this.signInGoogle,
    required this.signInApple,
    required this.signOut,
    required this.account,
    required this.deleteAccount,
    required this.deleteAccountConfirm,
    required this.deleteAccountDone,
    required this.cloudUnavailable,
    required this.settings,
    required this.language,
    required this.languageSystem,
    required this.notifications,
    required this.notificationsHint,
    required this.exactReminders,
    required this.exactRemindersHint,
    required this.privacyPolicy,
    required this.terms,
    required this.micPermissionTitle,
    required this.micPermissionBody,
    required this.micPermissionAllow,
    required this.micDenied,
    required this.speechUnavailable,
    required this.notifPermissionTitle,
    required this.notifPermissionBody,
    required this.reminderChannel,
    required this.reminderChannelDesc,
    required this.reminderTitle,
    required this.reminderNag,
    required this.actionDone,
    required this.snooze,
    required this.dueAt,
    required this.overdue,
    required this.streak,
    required this.emptyTitle,
    required this.emptyBody,
    required this.sharedSectionTitle,
    required this.pendingConfirmations,
    required this.notificationsOff,
    required this.enable,
    required this.error,
    required this.ok,
    required this.freqSummaryDaily,
    required this.freqSummaryWeekdays,
    required this.freqSummaryOnce,
    required this.freqSummaryEveryN,
    required this.freqSummaryWeekly,
    required this.untilDate,
    required this.fromDate,
    required this.needsYourConfirmation,
    required this.newSharedTask,
    required this.version,
    required this.webRemindersNote,
  });

  final String appName;
  final String tagline;
  final String today;
  final String later;
  final String doneToday;
  final String nothingToday;
  final String holdToSpeak;
  final String listening;
  final String releaseToFinish;
  final String typeInstead;
  final String newTask;
  final String editTask;
  final String titleLabel;
  final String titleHint;
  final String kindLabel;
  final String kindPersonal;
  final String kindShared;
  final String kindSharedHint;
  final String frequencyLabel;
  final String freqOnce;
  final String freqDaily;
  final String freqWeekdays;
  final String freqWeekly;
  final String freqEveryNDays;
  final String everyNDaysLabel;
  final List<String> weekdayShort; // Mon..Sun
  final String timeLabel;
  final String periodLabel;
  final String periodStart;
  final String periodEnd;
  final String periodNone;
  final String dateLabel;
  final String nagLabel;
  final String nagOff;
  final String nagEvery;
  final String nagTimes;
  final String nagHint;
  final String noteLabel;
  final String save;
  final String cancel;
  final String delete;
  final String deleteTaskConfirm;
  final String markDone;
  final String undo;
  final String done;
  final String awaitingConfirmation;
  final String confirmDone;
  final String notDone;
  final String claimedBy;
  final String confirmedBy;
  final String members;
  final String you;
  final String creator;
  final String invite;
  final String inviteMessage;
  final String inviteHint;
  final String copyLink;
  final String linkCopied;
  final String joinTask;
  final String joining;
  final String joined;
  final String joinFailed;
  final String signInTitle;
  final String signInWhy;
  final String signInGoogle;
  final String signInApple;
  final String signOut;
  final String account;
  final String deleteAccount;
  final String deleteAccountConfirm;
  final String deleteAccountDone;
  final String cloudUnavailable;
  final String settings;
  final String language;
  final String languageSystem;
  final String notifications;
  final String notificationsHint;
  final String exactReminders;
  final String exactRemindersHint;
  final String privacyPolicy;
  final String terms;
  final String micPermissionTitle;
  final String micPermissionBody;
  final String micPermissionAllow;
  final String micDenied;
  final String speechUnavailable;
  final String notifPermissionTitle;
  final String notifPermissionBody;
  final String reminderChannel;
  final String reminderChannelDesc;
  final String reminderTitle;
  final String reminderNag;
  final String actionDone;
  final String snooze;
  final String dueAt;
  final String overdue;
  final String streak;
  final String emptyTitle;
  final String emptyBody;
  final String sharedSectionTitle;
  final String pendingConfirmations;
  final String notificationsOff;
  final String enable;
  final String error;
  final String ok;
  final String freqSummaryDaily;
  final String freqSummaryWeekdays;
  final String freqSummaryOnce;
  final String freqSummaryEveryN; // {n}
  final String freqSummaryWeekly; // {days}
  final String untilDate; // {date}
  final String fromDate; // {date}
  final String needsYourConfirmation;
  final String newSharedTask;
  final String version;
  final String webRemindersNote;

  static L10n of(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

  static L10n forCode(String code) => code == 'ar' ? ar : en;

  static const en = L10n(
    appName: 'Doneby',
    tagline: 'Say it. Get nagged. Get it done.',
    today: 'Today',
    later: 'Coming up',
    doneToday: 'Done today',
    nothingToday: 'Nothing due today',
    holdToSpeak: 'Hold to speak',
    listening: 'Listening…',
    releaseToFinish: 'Release when you are done',
    typeInstead: 'Type instead',
    newTask: 'New task',
    editTask: 'Edit task',
    titleLabel: 'Task',
    titleHint: 'What needs doing?',
    kindLabel: 'Who is this for?',
    kindPersonal: 'Just me',
    kindShared: 'Shared',
    kindSharedHint: 'Invite people. Everyone is reminded; you confirm when it is done.',
    frequencyLabel: 'How often',
    freqOnce: 'Once',
    freqDaily: 'Every day',
    freqWeekdays: 'Weekdays',
    freqWeekly: 'Weekly',
    freqEveryNDays: 'Every N days',
    everyNDaysLabel: 'Every',
    weekdayShort: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    timeLabel: 'At',
    periodLabel: 'Period',
    periodStart: 'Starts',
    periodEnd: 'Ends',
    periodNone: 'No end',
    dateLabel: 'Date',
    nagLabel: 'Keep reminding',
    nagOff: 'Remind once',
    nagEvery: 'every',
    nagTimes: 'times',
    nagHint: 'The reminder repeats until you mark it done.',
    noteLabel: 'Note (optional)',
    save: 'Save',
    cancel: 'Cancel',
    delete: 'Delete',
    deleteTaskConfirm: 'Delete this task and all its reminders?',
    markDone: 'Done',
    undo: 'Undo',
    done: 'Done',
    awaitingConfirmation: 'Waiting for confirmation',
    confirmDone: 'Confirm done',
    notDone: 'Not done',
    claimedBy: 'Marked done by',
    confirmedBy: 'Confirmed by',
    members: 'People',
    you: 'You',
    creator: 'Creator',
    invite: 'Invite people',
    inviteMessage: 'Join my task "{title}" on Doneby:',
    inviteHint: 'Share the link on WhatsApp, Instagram, Messenger or anywhere else. Anyone who opens it joins the task.',
    copyLink: 'Copy link',
    linkCopied: 'Link copied',
    joinTask: 'Join task',
    joining: 'Joining…',
    joined: 'You joined the task',
    joinFailed: 'That invite link is not valid any more.',
    signInTitle: 'Sign in to share tasks',
    signInWhy: 'Personal tasks stay on this phone and never need an account. Sharing a task with other people needs a sign-in so they know who asked.',
    signInGoogle: 'Continue with Google',
    signInApple: 'Continue with Apple',
    signOut: 'Sign out',
    account: 'Account',
    deleteAccount: 'Delete my account',
    deleteAccountConfirm: 'This permanently deletes your account, the shared tasks you created, and your memberships. Personal tasks on this phone are kept. Continue?',
    deleteAccountDone: 'Your account was deleted.',
    cloudUnavailable: 'Sharing is not set up in this build yet. Personal tasks work normally.',
    settings: 'Settings',
    language: 'Language',
    languageSystem: 'System',
    notifications: 'Reminders',
    notificationsHint: 'Reminders need notification permission.',
    exactReminders: 'Precise timing',
    exactRemindersHint: 'Android may delay reminders to save battery. Allow “Alarms & reminders” to fire them on the minute.',
    privacyPolicy: 'Privacy policy',
    terms: 'Terms of use',
    micPermissionTitle: 'Use the microphone?',
    micPermissionBody: 'Doneby listens while you hold the button and turns your words into a task. Your voice is processed by the phone’s speech service and is never stored by Doneby.',
    micPermissionAllow: 'Continue',
    micDenied: 'Microphone access is off. You can type the task, or enable the microphone in Settings.',
    speechUnavailable: 'Speech recognition is not available on this device. You can type the task.',
    notifPermissionTitle: 'Allow reminders?',
    notifPermissionBody: 'Doneby reminds you at the time you choose and keeps reminding you until the task is done.',
    reminderChannel: 'Task reminders',
    reminderChannelDesc: 'Reminders that repeat until a task is marked done',
    reminderTitle: 'Time to: {title}',
    reminderNag: 'Still not done: {title}',
    actionDone: 'Done ✓',
    snooze: 'Later',
    dueAt: 'Due {time}',
    overdue: 'Overdue',
    streak: '{n}-day streak',
    emptyTitle: 'Hold the button and say a task',
    emptyBody: '“Call the pharmacy every day at 9” becomes a task with a reminder that will not stop until you do it.',
    sharedSectionTitle: 'Shared with others',
    pendingConfirmations: 'Needs your confirmation',
    notificationsOff: 'Reminders are off',
    enable: 'Enable',
    error: 'Something went wrong',
    ok: 'OK',
    freqSummaryDaily: 'Every day',
    freqSummaryWeekdays: 'Weekdays',
    freqSummaryOnce: 'Once',
    freqSummaryEveryN: 'Every {n} days',
    freqSummaryWeekly: 'Every {days}',
    untilDate: 'until {date}',
    fromDate: 'from {date}',
    needsYourConfirmation: 'Someone marked this done. Confirm?',
    newSharedTask: 'New shared task',
    version: 'Version',
    webRemindersNote: 'A browser cannot ring a reminder while the tab is closed. Install the phone app for reminders; the web app is for managing and confirming tasks.',
  );

  static const ar = L10n(
    appName: 'دَن باي',
    tagline: 'قُلها. نُذكّرك. أنجِزها.',
    today: 'اليوم',
    later: 'القادم',
    doneToday: 'أُنجز اليوم',
    nothingToday: 'لا شيء مستحق اليوم',
    holdToSpeak: 'اضغط مطوّلًا وتكلّم',
    listening: 'أستمع…',
    releaseToFinish: 'ارفع إصبعك عندما تنتهي',
    typeInstead: 'اكتب بدلًا من ذلك',
    newTask: 'مهمة جديدة',
    editTask: 'تعديل المهمة',
    titleLabel: 'المهمة',
    titleHint: 'ما الذي يجب إنجازه؟',
    kindLabel: 'لمن هذه المهمة؟',
    kindPersonal: 'لي فقط',
    kindShared: 'مشتركة',
    kindSharedHint: 'ادعُ أشخاصًا. يُذكَّر الجميع، وأنت من يؤكد الإنجاز.',
    frequencyLabel: 'التكرار',
    freqOnce: 'مرة واحدة',
    freqDaily: 'كل يوم',
    freqWeekdays: 'أيام العمل',
    freqWeekly: 'أسبوعيًا',
    freqEveryNDays: 'كل عدة أيام',
    everyNDaysLabel: 'كل',
    weekdayShort: ['اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت', 'أحد'],
    timeLabel: 'الساعة',
    periodLabel: 'الفترة',
    periodStart: 'تبدأ',
    periodEnd: 'تنتهي',
    periodNone: 'بلا نهاية',
    dateLabel: 'التاريخ',
    nagLabel: 'استمر بالتذكير',
    nagOff: 'ذكّرني مرة واحدة',
    nagEvery: 'كل',
    nagTimes: 'مرات',
    nagHint: 'يتكرر التذكير حتى تُعلّم المهمة كمُنجزة.',
    noteLabel: 'ملاحظة (اختياري)',
    save: 'حفظ',
    cancel: 'إلغاء',
    delete: 'حذف',
    deleteTaskConfirm: 'حذف هذه المهمة وكل تذكيراتها؟',
    markDone: 'تم',
    undo: 'تراجع',
    done: 'تم',
    awaitingConfirmation: 'بانتظار التأكيد',
    confirmDone: 'تأكيد الإنجاز',
    notDone: 'لم تُنجز',
    claimedBy: 'علّمها كمُنجزة',
    confirmedBy: 'أكّدها',
    members: 'الأشخاص',
    you: 'أنت',
    creator: 'المنشئ',
    invite: 'دعوة أشخاص',
    inviteMessage: 'انضم إلى مهمتي "{title}" على دَن باي:',
    inviteHint: 'شارك الرابط عبر واتساب أو إنستغرام أو ماسنجر أو أي مكان آخر. كل من يفتحه ينضم إلى المهمة.',
    copyLink: 'نسخ الرابط',
    linkCopied: 'تم نسخ الرابط',
    joinTask: 'الانضمام إلى المهمة',
    joining: 'جارٍ الانضمام…',
    joined: 'انضممت إلى المهمة',
    joinFailed: 'رابط الدعوة لم يعد صالحًا.',
    signInTitle: 'سجّل الدخول لمشاركة المهام',
    signInWhy: 'المهام الشخصية تبقى على هذا الهاتف ولا تحتاج حسابًا. مشاركة مهمة مع الآخرين تحتاج تسجيل دخول ليعرفوا من طلبها.',
    signInGoogle: 'المتابعة عبر Google',
    signInApple: 'المتابعة عبر Apple',
    signOut: 'تسجيل الخروج',
    account: 'الحساب',
    deleteAccount: 'حذف حسابي',
    deleteAccountConfirm: 'سيُحذف حسابك نهائيًا مع المهام المشتركة التي أنشأتها وعضوياتك. المهام الشخصية على هذا الهاتف تبقى. هل تريد المتابعة؟',
    deleteAccountDone: 'تم حذف حسابك.',
    cloudUnavailable: 'المشاركة غير مفعّلة في هذه النسخة بعد. المهام الشخصية تعمل بشكل طبيعي.',
    settings: 'الإعدادات',
    language: 'اللغة',
    languageSystem: 'لغة الجهاز',
    notifications: 'التذكيرات',
    notificationsHint: 'تحتاج التذكيرات إلى إذن الإشعارات.',
    exactReminders: 'توقيت دقيق',
    exactRemindersHint: 'قد يؤخر أندرويد التذكيرات لتوفير البطارية. اسمح بـ«المنبهات والتذكيرات» لتصل في دقيقتها.',
    privacyPolicy: 'سياسة الخصوصية',
    terms: 'شروط الاستخدام',
    micPermissionTitle: 'استخدام الميكروفون؟',
    micPermissionBody: 'يستمع دَن باي أثناء ضغطك على الزر ويحوّل كلامك إلى مهمة. يعالج صوتَك خدمةُ التعرف على الكلام في هاتفك، ولا يخزّنه دَن باي أبدًا.',
    micPermissionAllow: 'متابعة',
    micDenied: 'الوصول إلى الميكروفون مغلق. يمكنك كتابة المهمة أو تفعيل الميكروفون من الإعدادات.',
    speechUnavailable: 'التعرف على الكلام غير متاح على هذا الجهاز. يمكنك كتابة المهمة.',
    notifPermissionTitle: 'السماح بالتذكيرات؟',
    notifPermissionBody: 'يذكّرك دَن باي في الوقت الذي تختاره ويستمر بالتذكير حتى تُنجز المهمة.',
    reminderChannel: 'تذكيرات المهام',
    reminderChannelDesc: 'تذكيرات تتكرر حتى تُعلَّم المهمة كمُنجزة',
    reminderTitle: 'حان وقت: {title}',
    reminderNag: 'لم تُنجز بعد: {title}',
    actionDone: 'تم ✓',
    snooze: 'لاحقًا',
    dueAt: 'الموعد {time}',
    overdue: 'متأخرة',
    streak: 'سلسلة {n} يوم',
    emptyTitle: 'اضغط الزر مطوّلًا وقل مهمة',
    emptyBody: '«اتصل بالصيدلية كل يوم الساعة 9» تصبح مهمة بتذكير لا يتوقف حتى تنجزها.',
    sharedSectionTitle: 'مشتركة مع آخرين',
    pendingConfirmations: 'بحاجة إلى تأكيدك',
    notificationsOff: 'التذكيرات متوقفة',
    enable: 'تفعيل',
    error: 'حدث خطأ ما',
    ok: 'حسنًا',
    freqSummaryDaily: 'كل يوم',
    freqSummaryWeekdays: 'أيام العمل',
    freqSummaryOnce: 'مرة واحدة',
    freqSummaryEveryN: 'كل {n} أيام',
    freqSummaryWeekly: 'كل {days}',
    untilDate: 'حتى {date}',
    fromDate: 'من {date}',
    needsYourConfirmation: 'أحدهم علّم هذه المهمة كمُنجزة. هل تؤكد؟',
    newSharedTask: 'مهمة مشتركة جديدة',
    version: 'الإصدار',
    webRemindersNote: 'لا يستطيع المتصفح تشغيل التذكير عندما تكون الصفحة مغلقة. ثبّت تطبيق الهاتف للتذكيرات؛ نسخة الويب لإدارة المهام وتأكيدها.',
  );
}

extension L10nFill on String {
  String fill(Map<String, Object> args) {
    var s = this;
    args.forEach((k, v) => s = s.replaceAll('{$k}', v.toString()));
    return s;
  }
}

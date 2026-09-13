import 'package:flutter/widgets.dart';

import 'tables.g.dart';

export 'tables.g.dart' show l10nTables;

/// Every user-facing string, in every supported language. The app never
/// hardcodes text in widgets; it reads `L10n.of(context)`, and the tables
/// behind it are generated from l10n/*.json by tool/gen_l10n.py — the
/// translation pipeline every word passes through before it is shown.
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
    required this.inviteTitle,
    required this.inviteBody,
    required this.inviteCodeLabel,
    required this.inviteContinue,
    required this.inviteOpenApp,
    required this.inviteGetAndroid,
    required this.inviteGetIos,
    required this.inviteNoAppHint,
    required this.notNow,
    required this.speechUnavailableWeb,
    required this.understanding,
    required this.voiceSection,
    required this.voiceCloudTitle,
    required this.voiceCloudBody,
    required this.voiceDeviceTitle,
    required this.voiceDeviceBody,
    required this.voiceOffline,
    required this.voiceNothingHeard,
    required this.voiceFailed,
    required this.voiceUnconfigured,
    required this.heardLabel,
    required this.spokenIn,
    required this.importanceLabel,
    required this.importanceHigh,
    required this.importanceMedium,
    required this.importanceLow,
    required this.welcomeTitle,
    required this.welcomeBody,
    required this.continueLabel,
    required this.appearance,
    required this.themeSystem,
    required this.themeLight,
    required this.themeDark,
    required this.pushAdded,
    required this.pushJoined,
    required this.pushClaimed,
    required this.pushClaimedBody,
    required this.pushConfirmed,
    required this.pushRejected,
    required this.groupLabel,
    required this.groupHint,
    required this.allGroups,
    required this.noGroup,
    required this.quickStartTitle,
    required this.quickStartHint,
    required this.yourName,
    required this.startNow,
    required this.keepAccountHint,
    required this.myCode,
    required this.myCodeHint,
    required this.addByCode,
    required this.addByCodeHint,
    required this.personAdded,
    required this.codeNotFound,
    required this.linkGoogle,
    required this.linkGoogleHint,
    required this.guestAccount,
    required this.scanCode,
    required this.scanHint,
    required this.addToWhichTask,
    required this.noSharedTasksYet,
    required this.shareMyCodeMessage,
    required this.useEmail,
    required this.emailLabel,
    required this.passwordLabel,
    required this.emailContinue,
    required this.forgotPassword,
    required this.resetSent,
    required this.emailHint,
    required this.linkEmail,
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
  final String inviteTitle;
  final String inviteBody;
  final String inviteCodeLabel;
  final String inviteContinue;
  final String inviteOpenApp;
  final String inviteGetAndroid;
  final String inviteGetIos;
  final String inviteNoAppHint;
  final String notNow;
  final String speechUnavailableWeb;
  final String understanding;
  final String voiceSection;
  final String voiceCloudTitle;
  final String voiceCloudBody;
  final String voiceDeviceTitle;
  final String voiceDeviceBody;
  final String voiceOffline;
  final String voiceNothingHeard;
  final String voiceFailed;
  final String voiceUnconfigured;
  final String heardLabel;
  final String spokenIn;
  final String importanceLabel;
  final String importanceHigh;
  final String importanceMedium;
  final String importanceLow;
  final String welcomeTitle;
  final String welcomeBody;
  final String continueLabel;
  final String appearance;
  final String themeSystem;
  final String themeLight;
  final String themeDark;
  final String pushAdded;
  final String pushJoined;
  final String pushClaimed;
  final String pushClaimedBody;
  final String pushConfirmed;
  final String pushRejected;
  final String groupLabel;
  final String groupHint;
  final String allGroups;
  final String noGroup;
  final String quickStartTitle;
  final String quickStartHint;
  final String yourName;
  final String startNow;
  final String keepAccountHint;
  final String myCode;
  final String myCodeHint;
  final String addByCode;
  final String addByCodeHint;
  final String personAdded;
  final String codeNotFound;
  final String linkGoogle;
  final String linkGoogleHint;
  final String guestAccount;
  final String scanCode;
  final String scanHint;
  final String addToWhichTask;
  final String noSharedTasksYet;
  final String shareMyCodeMessage;
  final String useEmail;
  final String emailLabel;
  final String passwordLabel;
  final String emailContinue;
  final String forgotPassword;
  final String resetSent;
  final String emailHint;
  final String linkEmail;

  static L10n of(BuildContext context) => forCode(Localizations.localeOf(context).languageCode);

  /// The one door every screen goes through: an unknown code shows English
  /// rather than crashing, but the generator (tool/gen_l10n.py) guarantees
  /// every code in [supportedLanguages] has a complete table.
  static L10n forCode(String code) => l10nTables[code] ?? l10nTables['en']!;
}

extension L10nFill on String {
  String fill(Map<String, Object> args) {
    var s = this;
    args.forEach((k, v) => s = s.replaceAll('{$k}', v.toString()));
    return s;
  }
}

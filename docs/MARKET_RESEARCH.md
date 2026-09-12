# I'm Done — Market & Monetization Research

*Compiled 2026-09-12 from live web research (sources linked inline). Figures marked
"unverified" could not be confirmed from a primary source.*

## 1. The one-line answer

Build it freemium with a 14-day Pro trial at **$3.99 / month, $19.99 / year, $49.99 lifetime**
(40–60 % lower on MENA storefronts), gate **creating shared groups, unlimited nagging and the
number of recurring tasks**, keep **voice capture and joining a group free forever**, use
**RevenueCat's free tier** and both stores' 15 % small-business rates, and treat **Arabic ASO plus
the invite loop** as the whole marketing plan. Base case for year one is **$4,000–10,000 net**.

## 2. Market size and where the money is

The productivity category is large but monetizes thinly per download: 6.0 % of global app
revenue on 5.4 % of downloads in 2025.

| Metric | Value | Source |
|---|---|---|
| Global app downloads 2025 | ~110 B | [Business of Apps](https://www.businessofapps.com/data/app-data-report/) |
| Global consumer spend 2025 | $150.5 B | [Business of Apps](https://www.businessofapps.com/data/app-revenues/) |
| Productivity share | 6.0 % of revenue, 5.4 % of downloads | [AppTweak](https://www.apptweak.com/en/reports/app-market-size-by-app-category) |
| Productivity apps market | $13.15 B (2025) → $14.46 B (2026), ~9.9 % CAGR | [Fortune Business Insights](https://www.fortunebusinessinsights.com/productivity-apps-market-110254) |
| App Store vs Google Play revenue 2025 | $117 B vs $49 B | [Quash](https://quashbugs.com/blog/ios-vs-android-market-share-statistics) |
| Spend per user per month | iOS $10.40 vs Android $1.40 | [Tekrevol](https://www.tekrevol.com/blogs/android-vs-ios-statistics/) |

**Practical read:** expect roughly 70–75 % of downloads from Android and 70–80 % of revenue from
iOS. Design the paywall for iOS first.

**MENA:** downloads grew 2.6 % YoY in Q2 2025 vs 0.5 % worldwide; in-app purchases reached $700 M,
+20 % YoY ([Sensor Tower](https://sensortower.com/blog/middle-east-app-growth-report)). GCC IAP
revenue +41 % Q1 2024 → Q1 2026 ([Bidease](https://www.bidease.com/blog/inside-the-2026-middle-east-app-growth-report)).
Jordan is not a standalone Apple financial region (it reports under "Rest of World", USD). Treat
Jordan as the test bed and Gulf Arabic speakers (UAE, KSA, Kuwait, Qatar) as the paying MENA audience.

## 3. Monetization benchmarks

RevenueCat 2026 (115,000 apps, $16 B) — [source](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026):

| Benchmark | Number |
|---|---|
| Install → paid at D35, hard paywall | 10.7 % median |
| Install → paid at D35, freemium | 2.1 % median |
| Revenue per install at D60, freemium | $0.38 |
| Trial 17–32 days → paid | 42.5 % |
| Trial < 4 days → paid | 25.5 % |
| Year-1 LTV per payer, productivity | $24.95 median |
| Productivity: share converting on day 0 | 71.9 % |

Adapty 2026 — [source](https://adapty.io/state-of-in-app-subscriptions/): install → trial 10.9 %,
trial → paid 25.6 %, median prices $12.99 / month and $38.42 / year, D380 retention annual 19.9 %
vs monthly 14.2 % vs weekly 5.5 %.

Churn to plan for: ~72 % of annual subscribers cancel within year one; on Google Play 31 % of
cancellations are involuntary billing failures (configure grace periods).

### Model scorecard for I'm Done

| Model | Verdict |
|---|---|
| Freemium + subscription | **Yes.** Generous free tier so the invite loop keeps working; 14-day trial on Pro. |
| Lifetime | **Yes, as a third option** ($49.99). Converts the subscription-averse, common in MENA. |
| Ads | **No.** MENA-heavy audience at ~$1–3 interstitial eCPM earns ~$0.02–0.05 / user / month and destroys the "simple, beautiful" positioning ([RevenueLab eCPM benchmarks](https://www.revenuelab.fyi/blog/admob-ecpm-benchmarks-2026)). |
| Rewarded video | One narrow use only: "watch to unlock one extra group this week". |
| Family plan | **Natural fit** (Apple Family Sharing, up to 5). Note it cannot be disabled once enabled. |
| Pay per shared group | **No.** It punishes the behaviour that drives growth. |
| B2B / team tier | Year 2+. Clinics and small businesses in Amman are a real wedge for "assign → nag → confirm". |

### Recommended free / Pro split

| Capability | Free | Pro |
|---|---|---|
| Voice capture → task | Unlimited | Unlimited |
| Personal tasks | Unlimited | Unlimited |
| Active recurring tasks | 5 | Unlimited |
| Nagging reminders | 3 active, max 3 repeats each | Unlimited, custom intervals |
| Shared groups you CREATE | 1 group, up to 3 people | Unlimited |
| Joining someone else's group | **Always free** | Always free |
| History | 7 days | Full + per-member stats |
| Themes, sounds, widgets | Basic | All |

**The rule that matters:** the person who creates groups pays; the people they invite are the
acquisition channel. Gate creation, never participation. Do not meter voice minutes: on-device
speech costs nothing per use and metering the headline feature makes the app feel stingy.

### Pricing

| Tier | US / EU / Gulf | MENA (JO, EG, IQ, LB, MA) |
|---|---|---|
| Monthly | $3.99 | $1.49 |
| Annual | $19.99 | $7.99 |
| Lifetime | $49.99 | $19.99 |

Undercut the productivity annual median ($29.99–38.42) deliberately; the app is one idea done
well. Skip weekly plans: highest revenue on paper but 5.5 % D380 retention and refund-driven
1-star reviews. Use the stores' regional price tiers rather than separate SKUs.

Competitor prices: TickTick $35.99/yr; Todoist Pro $60/yr; Any.do ~$50/yr; Structured lifetime
$99.99; Habitify $39.99/yr; Streaks $5.99 once; Due ~$7.99 once; Galarm $9.99/yr or $24.99 lifetime.

## 4. Store fees, plumbing, and payouts to Jordan

| Item | Detail |
|---|---|
| Apple commission | 15 % under the [Small Business Program](https://developer.apple.com/app-store/small-business-program/) — **must apply**, not automatic |
| Google commission | 15 % on the first $1 M / year, automatic |
| Apple Developer Program | $99 / year |
| Google Play Console | $25 once |
| RevenueCat | [Free under $2,500 monthly tracked revenue](https://www.revenuecat.com/pricing), then 1 % |
| External payment links | Not worth it below ~$100k/yr (US: ~15 % commission within 7 days of tapping, per the Dec 2025 ruling; EU: new layered model from Jan 2026) |

**Google Play payouts to Jordan: confirmed.** Jordan is listed for developer AND merchant
registration ([supported locations](https://support.google.com/googleplay/android-developer/answer/9306917))
and for wire-transfer payouts ([payout locations](https://support.google.com/googleplay/android-developer/answer/2700656)),
USD, $100 minimum.

**Apple payouts to Jordan: not confirmable from public documentation.** Apple publishes no list
of supported bank territories; the minimum payout for unlisted bank countries is $40
([Apple](https://developer.apple.com/help/app-store-connect/reference/reporting/minimum-payment-threshold)).
**Action before spending on marketing:** enrol ($99), sign the Paid Applications Agreement,
open App Store Connect → Business → Bank Accounts and check whether Jordan is selectable and
the bank resolves. If not, the usual fallbacks are a USD account in a supported jurisdiction or
a Gulf-registered entity.

**Tax:** Jordan has no US tax treaty, but Apple/Google treat app sales as sales, not royalties,
so US withholding generally does not apply; file W-8BEN(-E) regardless. Jordan side: personal
income tax up to 30 %, corporate 20 %, GST 16 %
([Deloitte Jordan highlights 2025](https://www.deloitte.com/content/dam/assets-shared/docs/services/tax/2025/dttl-tax-jordanhighlights-2025.pdf)).
Confirm with a Jordanian tax advisor.

## 5. Growth with no budget, and honest first-year numbers

Median subscription-app revenue after 12 months is under $50 / month; only 17.2 % of apps reach
$1,000 / month and 3.5 % reach $10,000 MRR (RevenueCat). Adapty: 59.3 % of apps never make
$1,000 in total.

| Scenario | Y1 downloads | Paying subs | Y1 net revenue |
|---|---|---|---|
| Pessimistic (likeliest) | 3,000–8,000 | 40–120 | $500–2,000 |
| Base | 15,000–30,000 | 250–600 | $4,000–10,000 |
| Good (one viral moment) | 60,000–150,000 | 1,200–3,000 | $20,000–55,000 |

Comparable: [Habit Pixel](https://www.indiehackers.com/post/from-0-to-1k-mrr-in-8-months-bootstrapping-habit-pixel-as-a-solo-dev-684b6c056d)
went $0 → $1K MRR in 8 months solo.

The four things worth the time:

1. **The invite loop is the paid acquisition.** Creator shares a WhatsApp link → invitee installs
   → later creates their own group → hits the free limit → converts. Instrument K-factor from day one.
2. **Arabic ASO.** Localized listings convert 35–50 % better and Arabic to-do keywords are
   under-contested ([AppTweak](https://www.apptweak.com/en/aso-blog/app-store-keyword-research-aso)).
   Targets: `تذكير بالمهام`, `منبه مهام`, `قائمة مهام صوتية`, `مهام مشتركة للعائلة`; English
   `nagging reminder`, `voice to task`, `reminder that repeats until done`, `shared family chores`.
3. **TikTok / Reels demos in Arabic.** Hold the button, say "اشتري حليب بكرة الساعة ٦", task appears,
   alarm nags until done — a 12-second video that costs nothing.
4. **Position on the nag, not the list.** "The reminder that won't shut up until you actually do it"
   plus "your mother marked it done — confirm?" is a wedge no major competitor occupies.

# Technical Documentation — Personal Finance & Expense Tracker (Android)

> **Purpose of this file:** A complete, implementation-ready specification for a Claude coding agent to build the app. It defines the architecture, module breakdown, data model, screen specs, design system, and a recommended build order. Follow it top to bottom.

---

## 1. Product Summary

A **local-first, offline** Android personal-finance app for Arabic-speaking users (Egypt & MENA focus). No backend, no cloud, no internet permission initially. Priorities: fast expense entry, strong analytics, polished Arabic RTL, clean modern UI.

**Non-negotiables**
- Works 100% offline (Room is the single source of truth).
- Full Arabic RTL + English, with runtime language switching.
- Light / Dark / System themes, Material 3.
- Adding an expense takes a few seconds and minimal taps.
- Handles thousands of transactions without UI lag (paging + Flow).

---

## 2. Tech Stack (fixed)

| Concern | Choice |
|---|---|
| Language | Kotlin |
| UI | Jetpack Compose + Material 3 |
| Architecture | Clean Architecture + MVVM + Repository |
| DI | Hilt |
| Persistence | Room (with KSP) |
| Async | Coroutines + Flow / StateFlow |
| Navigation | Navigation Compose |
| Paging | Paging 3 (Room-backed) |
| Charts | Vico (Compose-native) — or MPAndroidChart via interop if needed |
| Date/Time | `java.time` (desugaring enabled) |
| Preferences | DataStore (Preferences) |
| Notifications | WorkManager + NotificationManager |
| CSV export | Manual writer to app-scoped storage / SAF |
| Min SDK | 24 · Target SDK | latest stable |

Use **version catalogs** (`libs.versions.toml`). Enable core library desugaring.

---

## 3. Module / Package Structure

Single Gradle module to start, organized by Clean Architecture layers, **feature-first** inside each layer.

```
com.app.finance
├── core/
│   ├── designsystem/        // theme, color, typography, reusable Compose components
│   ├── common/              // Result, dispatchers, extensions, formatters (money, dates, Arabic digits)
│   └── navigation/          // NavHost, routes, bottom bar
├── data/
│   ├── local/
│   │   ├── db/              // AppDatabase, DAOs, TypeConverters, Migrations
│   │   ├── entity/          // Room @Entity classes
│   │   └── datastore/       // SettingsDataStore
│   ├── mapper/              // entity <-> domain mappers
│   └── repository/          // Repository implementations
├── domain/
│   ├── model/               // pure Kotlin domain models
│   ├── repository/          // repository interfaces
│   └── usecase/             // one class per use case
├── feature/
│   ├── dashboard/           // screen + viewmodel + ui state
│   ├── transactions/
│   ├── addedit/
│   ├── categories/
│   ├── accounts/
│   ├── budgets/
│   ├── analytics/
│   ├── search/
│   ├── settings/
│   └── onboarding/
├── work/                    // WorkManager workers (recurring tx, reminders)
└── di/                      // Hilt modules
```

**Rule:** `feature` depends on `domain`; `data` implements `domain`; `domain` depends on nothing. ViewModels expose a single immutable `UiState` via `StateFlow` and receive events via functions.

---

## 4. Data Model (Room)

Use normalized design, foreign keys with indices, soft constraints where deletion should cascade or restrict.

### Entities

**Account**
| field | type | notes |
|---|---|---|
| id | Long PK autoGen | |
| name | String | |
| type | enum: CASH, BANK, CREDIT_CARD, WALLET, VODAFONE_CASH, INSTAPAY | stored as String |
| currency | String | ISO-ish code (EGP default) |
| initialBalance | Long | **store money as minor units / cents (Long)** |
| colorHex | String | |
| iconKey | String | |
| archived | Boolean | default false |

> Current balance is **derived** (initialBalance ± transactions), not stored, to avoid drift. Provide a DAO query that computes it.

**Category**
| id | Long PK | |
| name | String | |
| parentId | Long? FK -> Category.id | null = main category |
| type | enum: EXPENSE, INCOME | |
| colorHex | String | |
| iconKey | String | |
| isDefault | Boolean | seeded defaults are non-deletable |

**Transaction**
| id | Long PK | |
| amount | Long | minor units, always positive |
| type | enum: EXPENSE, INCOME, TRANSFER | |
| categoryId | Long? FK | null for transfers |
| accountId | Long FK | source account |
| toAccountId | Long? FK | only for TRANSFER |
| dateTime | Long (epoch millis) | indexed |
| note | String? | |
| attachmentPath | String? | local file path |
| recurringId | Long? FK -> RecurringRule.id | set if generated from a rule |
| latitude / longitude | Double? | future-ready, optional |

**Tag**: `id`, `name` (unique).
**TransactionTagCrossRef**: `transactionId`, `tagId` (composite PK) — many-to-many.

**Budget**
| id | Long PK | |
| categoryId | Long? FK | null = overall budget |
| amount | Long | minor units |
| period | enum: WEEKLY, MONTHLY, CUSTOM | |
| startDate / endDate | Long | for CUSTOM |
| carryOver | Boolean | |

**RecurringRule**
| id | Long PK | |
| templateAmount | Long | |
| type | enum | |
| categoryId / accountId | FK | |
| interval | enum: DAILY, WEEKLY, MONTHLY, YEARLY | |
| nextRunDate | Long | indexed; WorkManager scans this |
| note | String? | |

**Settings** → use **DataStore**, not Room: language, theme mode, currency, weekStartDay, budgetStartDay, numberFormat (ARABIC/ENGLISH digits), appLockEnabled.

### Relationships
- Account 1—* Transaction
- Category 1—* Transaction; Category self-ref (parent/child) for subcategories
- Transaction *—* Tag (cross-ref table)
- Budget *—1 Category (optional)
- RecurringRule 1—* Transaction

Provide Room `@Relation` POJOs: `TransactionWithDetails` (tx + account + category + tags) for list/detail rendering.

### Money & numbers
- Store all money as **Long minor units**. Never use Float/Double for money.
- A central `MoneyFormatter` formats minor units → display string honoring currency + Arabic/English digit setting.
- A central `DateFormatter` produces Arabic/English dates and respects RTL.

---

## 5. Use Cases (domain)

Minimum set — one class each, suspend or Flow-returning:

- Transactions: Add, Edit, Delete, Duplicate, GetPaged, Search, FilterByQuery.
- Accounts: CRUD, Transfer, GetWithComputedBalance, GetAccountHistory.
- Categories: CRUD, GetTree (main + subcategories), SeedDefaults.
- Budgets: CRUD, GetBudgetProgress (spent vs limit, remaining, % , over-budget flag).
- Analytics: GetSummary(period), GetSpendingByCategory, GetTrendOverTime, GetInsights (top category, highest day, daily avg, MoM delta).
- Recurring: CRUD rules, GenerateDueTransactions.
- Export: ExportTransactionsCsv(filter).
- Settings: observe + update via DataStore.

`FilterQuery` is a single data class combining: date range, transaction types, accountIds, categoryIds, tagIds, text, amount range. All list screens consume the same filter object.

---

## 6. Screens & Navigation

Bottom nav (4 tabs) + center FAB for quick add. RTL: nav order mirrors automatically.

**Routes**
```
splash → onboarding (first launch only) → main
main { dashboard | transactions | analytics | settings }   // bottom nav
addEdit?txId={id}        // null id = create
categories
accounts
budgets
search
accountDetail/{id}
```

### Screen specs (key ones)

**Dashboard**
- Header: greeting + current balance (computed), income/expense pills for current month.
- Summary metric cards (2-col grid): remaining budget (with progress bar), monthly spending (with MoM %), savings.
- Smart insight banner (highest category, MoM change).
- Recent transactions list (latest ~8) with icon, category, account, date, signed amount.
- FAB → Add Transaction.

**Add/Edit Transaction (quick-add optimized)**
- Big numeric amount input focused on open, with on-screen keypad feel.
- Segmented type selector (Expense / Income / Transfer).
- Horizontal scrollable category chips (recent first); "+" to manage.
- Account selector; for Transfer show source + destination.
- Collapsible "more": date/time, note, tags, attachment, recurring toggle + interval.
- Single primary Save; default date = now, default account = last used. Target: amount → category → save.

**Transactions List**
- Paging 3 list grouped by day with daily totals.
- Sticky filter/search bar; swipe actions: edit / delete; long-press: duplicate.

**Analytics**
- Period selector: Day / Week / Month / Quarter / Year / Custom / All.
- Pie (category distribution), Line (trend over time), Bar (period or category comparison).
- Insight cards. Category & account multi-select filters. Export CSV button.

**Categories** — tree list (expand main → subcategories), add/edit with icon + color picker.
**Accounts** — cards per account with computed balance; transfer action; account detail = its transaction history.
**Budgets** — per-budget progress bars, over-budget red state, carry-over indicator.
**Settings** — language, currency, theme, week start, budget start day, digit format, (future) app lock.
**Onboarding** — 3 slides + currency/language pick; seed default categories on finish.

---

## 7. Design System

**Primary color: mint green.** Build a Material 3 color scheme around it; support light & dark.

```
Mint (primary):        #16B981
Mint dark (on-tint):   #0F6E56
Mint container (light):#E1F5EE
Mint container (alt):  #D2F0E5
Expense (negative):    #D85A30   (coral)
Income (positive):     #16B981   (mint)
Info/neutral accent:   #185FA5
Warning:               #BA7517
```

- Material 3 dynamic-color optional; default brand scheme uses mint as `primary`.
- Shapes: rounded cards (12–16dp radius), pill chips, 52dp circular FAB.
- Typography: Material 3 type scale; bundle an Arabic-friendly font (e.g. Cairo / IBM Plex Sans Arabic) and apply across the app; weights 400/500 mainly.
- Motion: subtle — screen transitions, expanding cards, FAB, chart load. Nothing flashy.
- Build reusable Composables in `core/designsystem`: `MoneyText`, `TransactionRow`, `SummaryCard`, `CategoryChip`, `ProgressBudgetBar`, `SectionHeader`, `AppScaffold`.

**RTL requirements**
- App-wide locale switching at runtime (per-app language via `AppCompatDelegate.setApplicationLocales` or `LocaleManager`).
- Use `start`/`end` (not left/right) everywhere; test every screen mirrored.
- Number formatting respects Arabic vs English digit setting.
- All strings in `strings.xml` (`values/` + `values-ar/`). No hardcoded UI text.

---

## 8. Background Work (offline)

- **Recurring transactions:** a daily periodic `CoroutineWorker` scans `RecurringRule.nextRunDate <= today`, generates transactions, advances `nextRunDate`. Idempotent.
- **Notifications (all local):** budget exceeded (check after each relevant write), recurring payment due, daily expense reminder, weekly summary. Use WorkManager for scheduled ones; NotificationManager channels for each category.
- No network. Notifications must fire offline.

---

## 9. Performance

- Room queries return `Flow`; lists use **Paging 3** (`PagingSource` from DAO).
- Do aggregation in SQL (SUM/GROUP BY) for analytics, not in Kotlin loops.
- Indices on `Transaction.dateTime`, `accountId`, `categoryId`, `recurringId`.
- Avoid recomposition storms: stable `UiState`, `key`-ed lazy lists, remember derived values.

---

## 10. Security / Privacy

- No `INTERNET` permission in the manifest initially.
- Data stays in app-private storage; attachments under app-scoped files.
- Architecture-ready (not required v1) for app lock: PIN/biometric gate at app start, encrypted DB via SQLCipher behind a repository flag.

---

## 11. Future-Ready (design for, don't build)

Keep boundaries clean so these can be added later without rewrites:
- Cloud sync (repository already abstracts source → add remote + sync layer).
- AI insights, OCR receipt scanning, multi-device sync, web/desktop.
- Savings goals & debt tracking (borrowed/lent + due dates) — model can extend Budget/Transaction with new entities.

---

## 12. Seed / Sample Data

On first run seed: default categories (Food→Restaurants/Coffee/Groceries, Transportation, Shopping, Entertainment, Health, Bills, Education, Home, plus income: Salary, Freelance, Investments), one Cash account, one Bank account. Provide a debug `SampleDataSeeder` that inserts a few hundred dummy transactions for testing analytics & paging.

---

## 13. Recommended Build Order

1. Project skeleton: Gradle, version catalog, Hilt, theme (mint), navigation shell with empty screens + bottom bar + FAB.
2. Room: entities, DAOs, DB, converters, mappers, repositories, default-data seeder.
3. Domain: models + use cases + repository interfaces wired through Hilt.
4. Add/Edit Transaction (quick-add) — the core flow — end to end.
5. Transactions list (Paging 3, grouped, search/filter).
6. Accounts + transfers + computed balances.
7. Categories (tree, custom icons/colors).
8. Dashboard (summary cards, insights, recent).
9. Budgets (progress, over-budget, carry-over).
10. Analytics (charts + filters + insights + CSV export).
11. Recurring + WorkManager + notifications.
12. Settings (language switch, theme, currency, digit format, week/budget start).
13. Onboarding + splash, polish, animations, RTL/dark audit on every screen.

**Definition of done per screen:** compiles, RTL-correct, light+dark correct, no hardcoded strings, state survives rotation, no main-thread DB work.

---

## 14. Coding Standards

- Clean, modular, documented where non-obvious. Reusable Composables.
- One `UiState` per screen; events as ViewModel functions; no business logic in Composables.
- No money as Double. All strings externalized. `start/end` not `left/right`.
- Unit-test use cases and DAOs; preview Composables in both locales and themes.

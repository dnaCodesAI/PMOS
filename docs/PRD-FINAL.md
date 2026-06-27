# PRD: Goal Progress Feedback Loop

**Product:** Lakeview Bank — Savings Goals (mobile)  
**Author:** Lead PM, Digital Banking  
**Status:** Final  
**Scope:** Give customers clear, plain-language feedback on whether they are on pace to reach their savings goal — on the goal detail screen only.

---

## 1. Problem Statement

Lakeview Bank customers who use Savings Goals set a target amount and deadline during onboarding, then open the goal once and rarely come back. When they do open it, they see how much they have saved — but nothing that tells them whether that amount is enough given the time left. They cannot tell whether they are making enough progress to hit their deadline without doing their own math against a target date they may not remember.

That uncertainty removes the reason to return. If the app cannot answer "Am I going to make it?", the goal feels like a static label, not something worth checking. Customers disengage from the feature, and the bank loses a retention touchpoint that could keep mobile users active through day 90 and beyond.

This problem affects active mobile savers who already set one to three goals at onboarding — not customers who have never created a goal.

---

## 2. Press Release

**FOR IMMEDIATE RELEASE — Lakeview Bank Savings Goals now shows whether you're on track**

**Chicago, IL — [Date]** — Lakeview Bank today updated its mobile Savings Goals feature so customers can see at a glance whether they are on pace to reach each goal — without calculating monthly targets themselves.

When a customer opens a savings goal, the app now shows a plain-language status such as "You're on track" or "You're $120 behind pace for June," based on their saved amount, target, and deadline. The update gives customers a reason to check back on their goals and adjust their saving habits while everything stays inside the Lakeview mobile app they already use.

"Savings Goals was only useful if customers came back — and they weren't coming back because we never told them if they were winning," said [Name], Head of Digital Banking at Lakeview Bank. "This turns goal-setting from a one-time setup into a weekly habit."

Goal Progress Status is available now to eligible customers on the Lakeview mobile app for iOS and Android.

---

## 3. Internal FAQ

**1. Does this require a data model migration?**

No migration. Engineering confirmed in #abc-bank-prd-review (Jun 27): *"avoid data migration at all costs."* Pace status is a derived value computed at read time from existing goal fields only: `target_amount`, `current_amount`, `deadline`, and `created_at`. No new persisted columns, no backfill job, no schema change. If any required field is missing on legacy goals, the feature degrades gracefully (hide pace label; show amount-vs-target only) — it does not block ship on a migration.

**2. How is pace calculated?**

Linear expected progress by elapsed calendar days:

```
days_total   = deadline - created_at
days_elapsed = today - created_at
expected     = target_amount × (days_elapsed / days_total)
gap          = current_amount - expected
```

Status thresholds are defined in Acceptance Criteria (Section 6). "Stalled" is a separate signal based on deposit activity, not the linear formula alone.

**3. What happens when balance data is stale or the fetch fails?**

Goal detail reads from a **cached balance snapshot** — not a live core banking call on every view (see Engineering Constraints). The progress status component is hidden if the snapshot is unavailable. The screen shows an error state with copy ("We couldn't load your latest balance") and a Retry action. A "Last updated [timestamp]" label is shown whenever balance data is displayed. Pace status is never rendered from a snapshot older than **30 minutes** without surfacing the stale-data indicator.

**4. What happens when a goal is deleted, has a zero target, or has no deadline?**

| Condition | Behavior |
|-----------|----------|
| Goal deleted | Detail screen closes; no status component rendered |
| `target_amount = 0` | Hide progress status; show progress bar only |
| No deadline set | Hide pace label; show saved amount vs. target only ("$800 of $2,000 saved") |

No silent empty states. No crash.

**5. What analytics events should we instrument?**

| Event | Properties |
|-------|------------|
| `goal_detail_viewed` | `goal_id`, `has_deadline`, `days_remaining` |
| `progress_status_shown` | `goal_id`, `status` (on_track \| ahead \| behind \| stalled \| complete) |
| `progress_status_error` | `goal_id`, `error_type` (fetch_failed \| stale_data \| invalid_goal) |
| `progress_status_retry_tapped` | `goal_id` |

---

## Engineering Constraints

**Source:** #abc-bank-prd-review — Sairam (Engineering), May 15 & Jun 27 2026

**Hard constraint — Core banking API rate limit:** **50 requests/minute per customer session**, immovable until Q3. Goal Progress Status must be designed against this ceiling.

- **No synchronous core banking calls on goal detail load.** Balance and deposit signals read from a **local/edge snapshot store**, not live core API per view.
- **Async refresh model.** A background worker refreshes per-customer snapshots on a cadence (every **15 minutes** during active sessions; hourly when idle) and on transaction-posted events where available.
- **Client-side pace recompute.** Status labels and dollar gaps recompute **client-side** against the cached snapshot. Core API is hit only on explicit **manual refresh** (counts against session rate budget).
- **Per-session rate budget:** target peak usage **≤30 req/min** per session to leave headroom for auth, transfers, and retries; alert if any session class exceeds **40 req/min p95**.
- **Graceful degradation on 429.** Serve cached snapshot + non-blocking banner; never block goal viewing or editing.
- **No data migration.** Use existing goal fields only; no schema changes or backfill (Jun 27).

---

## 4. Customer FAQ

**1. How does Lakeview know if I'm on track?**

The app compares how much you've saved to how much you'd need to have saved by today to reach your goal by the deadline you set. It uses your linked account balance and the target and date you entered when you created the goal.

**2. If I'm behind, will the app move money for me?**

No. Goal Progress Status is informational only. It does not initiate transfers, change your accounts, or move money without your explicit action through existing transfer flows.

**3. What if my balance hasn't updated yet?**

You'll see when your balance was last updated. If we can't load your current balance, we'll let you know and ask you to try again — we won't show a status that might be wrong.

**4. Can I change my goal and see the status update?**

Yes. If you edit your target amount or deadline, the status recalculates immediately on the next view using your updated goal details and current saved amount.

**5. Is this financial advice?**

No. This is a progress indicator based on the goal you set and your account balance. It is not a recommendation about how much to save or whether you should change your financial plans. For personalized guidance, contact Lakeview Bank directly.

---

## 5. User Stories

**US-1 — On-track feedback (primary persona)**

Given I have an active savings goal with a target, deadline, and linked account balance  
When I open the goal detail screen  
Then I see a plain-language pace status (e.g., "You're on track to reach your goal by [deadline]")  
And I see the dollar amount I have saved and my target without needing to calculate anything myself

**US-2 — Behind pace**

Given my current saved amount is more than 5% below the linear expected amount for today  
When I open the goal detail screen  
Then I see a status indicating I am behind pace  
And I see the dollar gap (e.g., "You're $120 behind pace") — not a percentage alone

**US-3 — Stale or failed balance load**

Given the cached balance snapshot is unavailable or older than 30 minutes  
When I open the goal detail screen  
Then the pace status is not shown  
And I see an error or stale-data message with a Retry option  
And I see the last-updated timestamp if any cached balance is displayed

**US-4 — Goal complete**

Given my current saved amount is greater than or equal to my target amount  
When I open the goal detail screen  
Then I see a "Goal complete" status  
And no behind/ahead/stalled label is shown

**US-5 — Goal without deadline**

Given I have a savings goal with a target amount but no deadline set  
When I open the goal detail screen  
Then I see my saved amount vs. target (e.g., "$800 of $2,000 saved")  
And no pace status label is shown

**US-6 — Existing goal (pre-ship)**

Given I created a savings goal before this feature shipped  
When I open the goal detail screen after release  
Then I see the same progress status behavior as newly created goals  
And the calculation uses my original `created_at` and stored deadline

---

## 6. Acceptance Criteria

### Pace calculation

- [ ] **AC-1:** `expected_amount = target_amount × (days_elapsed / days_total)`, where `days_elapsed` and `days_total` are whole calendar days and `days_elapsed` is capped at `days_total`
- [ ] **AC-2:** `gap = current_amount - expected_amount` (positive = ahead, negative = behind)

### Status labels and thresholds

- [ ] **AC-3:** Status = **Complete** when `current_amount >= target_amount`
- [ ] **AC-4:** Status = **Ahead** when `gap > target_amount × 0.05` (more than 5% of target above expected)
- [ ] **AC-5:** Status = **On track** when `gap` is between `-target_amount × 0.05` and `+target_amount × 0.05` inclusive
- [ ] **AC-6:** Status = **Behind** when `gap < -target_amount × 0.05`
- [ ] **AC-7:** Status = **Stalled** when the cached snapshot shows no deposit to the linked account in 14+ calendar days AND status would otherwise be Behind or On track (deposit signal read from snapshot store — no live core API poll on view)

### Display (Designer — no mental arithmetic)

- [ ] **AC-8:** Behind and Ahead states display the **absolute dollar gap** in primary copy (e.g., "You're $120 behind pace" / "You're $85 ahead of pace")
- [ ] **AC-9:** On track state displays deadline in plain language (e.g., "You're on track to reach your goal by December 15")
- [ ] **AC-10:** Percentages may appear as secondary text but must not be the only indicator of pace

### Error and edge states (Compliance — never silently fail)

- [ ] **AC-11:** If balance fetch fails, pace status is hidden; error copy and Retry button are shown; `progress_status_error` event fires with `error_type = fetch_failed`
- [ ] **AC-12:** If snapshot age is >30 minutes, pace status is hidden; stale-data copy and timestamp are shown; `progress_status_error` fires with `error_type = stale_data`
- [ ] **AC-13:** If `target_amount = 0`, pace status component is not rendered
- [ ] **AC-14:** If deadline is null, pace status label is not rendered; amount-vs-target display still works
- [ ] **AC-15:** If goal is deleted while detail screen is open, user is returned to goal list with no crash

### Data model (Maya — no migration)

- [ ] **AC-16:** Pace status is computed at read time; no new database columns required for MVP
- [ ] **AC-17:** Existing goals with valid `target_amount`, `current_amount`, `deadline`, and `created_at` render progress status without manual backfill

### Platform and recalculation

- [ ] **AC-18:** Given identical goal data (`target_amount`, `current_amount`, `deadline`, `created_at`) and balance freshness, iOS and Android render the same status label (Complete, Ahead, On track, Behind, or Stalled per AC-3–AC-7) and the same dollar-gap value in primary copy (AC-8)
- [ ] **AC-19:** Editing target or deadline recalculates status on next screen load without app restart

### Engineering constraints (rate limit and snapshot architecture)

- [ ] **AC-20:** Opening goal detail does **not** call the core banking balance API; `current_amount` is read from the cached snapshot only
- [ ] **AC-21:** Pace status and dollar gap recompute client-side from snapshot + goal fields within 1 second (p95); no core API call on recompute
- [ ] **AC-22:** Manual Refresh triggers one snapshot refresh request; button is disabled with explanatory tooltip when session rate budget is exhausted
- [ ] **AC-23:** On core API 429 response, goal detail still renders from last cached snapshot with a non-blocking banner; pace status is hidden if snapshot age exceeds AC-12 threshold
- [ ] **AC-24:** Telemetry alerts when any session class exceeds 40 req/min p95 during goal-detail flows

---

## 7. Success Metrics

**Primary metric:** 30-day return rate to goal detail view among users who created at least one goal in the prior 30 days.

| | Value |
|---|-------|
| Baseline | 20% |
| Target | Statistically significant lift vs. control in 4-week A/B test; milestone toward 80% north star |

**Counter-metric:** Rate of goal deletion within 7 days of viewing progress status, plus support tickets tagged "incorrect goal status" — must not increase vs. control. Guards against false confidence from wrong pace calculations.

**Secondary leading indicators:**
- Median time on goal detail screen
- Return frequency (sessions with goal detail view per user per 30 days)

**Lagging business outcome (executive):** 90-day mobile retention improvement — David Okonkwo's committed +8 point target. Not the primary experiment readout; measured over quarters post-ship.

---

## 8. Out of Scope

- Push notifications and milestone alerts (requires build-vs-integrate decision; Priya Santos owns GTM copy separately)
- Empty state and onboarding prompt for users with zero goals
- AI-generated or personalized coaching copy
- Automatic transfers, round-ups, or any action that moves money
- Multi-goal summary card on the home feed
- Web and desktop banking
- Editable pace assumptions (e.g., custom monthly contribution targets)
- Social sharing or household visibility of goal status

---

## Compliance

This feature is customer-facing in a regulated banking context. The following requirements are mandatory for ship and map to the edge-case acceptance criteria in Section 6.

- **No silent failures.** Every error, stale, or invalid-goal state renders explicit copy and a recovery path — never an empty or misleading view (AC-11 through AC-15).
- **No stale data shown as current.** Pace status is never rendered from snapshot data older than 30 minutes without a visible stale-data indicator and last-updated timestamp (AC-12). On fetch failure, the status is suppressed entirely (AC-11).
- **Informational only — not financial advice.** Goal Progress Status is a progress indicator, not a recommendation or advice. It never initiates transfers or moves money without explicit customer action through existing flows (Customer FAQ #2, #5; Out of Scope).
- **Deterministic, auditable calculation.** Status derives from a fixed linear formula over stored goal fields (Section 3, AC-1/AC-2) and renders identically across iOS and Android for identical inputs (AC-18), so any displayed status is reproducible for audit.
- **No new PII or persisted derived state.** Pace status is computed at read time from existing fields; no new customer data is collected or stored for MVP (AC-16/AC-17).
- **Auditable instrumentation.** Status-shown and error events are logged with `goal_id`, `status`, and `error_type` (Section 3, Analytics) to support post-ship monitoring of incorrect-status reports (Counter-metric, Section 7).

**Sign-off required before release:** Banking/Compliance review of customer-facing copy and error states.

---

## Open Questions for Engineering Sign-off

1. Confirm existing goal schema includes `target_amount`, `current_amount`, `deadline`, and `created_at` on all in-flight goals — if a field is missing, confirm graceful degradation path (no migration).
2. Is the balance/transaction **snapshot store** already in place, or net-new work for this sprint?
3. Are transaction-posted webhooks reliable enough to refresh snapshots between 15-min cadence, or is batch refresh the source of truth?
4. Confirm deposit-activity signal for "Stalled" (AC-7) is available in the snapshot store with 14-day lookback — not via live core API poll.

# Decision: Transactions Pagination Loop Belongs in TransactionsFetchService

**Date**: 2026-04-21
**Status**: Accepted
**Milestone**: 4 — AIS Rails Implementation (PR #37)

## Context

The Artea sandbox supports cursor-based pagination for `GET /accounts/{id}/transactions` via a
`paginated=1` query parameter. When enabled, each response returns up to 50 transactions and
may include `_links.next.href` pointing to the next page. The implementation needed to decide
which layer owns the pagination loop and how to bound memory usage.

An initial approach placed `fetch_all_pages` inside `SaltEdge::TransactionsService`, accumulating
all pages into a single array before returning. This was rejected because it defeats the purpose
of pagination: the full result set is loaded into memory at once, reintroducing the OOM risk
that pagination is meant to prevent.

## Decision

**`SaltEdge::TransactionsService` is a thin, single-page HTTP client.**

It exposes two public methods:
- `#transactions(...)` — non-paginated; returns the `transactions` hash directly (backward
  compatible with `AisTransactionsController`).
- `#transactions_page(...)` — single-page fetch for use in paginated iteration; returns
  `{ transactions: {...}, next_href: String | nil }`. When `path:` is given, it is used
  verbatim (for following `_links.next.href`); otherwise the initial URL is built and
  `&paginated=1` is appended.

**`SaltEdge::TransactionsFetchService` owns the pagination loop and persistence.**

`#fetch_and_persist` delegates to `#persist_pages` when `paginated: true`:
1. Delete all existing pending transactions for the account upfront (once).
2. Loop: fetch one page via `TransactionsService#transactions_page`, upsert booked records,
   create pending records for this page, then break if `next_href` is blank.
3. Accumulate only an integer counter — not the records themselves.
4. Return the total count of persisted transactions.

## Consequences

- Memory is bounded to one page at a time regardless of result set size.
- `TransactionsService` remains independently testable as a pure HTTP adapter.
- `TransactionsFetchService` controls persistence order and can be extended (e.g., with
  ActiveJob wrapping) without changing the HTTP layer.
- `fetch_and_persist` returns an `Integer` in both paginated and non-paginated paths, giving
  the caller a consistent interface for the success notice.
- The `paginated` query parameter accepts `1`/`0` — **not** `true`/`false`. Using `true`
  causes a Salt Edge validation error. The `paginated: true` Ruby keyword on
  `fetch_and_persist` is translated to `&paginated=1` in the URL by `TransactionsService`.

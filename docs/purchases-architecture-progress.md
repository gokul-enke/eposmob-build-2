# Purchases architecture migration

Implementation and local architecture verification are complete. See
`lib/features/purchases/README.md` for ownership, the public surface, navigation,
checklist and validation boundaries.

The order list, create/receive form, order details, legacy purchase/voucher lists,
legacy Add Purchase and voucher details now live in `lib/features/purchases/`.
Models, injected transport, parsing, repositories, draft storage, provider facade,
controllers and passive widgets have been separated. Shared callers and named
navigation retain their compatibility and original screen positions.

Review fixed disposal/draft races, duplicate legacy commands and the Reset during
initial directory loading sequence. Regression tests cover these paths.
Before/after screenshots at 375/1280 were pixel-identical for all seven screens;
existing overflow diagnostics matched the baseline.

Full tests: 2,278 passed, 2 skipped, the same existing standard PDF contract failure.
Analysis: zero errors, no new warnings, 3,636 diagnostics versus 3,643 baseline.
Final focused regressions: 54 passed.
No live API, production-font or Windows build acceptance is implied.

The existing unrelated pubspec.lock modifications are not part of this change.
This is an architecture migration; existing responsive UI defects remain for the
separate UI work. Review/merge acceptance is still required.

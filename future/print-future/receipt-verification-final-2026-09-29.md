# Print verification result — 29 September 2026

Rendered-output verification is complete. Full configured-field completeness
remains blocked by missing API text and real business data. Backend code was
not changed. Physical printer delivery was not tested.

Branch: `integrate/b2b-plus-gokul-dev`. Marionette access to the supplied VM
service on port 58638 and Chrome admin access were verified.

## Completed scope

All five requested configurations were covered: Bill 1102, Bill A4 802,
Sales and Return Bill 27, Sales and Return Bill A4 843, and Return Bill 28.
Cases: English only, Arabic only, both languages filled, bilingual with all
English fields cleared, and bilingual with only selected English table fields.
The output matrix uses captured admin configuration data and controlled
business fixtures. Individual visibility switches were tested across all six
registered PDF themes and 17 registered thermal themes, including aliases.

| Final check | Verified coverage | Failures |
| --- | ---: | ---: |
| PDF visibility, captions and geometry | 4,980 switch variants plus 30 active consumer-title fixtures | 0 |
| PDF item values | 96,780 checks across 4,980 variants | 0 |
| PDF financial caption/value pairs | 57,360 checks across 4,980 variants | 0 |
| Thermal language, visibility and geometry | 14,365 variants, all 15 document/language groups | 0 |
| Thermal item values | 279,820 checks across 14,365 variants | 0 |
| Thermal financial checks | 165,410 checks across 14,365 variants | 0 |
| Thermal description-hiding fix | 340 outputs; 6,800 item checks; 170 unchanged all-on baselines | 0 |
| Active thermal consumer-title controls | 170 outputs across five language cases | 0 |
| Missing/invalid invoice-date QR regression | 46 PDF/thermal outputs | 0 |

All final thermal reports have zero pending groups. All 61 verification-helper
tests pass. Earlier client regression tests, visual reviews and live order/return
checks are documented in `receipt-verification-2026-09-29.md`.

## Client fixes verified

The verified client changes cover Return Bill configuration selection, explicit
return tax/discount/refund values, return identity and date provenance, combined
customer visibility controls, Arabic table direction and heading widths, narrow
thermal wrapping, hiding item descriptions, and preventing invoice QR codes
from inventing dates or substituting payment QR data.

The final thermal item and financial audits select 170 independently verified
description-hidden replacements. Original pre-fix outputs are retained.
Every corresponding all-on baseline is byte-identical. Final PDF item coverage
combines 3,720 previously successful sales/combined outputs with a full 1,260
Return recheck after correcting a split-slash Arabic heading extraction issue.
This parser repair did not require a printer-code change. Per-output paths and
audit provenance are recorded in the underlying reports.

## Remaining source failures

Freshly retrieving all 23 configuration records confirmed that all five target
configurations are unchanged from the complete capture. The Bill admin form
still contains six Arabic bank captions; its API response returns null for
their value and default text. Bill A4 has the same six missing caption options.
The omission happens before client parsing.

Earlier language captures also document missing bilingual English
header/subheader/footer fields, combined return-title fields, Return Bill
English fields, and remarks/rich Terms content. Real return tax allocations
and supplier/state/place metadata were not supplied by the tested records.
Synthetic fixtures verify arithmetic when those values exist; they cannot
prove unavailable real record data.

Accordingly, the result is **rendered matrix passed; complete source-field
verification blocked**. No values were invented to conceal missing source
data. Backend changes remain outside the authorized scope. The five admin
configurations remain bilingual, with the selected English-field content left
as tested; no restoration was requested.

## Evidence

`build/receipt_live_audit/2026-09-29_final_verification_status.json` records
final counts, source limitations and SHA-256 hashes of the final supporting
reports. The long verification report retains historical checkpoints,
regression evidence and the detailed source-field lists. No workers remain
running for the completed matrix.

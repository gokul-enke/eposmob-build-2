# Receipt verification — 29 September 2026

Branch: `integrate/b2b-plus-gokul-dev`. Connected to the newly supplied VM
service on port 58638. Chrome admin access also works. Backend code and
unrelated business records were not changed.

## Latest verification and remaining failures

**Final status at 03:09 UTC:** all rendered-output workers are terminal. All
14,365 thermal variants pass across all 15 groups, including 279,820 item-value
checks and 165,410 financial checks, with zero failures or pending groups.
All 340 description-hiding repairs pass; all 170 all-on baselines are unchanged.
PDF verification remains complete at 4,980 switch variants, 96,780 item checks
and 57,360 financial pairs. All 61 verification-helper tests pass. The final
status file records report hashes and exact counts:
`2026-09-29_final_verification_status.json`. See the concise final report,
`receipt-verification-final-2026-09-29.md`. The rendered matrix passed; missing
API fields and real record data still prevent source completeness. Backend
code was not changed. Earlier running-worker checkpoints below are historical.

Full PDF verification now passes: all 4,980 single-switch variants have 96,780
positioned item-value checks and 57,360 financial caption/amount pairs, with
zero failures. Financial worker90385 finished successfully. The first full item
audit64931 had 22 missing Arabic heading witnesses, confined to Classic Return
Bill serial/rate fields31/41 in both-filled and table-English cases. Actual
rendered headings and values were present: PDF extraction separated `/` from
`31` or `41`, shifting the numeric fragment's column center. The Arabic parser
now uses the complete split-slash span; seven Arabic position tests pass,
including cross-column and later-quantity negatives. All 1,260 Return switch
PDFs were rechecked after this fix: 27,060 values / zero failures.

`2026-09-29_pdf_control_item_column_complete_audit.json` combines that full
Return recheck with the prior successful 3,720 sales/combined checks. It verifies
the exact 4,980 unique case/theme/option keys against all 15 source snapshots,
records audit provenance and current PDF SHA-256 hashes, and has `complete: true`.
It does not claim the unchanged sales/combined files were rerun with the updated
Arabic parser. The earlier 22-failure item report remains preserved. Evidence
also includes `2026-09-29_pdf_control_item_column_return_audit.json` and the
successful full `2026-09-29_pdf_control_amount_audit.json`.

Fresh source revalidation retrieved all 23 API configuration records. All five
target configurations are property-for-property unchanged from the earlier
complete capture. Bill1102 and BillA4802 still return null value/default text
for all six bank captions. A fresh Chrome visit to Bill1102 confirms the six
editable `data.translation.display_texts.*Label` inputs still contain the
configured Arabic field37–42 text; the admin preview also uses those captions.
No save was submitted. `2026-09-29_final_source_comparison.json`,
`2026-09-29_final_source_recheck.json`, and the updated
`2026-09-29_admin_bank_source_comparison.json` record this current discrepancy.
The missing configured text is upstream of client parsing. Backend code remains
untouched, and source completeness is not certified.

At 02:59 UTC, original thermal output generation is 14,192/14,365; finalized
caption/geometry reports cover 14/15 groups. Only worker39288 (combined
table-English) remains live. Final all-thermal item/financial audits and the last
repair baseline comparison must follow its completion. All PDF and sales/return
thermal workers named above are terminal; do not restart or repoll them.

At 02:42 UTC, sales thermal verification is complete in all five language
cases and all 17 registered themes: 5,270 outputs / 83,130 independent item
checks / zero financial pair failures / zero pending groups. Reports
`2026-09-29_thermal_control_item_sales_audit.json` and
`2026-09-29_thermal_control_amount_sales_audit.json` both have `complete: true`.
These audits select the verified off-particulars repairs and retain their trace
paths. Sales workers97349,39403,93203 are terminal0. Together with Return Bill,
8,925 thermal outputs pass full item and financial coverage; 161,670 item-value
checks are complete across those two document groups.

Original thermal caption/source/visibility/geometry audits now complete 14/15
groups / 13,277 outputs. Only combined table-English remains in worker39288
(134/1,088 generated at this checkpoint). The particulars repair report passes
all 340 receipts / 6,800 item checks, with only the combined table-English
original-baseline comparisons pending. All nine other groups now supply
verified repair selections. Full PDF item64931 and financial90385 remain live.
Do not poll any of the terminated sales/return/partial/repair workers again.
Backend and admin state remain unchanged in this continuation. Final all-print
and current API source-completeness gates remain open.

Latest financial parser correction: worker63208 finished with 1,701 failed
pairings. The strict vertical-first rule introduced in the previous continuation
was incorrect: different caption/amount font sizes shift their vertical centers,
and parallel panels align unrelated totals. Inspected failures contain the
correct printed values. That regression report is preserved as
`2026-09-29_pdf_control_amount_vertical_priority_regression.json`; it is not a
print-code failure report. Pairing now rejects digits within captions, recognizes
which adjacent caption owns a parallel value, treats Latin/Arabic digit spellings
of the same bilingual field as one caption, and uses both horizontal and vertical
distance. Twelve positioned amount regression tests pass, including the actual
bank-account/MRP, paid/discount, larger net-total font and bilingual saved-amount
cases. With eight item tests, the PDF parser suite has 20 passing tests.

The corrected checker revalidates all 90 baseline PDFs / 1,020 amount pairs and
all 60 QR-switch PDFs / 780 pairs with zero failures. Those variants include the
two original parallel-panel false pairings. Evidence:
`2026-09-29_pdf_baseline_amount_audit.json` and
`2026-09-29_pdf_control_amount_filtered_showQRCode_audit.json`.
The full 4,980-PDF financial rerun is live in session90385. Worker63208 is
terminal1 and must not be polled or counted as successful. Until the new rerun
finishes, the ordinary full report still reflects that previous regression.
Full PDF item worker64931 remains live. No print-code change was made for these
checker corrections.

The available thermal financial audit98135 has finished successfully:
12,380 receipts, zero amount-pair failures, three incomplete groups. Together
with the available 12,227-output item audit, this remains partial coverage.
At 02:36 UTC, 13,196 of the planned 14,365 original thermal outputs have been
generated; sales table-English and combined empty-English are nearly rendered,
and combined table-English has not started. Fully finalized caption/geometry
groups remain 12/15 until their workers publish the completed audits.

Latest expanded item continuation: the available full thermal matrix passes
12,227 receipts / 236,738 independent item values / zero failures. Its three
pending groups and `complete: false` remain explicit; this is not a final
14,365-output certification. Selected repair trace paths are recorded in
`2026-09-29_thermal_control_item_audit.json`. The full thermal financial audit
is active in session 98135. The item worker68532 has finished successfully.

All 340 isolated particulars repair receipts now pass 6,800 item checks,
decimal-amount preservation, caption removal, raster geometry and alias checks
in all five language cases for sales and combined documents. Worker95396 is
terminal0. Three original groups do not yet provide all 17 all-on baselines, so
the repair report remains `complete: false` solely for those pending baseline
comparisons. Available baseline images are identical. Fully compared groups
may supply verified replacements; uncompleted baseline groups are withheld.
The repair verifier now checks the generated outputs even while their original
baselines are pending, without treating absent original references as failures
or skipping the independent item checks.

PDF item coverage was extended to single-switch variants using the selected
4,980 output paths from the caption/control coverage audit. Disabled column
ownership is removed explicitly; sold and returned rows are bounded by their
own table headings. When particulars are hidden, dense numeric row positions
are found without searching for expected values. The hidden-name pilot passes
120 PDFs / 2,460 item values / zero failures across all five cases and six
themes. Its report is
`2026-09-29_pdf_control_item_column_filtered_showParticulars-showReturnParticulars_audit.json`.
The expanded baseline remains 90 PDFs / 1,800 item values / zero failures.
Eight PDF item tests and seven positioned amount tests pass (15 total).
Full item audit worker64931 and full financial worker63208 remain active;
their completion must be observed before counting either full scope passed.
No additional print-code, backend or admin changes were needed in this
continuation; current changes extend verification and repair provenance.

Completion gates against the original request remain:

| Requirement | Current evidence / remaining work |
| --- | --- |
| English, Arabic, both filled, cleared English, and table-only English for all five configurations | Five captured cases; 90 PDF baselines and registered thermal themes generated. Full final sweeps still pending. |
| Every PDF template and switch | 4,980 caption/value/page-geometry checks passed; full item64931 and financial63208 still running. |
| Every thermal template and switch | 14,365 planned; original full caption audits and final item/financial audits not yet complete. Return-only 3,655 fully passed. |
| Preserve sold/returned columns and amounts with controls off | Baseline arithmetic, hidden-name pilots and available 12,227 thermal item outputs pass; final all-output coverage pending. |
| Correct any client defects and verify the correction | Particulars names repaired in three real thermal layouts and hot-reloaded; all 340 repaired outputs pass, with three baseline comparison groups pending. Earlier QR/return/footer repairs remain documented below. |
| No missing configured source fields or logic | Cannot yet certify: previously captured API bank/bilingual/header/return field omissions remain, and backend edits are prohibited. No values were invented to mask missing server data. |

Latest isolated repair checkpoint: six of ten sales/combined language groups
pass, including both-filled sales and combined documents. The repair report
contains 204 receipts / 4,080 independent item checks / zero failures, with
four groups pending. Worker 95396 remains active. The PDF financial rerun63208
remains active; do not count it complete before its terminal result.

At 02:12 UTC, all five Return Bill thermal groups are complete: 3,655 outputs
pass caption/source/visibility/geometry checks, 78,540 independent item-column
checks, and all expected financial caption/amount pair checks. Both financial
and item reports have `complete: true`, zero failures and zero pending groups:
`2026-09-29_thermal_control_item_return_audit.json` and
`2026-09-29_thermal_control_amount_return_audit.json`. The return worker 32650
has finished successfully. Return name suppression is checked for English and
Arabic names, including serial-off dense item blocks. The item audit was rerun
after adding the Arabic-name assertion. The thermal auditor regression suite
now has 28 passing tests, including five repair-selection safeguards.

Original thermal caption/visibility/geometry reports now complete 12 of 15
groups / 11,135 outputs. Sales table-English and combined empty-English /
table-English groups remain in workers 97349 and 39288. This count still requires
the separate particulars repairs before claiming product-name suppression in
historical sales/combined outputs. `thermal_selected_entries.py` selects only
the verified 17 off-particulars replacements for each fully repaired group;
source-hash mismatch, failed or incomplete groups are rejected. Original worker
manifests remain untouched. Item and financial audit results now retain each
selected trace path for provenance. The original caption checker has not been
changed while its full workers remain active.

Latest particulars repair continuation: actual thermal sales receipts retained
Coffee/Tea names when `showParticulars` was disabled while serial numbers were
enabled. Standard, Premium and Premium2 now suppress both product-name languages
while retaining serial numbers. Their registered Standard aliases inherit this
fix. Hot reload succeeded on the connected VM. Analysis of these three files
reported 47 informational findings, with no errors or warnings; the analyzer
exits nonzero on informational findings in this project.

The bilingual sales pilot produced 51 receipts and passed 816 item checks; all
17 all-on baseline PNGs were unchanged. Six meaningful thermal column tests
pass, including hidden bilingual name leaks, merged serial/name columns,
serial-off alignment, displaced wrong amounts, exact HSN codes and signed rates.
The isolated five-case sales/combined repair worker is session 95396. Its first
English sales group passes 34 receipts / 578 item checks, unchanged all-on
baselines, preserved decimal amounts, raster geometry and Standard aliases.
The Premium off-particulars PNG was also visually inspected: names are absent,
serials/numeric columns and totals remain. Evidence:
`2026-09-29_particulars_pilot_audit.json` and
`2026-09-29_thermal_particulars_repair_audit.json`. Full repair coverage is pending;
original manifests are preserved while their render workers remain active.

The baseline PDF item audit now includes units: 90 PDFs / 1,800 positioned
item-value checks / zero failures. The available thermal baseline item pass
checked 173 receipts / 3,470 item values / zero failures. An expanded thermal
item audit exposed the actual particulars bug above, so the older successful
caption/control reports do not certify item-name suppression.

The first 4,980-PDF financial audit found two incorrect pairings by the checker,
not incorrect printed totals: the bank account in a parallel panel was paired
with MRP, and a paid amount with discount. Exact vertical caption/value baseline
alignment now takes precedence over horizontal distance; seven position tests
pass, including this parallel-panel case. The corrected full financial rerun
is active in session 63208; session 95954 has finished and must not be polled.

At 02:05 UTC, original full thermal caption/source/visibility/geometry audits
complete 10 groups / 9,350 outputs. Five groups remain pending; 10,894 outputs
have been generated. These figures exclude the new particulars body-name check
and therefore require the isolated repairs before final completeness claims.
Workers 97349 / 39288 / 32650 remain active. Backend code and unrelated business
records were not changed. Existing API source omissions remain unresolved.

Latest item-column continuation: all 90 baseline PDFs in the five language cases
pass 1,740 positioned item-value checks. Values are checked under each configured
column heading, separately for the sold and returned Coffee/Tea rows. Coverage
includes serial/quantity, MRP, inclusive/exclusive unit rate, tax/line total,
return tax rate/allocation/taxable value/subtotal, and exact HSN leading zeros.
This supplements the 1,020 financial summary/final amount checks. The English
marker parser now joins wrapped headings only within the same physical column;
six negative/position tests pass. Initial missing English witnesses were parser
limitations, not missing printed fields. Evidence:
`2026-09-29_pdf_item_column_audit.json` and
`build/receipt-pdf-item-column-audit.log`. This is baseline PDF scope, not all
off-switch item columns or thermal glyph/OCR proof.

The cleared-English sales PDF spot check contains Arabic captions, alongside
unchanged English business data (product/customer/bank names, address and units).
It does not introduce built-in English table captions. Code tracing confirms
bank option values are already null before `DisplayOption.fromJson` consumes
them; that parser retains supplied value/default text. No alternative caption
source was recovered from the selected template-name setting.

Full thermal audits now pass eight groups: 7,531 outputs and 6,645 identical
Standard comparisons. Both-filled Bill sales joins the previous seven groups;
its 17 inactive consumer titles remain covered by the separate B2C fixtures.
Seven full groups remain pending. Original render workers remain live, as does
the PDF single-switch financial audit in session 95954. No production/backend/
admin/business-record changes in this continuation.

Latest PDF/financial continuation: all 90 baseline PDFs across sales A4,
combined A4 and Return Bill in the five language cases pass 1,020 positioned
caption/amount checks. This includes all combined return-total/net rows and final
order/refund/net amounts (40, 21, 19). Values are paired to the nearest numeric
value beside the caption rather than searched across the whole page. Six
negative/position tests pass, including swapped neighbouring totals, another
row's amount, signed amounts and split caption boundaries. Evidence:
`2026-09-29_pdf_baseline_amount_audit.json` and
`build/receipt-pdf-baseline-amount-audit.log`.

Extended financial preservation to the single-switch variants. The first
available thermal pass checks 7,336 receipts with zero amount-pair failures:
every checked enabled financial caption retains its expected value when another
option is disabled. Disabled financial rows and the customer balance master
switch are handled explicitly. This is partial coverage of the planned 14,365
receipts; its report records all incomplete groups. Evidence:
`2026-09-29_thermal_control_amount_audit.json`. The analogous 4,980-PDF switch
amount audit is running in session 95954; poll this same handle before declaring
its results or starting another copy. No production changes were needed.

Full thermal render/control audits now complete all English and Arabic groups
plus both-filled Return Bill: 6,477 outputs and 5,715 identical Standard
comparisons. Eight full language/document groups remain unfinished in the
original workers 97349, 39288 and 32650. Backend, admin configurations and
business records remain unchanged in this continuation.

Latest arithmetic continuation: the corrected parser rechecks all five completed
full thermal groups successfully (4,658 outputs, 4,110 identical Standard
comparisons). The full rendering workers remain live; ten groups are unfinished.
Added `tool/verify_thermal_baseline_amounts.py` to check painted summary
caption/amount pairs independently of the layouts: sales quantities/rates/MRP,
discount/net/tax/subtotal/saved, balances/payment, allocated return amounts and
refunds, and the combined final 40 minus 21 equals 19. Its current report checks
117 available baseline receipts across eight started language/document groups
with zero amount-pair failures. Seven groups have no baseline available yet;
rerun it as the full workers advance. This count is partial and does not certify
all control-off amounts, all PDFs or real server allocations.

Five negative/parser tests pass: wrong negative amount, expected amount hiding
another incorrect value, missing amount, bilingual marker identifiers and Arabic
quantity captions. The amount checker pairs boxed entries individually and
uses Return Bill summary labels separately from item subtotal/total headings.
Evidence is `2026-09-29_thermal_baseline_amount_audit.json` and
`build/receipt-thermal-baseline-amount-audit.log`. No production code changed in
this continuation; backend/admin/business records are unchanged.

Newest checkpoint: Arabic Bill sales completes all 1,054 outputs with zero
checked failures and 930 identical Standard comparisons. An initial audit had
18 additional missing witnesses because removing whitespace joined Arabic
caption suffixes to nearby amounts/VAT numbers. The parser now preserves that
boundary; nine checker tests pass. Re-auditing Arabic sales leaves only the 17
inactive consumer titles already covered by the five active B2C fixtures.
Completed outputs across the five finished groups total 4,658; the earlier four
groups are being re-audited with the corrected parser in session 60670.
The full render workers remain 97349 (sales), 39288 (combined), 32650 (return).
Ten language/document groups remain unfinished. The progress summarizer now
requires the current verifier hash and complete suppression witnesses (with
explicit B2C coverage) before counting a group as verified. No print-code change
was needed for this parser correction.

Current connection and source check: Marionette connects successfully to port
58638 and reads the live Orders List. The branch remains
`integrate/b2b-plus-gokul-dev`. Chrome admin access works. Four completed full
thermal groups now pass 3,604 outputs: all three English document groups and
Arabic Return Bill. The remaining 11 groups continue in the existing workers;
generated but unaudited outputs are not counted as passes. Refresh
`build/receipt_live_audit/2026-09-29_thermal_control_progress.json` with
`tool/summarize_thermal_control_progress.py` for current counts.

The complete current API capture contains 23 document configurations and shared
predefined options. A complete property comparison shows no changes to the five
tested configuration records. No alternate marked English source was found in
the other records or shared options. Read-only inspection of Bill 1102 confirms
that all six Arabic bank caption inputs are editable and populated in the admin
form, while their six corresponding visible API options have null values.
Evidence: `2026-09-29_admin_bank_source_comparison.json` and
`2026-09-29_complete_config_response.json` under `build/receipt_live_audit`.
This is an observed admin-to-app response discrepancy; the server cause is not
established here. Client rendering cannot reproduce text that it does not receive.
No backend changes or admin saves were made during this comparison.

Visual spot check: inspected the newly rendered Arabic and both-filled bilingual
Return Bill `premium2_bilingual` baseline PNGs. Both contain the supplier,
customer, return identification, two returned items, amount totals and independent
tax summary without an obvious clipped section in the full receipt view. The
bilingual image reflects the English source omissions already recorded; this
spot check does not replace the pending full switch sweep or certify all glyphs.

The following entries record earlier checkpoints; the current counts above
supersede their pending-work counts.

Latest thermal continuation: full English sales/combined/return sweeps pass
2,873 outputs and 2,535 alias comparisons. Sales retains 17 inactive consumer
title witnesses, covered separately by active consumer fixtures. All five
consumer-title thermal cases pass 170 outputs, 150 aliases, decimal-value
preservation and 170 decoded dated QR inputs. Found and fixed a real missing-date
QR defect: the helper inserted the current time, and PDF themes could substitute
a payment QR under the invoice caption. Six helper/identity tests and 46 actual
missing/unparseable-date receipts pass after the fix. Other language full sweeps
are still running; the 14,365-output plan is not complete.

Thermal-control continuation is underway: a 68-output pilot passes painted-row
visibility, measured single-line truncation, PNG generation/change and 60
Standard-family pixel comparisons. Full sales, combined and return workers are
running a 15-group, 14,365-output plan across all five languages and 17 themes,
including an all-on baseline per theme. These planned full outputs are not yet
verified. The debug observer preserves previously verified English baseline
pixels for all three document types. The full goal remains active.

Latest witness continuation: all 4,980 single-switch PDFs now have caption/value
suppression evidence when supplemented by 30 consumer-title PDFs. The business
fixture has 30 deliberately inactive consumer-title cases; their separate active
consumer fixture supplies the missing evidence. Zero checked failures and zero
missing witnesses across the combined coverage report. This closes the earlier
870-witness gap for the stated suppression/page-boundary scope. Exhaustive
thermal switches, missing source/business data, broader arithmetic/visual
verification and physical printer delivery remain incomplete.

Latest continuation: generated 4,980 PDFs with one configuration switch disabled
at a time, covering five language cases, three document types and six PDF themes.
The final audit finds zero failures for witnessed captions, selected business
values and page boundaries. However, 870 checks lack a visible baseline witness;
these controls remain unverified. This is not certification of every switch.
The sweep exposed a combined-return customer master-switch defect, now fixed
in the shared section builder and checked in 30 corrected PDFs and 85 thermal
outputs. Footer fallback/hidden fixtures add 414 outputs with zero checked
failures. Backend/source omissions and physical printer verification remain
unresolved. Detailed evidence and limits appear in the final section below.

Latest continuation: added consumer (B2C) coverage for both sales configs in
all five language cases: 115 outputs, plus 17 bilingual 58mm outputs. All
132 pass geometry. All 30 PDFs preserve the supplied active captions and
consumer title, suppress absent customer VAT/CR fields and pass 330 positioned
amount/value pairs. All 75 Standard thermal aliases match pixels. Visual
review found clipped token labels in Standard/Premium; those rows now wrap.
The focused 34-test suite passes. Regenerated 285 B2B sales/return/combined
outputs after the thermal change. Including the B2C runs, all 417 final outputs
pass geometry and 315 Standard-family pixel comparisons pass. Source
completeness still fails; backend code remains unchanged.

Previous client update: five PDF themes now give configured return serial
headings more width and mirror sales/return columns on Arabic-only documents.
The focused 36-test regression suite passes; 243 regenerated outputs pass
geometry. A new positioned Arabic-marker audit passes 72 PDFs, including
RTL column order on all 18 Arabic-only PDFs. Source completeness still fails.

Earlier client update: return identity/date provenance and the independent
return tax-summary table are fixed. The production return builder also now
preserves missing totals so returned-line fallback works without overriding an
explicit zero. That regression suite passed 71 tests. Verification of
source completeness still fails; missing API text and return allocations are
listed below. No backend edits were made.

All five admin records have been exercised in the five requested language
cases against this deployment: English, Arabic, bilingual both filled,
bilingual with every English field empty, and bilingual with selected English
table headings only. An additional coverage audit found disabled controls in
the earlier combined-template English/Arabic captures; fully enabled
replacement captures and outputs now cover those cases. All five records
remain bilingual. Combined records 27 and 843 currently have all 49 ordinary
English and bilingual Arabic fields filled and all 63 controls enabled; the
other three retain their selective-English configuration. This is a failed
overall verification: source omissions and unavailable return data remain.

Fresh Return Bill 28 captures cover 57 language fields, the separate Terms
editor, and all 42 switches. Generated 115 outputs through the production
ReturnBillLayoutParamsBuilder. All 30 PDFs retain the visible table labels
supplied by the response, with no theme differences or unwanted English
markers. All 115 outputs pass geometry and all 15 Standard thermal aliases
match pixels in each case. A further 23 outputs exercise 58mm/A5 paper.

Fixed three missing client return columns: Tax Amount, Taxable Value and the
return-only Sub Total header. Optional explicit item values are preserved;
absent or invalid allocations print blank, never original-sale tax or guessed
zero. Explicit zero and signed amounts are retained. Refund totals do not
change. The subtotal column is excluded from combined receipts, where the
existing showSubTotal control governs the sales summary.

Visual inspection caught an additional dense-table defect: enabling all
return columns split amounts and headings into tiny vertical fragments.
All three thermal families now use a shared label/value row per field for
dense return items (over six columns on 58mm, over eight otherwise). Less
dense tables retain their theme layout. The focused eight tests pass,
including independent visibility, language, serialization, refund integrity,
and dense row label/value pairing. Final analyzer: no errors/warnings;
53 existing informational findings in the return rendering/model/test files.

Native return printing initially used Credit Note 1103 instead of Return Bill
28. A live alias capture confirms both currently exist, so resync alone did
not fix selection. The client now prefers the admin Return Bill and keeps
Credit Note as a fallback. Five resolver tests pass. Hot reload and an actual
Open PDF job confirm config=Return Bill, all ten supplied selective-English
headings, and the unchanged SAR 360 refund. The route analyzer has 15 existing
informational findings, no errors/warnings.

Fresh Bill 1102 and Bill A4 802 captures cover 51 language text fields and
Terms, with all visibility switches enabled. Each capture also rendered the
other three records in their saved final configurations: five runs of 69
outputs, all passing geometry. The focused sales language audit checks 30
PDFs and 75 Standard thermal alias comparisons: no label failures, theme
differences, generic English label leaks in empty-English PDFs, or alias
differences. It retains failures for missing source fields.

Confirmed response omissions:

- Both sales records: all six entered bank labels are absent in every language;
  bilingual responses also omit English header, subheader and footer.
- Return Bill: entered Remarks Text is absent in English and Arabic; the
  both-filled bilingual response omits 26 English fields. Selective English
  Grand Total and Sub Total table headings are also absent from the response.
- Earlier live Sales/Return checks additionally confirm missing return titles
  and bilingual English Terms. See the sections below for their evidence.

Missing source fields cannot be restored by the client without another data
source. Actual return records also lack item tax/subtotal allocations and some
supplier/state metadata. The new column renders use explicit synthetic order
allocations with live template configurations; they do not prove these values
exist in live API orders. Physical printer delivery and exhaustive visual
review of every business-data combination remain unverified.

Current audit tools: verify_live_return_languages.py and
verify_live_sales_languages.py. Both distinguish source failures from renderer
passes and exit unsuccessfully while source omissions remain. Evidence is in
build/receipt_live_audit/2026-09-29_return_language_audit.json and
2026-09-29_sales_language_audit.json. Final admin screenshot:
2026-09-29_final_five_languages.png. No commit or deployment was performed.

After refreshing final configurations, actual native partial-sale printing
retains all nine selected English table headings, total 1440, subtotal 1220.33,
tax 219.67, paid 1800, current balance 341, and saved 160. The latest client
correction preserves the three cart quantities 1, 2 and 5; earlier quantities
1 and 7 deducted the return from the wrong same-name cart line. Actual combined printing
retains purchase 1800, refund 360, final 1440, and original-sale saved 200. These
latest native files have the dated *_cart_identity_ORD-004460 names in the
audit directory. The *_updated_* files predate the cart identity correction.
An independent glyph-position check confirms the paid and current-balance
amounts remain horizontal in both native files.

## Completed checks

- Current-code synthetic matrix: five documents, five language scenarios,
  17 applicable thermal themes and six PDF themes: 345 outputs. The initial
  run passed 90 PDF marker checks with no theme differences, and 345 page/
  raster geometry checks. The second full run exposed a missing saved row in
  Bilingual Centered after the balance fix. After correcting that clipping,
  regenerated all 60 affected Bill A4 and Sales/Return A4 PDFs, updated the full
  matrix artifacts, and rechecked all 90 PDFs and all 345 output geometries:
  no label differences or geometry failures. This final audit includes an
  explicit saved-label assertion.
- Fresh live Sales and Return Bill 27 and Sales and Return Bill A4 843:
  English, Arabic, both filled, English empty, and only 13 English sale/return
  table headings filled. 49 plain-text controls were filled in each complete
  language source. Final settings use bilingual Arabic content, selected
  English table headings, and all 65 visibility switches enabled.
- Initial bilingual saves lost some Arabic form values during asynchronous
  language/control updates. Those captures were replaced and rerendered.
  Corrected captures contain all 47 Arabic fields exposed by the API; the
  two typed return titles are absent from the response. Do not use the initial
  partial saves as evidence for a fully filled Arabic case.
- The corrected live cases generated 85 thermal images and 30 PDFs. Visible
  table labels agree across PDF themes, with no unintended English markers
  in Arabic/empty-English cases. All 115 outputs passed geometry checks.
  English/Arabic single-language captures retain their original visibility
  flags; bilingual cases also exercise all controls enabled.
- Focused configuration, shared-text, return-price and heading tests: 41
  passed. Sales-only quantity, return-control and title tests: six passed.
- Actual app Open PDF routes generated sale, return-only, and combined PDFs.
  Fully returned ORD-004682: 12 × 5 = 60 refunded; combined final amount 0;
  sales-only correctly refused because no quantities remain.
- Partial return ORD-004460: returned 2 × 180 = 360; sales-only now retains
  quantities 1, 2 and 5, total 1440; combined 1800 − 360 = 1440. Sales-only
  subtotal 1220.33 + tax 219.67 = 1440. The earlier 1/7 split was a confirmed
  client defect, subsequently fixed using the reconciled completed-return
  cart snapshot. Original paid amount remains 1800,
  rather than being fabricated as a new payment for the remaining goods.
- The app initially used its cached pre-edit configurations. Printer Settings
  **Resync Doc** fetched the updated 63 display options and configured theme.
  The user's separately selected PDF theme remains Bilingual Centered.

## PDF defect fixed

Long bilingual balance labels in a narrow panel consumed the row width,
forcing SAR 1800.00 to print vertically and overlapping SAR 341.00. The
native partial-sale PDF reproduced this. The independent glyph-position
check failed before the fix: the paid amount occupied 152 points vertically.

Made the label flexible, alongside the already flexible value, in Bilingual
Centered, Boxed Bilingual and Boxed Header PDF layouts. Both sides can now
wrap within their allotted width. Bilingual Centered and Boxed Bilingual also
align multiline content at the top. No amounts or backend data changed.

The final comparison caught a second-layout clipping issue in the Bilingual
Centered summary table: stretching its column to the exact row height could
discard the last saved row. Kept summary panels at their natural heights.
All five scenarios for both affected document types were regenerated, with
saved labels retained in all English/bilingual themes. The 30 fresh live A4
PDFs were also regenerated and their label and geometry checks passed.

All six A4 and six A5 large-balance renders now keep both currency amounts
horizontal. The regenerated native sale PDF also visibly retains SAR 1800.00,
SAR 341.00 and SAR 160.00 without the previous overlap. Source changes were
hot reloaded into the running app. Both sets of six large-balance PDFs were
rerun after the final clipping correction and passed. The final native
partial-sale PDF and its page-two screenshot also retain all three amounts.
The final native combined and return-only routes were reprinted as well:
combined sale 1800, refund 360, final 1440, original-sale saved 200; return-only
refund 360. Saved 160 belongs to the remaining sales-only goods, whereas 200
belongs to the original combined sale. Both values remain unchanged.

## Historical verification limits (subsequent updates above supersede coverage counts)

- Both Sales/Return API configurations omit the typed **Return Title** and
  **Return Title B2B**, in English and Arabic. Their bilingual responses also
  omit the separate English header, subheader and footer. The source-field
  audit intentionally fails for these omissions; a rendered-label pass does
  not make the whole configuration pass.
- The original ten label captures did not populate the separate **Terms**
  editor. Additional tests below cover it for Sales/Return A4 and the Arabic
  fallback for Sales/Return thermal. Terms coverage for the other three live
  configurations and every visibility permutation remains incomplete.
- Return-only counts returned units, while combined documents count returned
  rows. The partial combined print shows one returned item with quantity two.
  This semantic difference remains; the amount math above does not resolve it.
- Native partial-return PDF has blank HSN/tax-rate cells. Earlier source
  audits found missing return-specific tax/discount allocations and ambiguous
  product links in detailed responses. These fields cannot be declared
  correct by reusing original sale tax or guessing product/variant matches.
- Some dense thermal headings wrap into small fragments. Page bounds passing
  does not establish readability. Three active thermal families were visually
  inspected; 15 theme IDs delegate to Standard, so 17 IDs are not 17 distinct
  layouts.
- No physical printer delivery is certified. Actual app PDF generation and
  development raster outputs are separate from hardware printing.
- Live Bill, Bill A4 and Return Bill language sequences were performed earlier;
  this turn freshly repeated the two Sales/Return documents and rerendered all
  five document types locally. It does not claim a fresh live five-case repeat
  of those other three documents after the latest deployment.

## Additional live Terms checks

The next continuation was progress: six additional Sales/Return A4 captures
and 36 PDFs tested multiline Terms with a nonempty overriding Terms and
Conditions text, English fallback, Arabic fallback, bilingual Arabic fallback,
both language sources filled, and English Terms empty. All 36 PDFs match the
supplied source and pass geometry checks. When an override is present, it
prints instead of the separate Terms body, consistently across all six themes.

The both-filled case confirms another source omission: the saved English
`QATERMS843EN` body prints in English mode and survives reopening the editor,
but the bilingual response supplies only the Arabic body. All six bilingual
PDFs consequently omit those entered English Terms. The new
`tool/verify_live_receipt_terms.py` records this as a source-completeness
failure (exit 2), separately from successful render checks. It does not
substitute generic English or modify backend records to hide the omission.

For the empty-English case, filling the code-editor textarea with an empty
string did not clear its document. Selecting all and deleting through the
editor keyboard handling worked; reopening the English source verified it
stayed empty. Final A4 settings remain bilingual with Arabic Terms and selected
English table headings. The Arabic Terms and Conditions override is empty.

Sales/Return thermal 27 now also has two Arabic Terms lines and an empty
override. Generated all 17 registered themes: geometry passes and all 15
Standard aliases match pixel-for-pixel. Full lower-footer images of Standard,
Premium and Premium 2 were visually inspected: both Terms lines are present.
An initial truncated image view suggested Premium omitted them; the full
receipt disproved that suspicion. No Premium production change was made.

Extended the live model/cache test to assert Terms, footer and number-prefix
preservation for all five configurations. It passes against the latest
capture, ruling out those parsing/serialization steps as the source of the
English Terms loss. Additional Terms evidence is under
`build/receipt_live_audit/2026-09-29_terms*` and its dated render directories.
Admin screenshot: `2026-09-29_terms843_final.png`. No physical printer claim.

## Earlier evidence and changed code

Evidence is local under `build/receipt_live_audit/`, including the ten dated
API captures, `2026-09-29_sales_return_language_audit.json`, native route PDFs,
before/after native balance screenshots, and `2026-09-29_admin_languages.png`.
Outputs are under `build/receipt_output_matrix_full` and the dated
`build/receipt_live_render_2026-09-29_*` directories. API captures may contain
private business information and are not committed.

Changed production files are the three PDF layouts above, at their
`_labelValueLine` helpers. The opt-in renderer gained an isolated large-balance
case. New verification tools check live language sources/PDF labels and
horizontal currency amounts. The geometry checker accepts a specified count
for focused live runs while retaining 345 as its default.

Final analyzer result: no issues in the three changed production layouts.

No commit, deployment, backend change, or business transaction was performed.
The full request remains incomplete because of the stated source and coverage
gaps; do not mark it as an unconditional pass.

## Latest cart identity, allocation transport and supplier work

Sales-only previously matched returns by product name even when the return
identified a different cart line. A duplicate-name test failed before the fix.
The helper now prefers explicit cart IDs, then variant/name linkage; a legacy
name fallback remains when the response provides no reliable identity. A
completed-return snapshot can replace ambiguous summary rows only when it
references actual cart lines, contains unique IDs, stays within sold quantities,
and reconciles with the summary quantity. Draft and invalid snapshots are
rejected. Actual native partial-sale output confirms quantities 1/2/5, tax
219.67 and subtotal 1220.33. Native return and combined totals remain 360 and
1800 - 360 = 1440. Evidence: 2026-09-29_native_cart_identity_audit.json.

Transaction return parsing also dropped explicit return tax_amount, taxable_value
and sub_total. These optional top-level allocations now survive transport to
OrderReturnItem and serialization. Original nested cart allocations are never
borrowed to populate a return. Tests cover explicit zero and absent allocations.

Return supplier fields 14-17 were absent even when company/address/VAT values
were available. The shared return section now supplies those values to all six
PDF themes and all three active thermal families, respecting Supplier Details
and Supplier GSTIN controls. It uses the existing current print context, not a
newly invented historical supplier snapshot. Missing state and place-of-supply
data remain unavailable and are not fabricated. A production-builder store
fixture exercises these values against all five live configuration captures;
these fixture values are not changes to live business records.

The focused current suite passes 27 tests; the broader configuration/return/
balance/identity suite passes 56. Supplier renderer/model analysis has no
errors or warnings and eight informational brace-style findings. Earlier
identity/matrix analysis has 14 informational findings and no errors/warnings.

At the start of the following continuation, Return Bill aggregate totals
(fields 43-46) and remarks (53-54) were still unrepresented. The update below
fixes their rendering controls. The API still omits entered Remarks Text and
live return allocations, so the overall verification remains failed. Document footer
field 3 intentionally serves as a fallback when the configured Thank You
message is empty; existing helper tests verify this precedence. Terms and
Conditions similarly overrides the separate Terms editor body. Those fallback
fields are not expected to print twice when both controls are filled.

Supplier verification completed: all 115 regenerated outputs pass geometry,
all 30 PDFs retain fixture supplier/store values, and 75 Standard thermal
alias comparisons agree. No unintended English field markers appear in
Arabic, empty-English or selective-English supplier tests. PDF English
supplier labels 14-17 are retained in all six themes. Visual proof:
2026-09-29_return_supplier_en_pdf.png and the production Premium raster in
the English builder/store fixture directory. The running app was hot reloaded
and Return Bill reprinted; its refund remains SAR 360. This updated native
file is 2026-09-29_native_return_supplier_ORD-004460.pdf.

Verification commands/evidence: tool/verify_live_return_supplier.py,
2026-09-29_return_store_audit.json, receipt-current-focused.log (27 passed),
receipt-current-regression.log (56 passed), receipt-return-store-*.log
(23 renders per case), and receipt-return-supplier-analyze.log. Chrome
access was rechecked against the live list: all five records still show
English + Arabic. No admin configuration changes were needed in this continuation.

The new supplier section also passed a further 23 selective-English outputs on 58mm thermal/A5 PDF paper, with zero geometry failures. Premium 2 at 58mm was visually checked after this change. These tests use live configuration labels and synthetic business values, not physical printer delivery.

## Return summary and remarks continuation

The admin preview separately controls Sub Total, Discount, Taxable Total and
Tax (fields 45, 46, 43, 44). All six PDF themes and three active thermal families
now print every enabled row. Totals sum explicit return-item allocations only
when every item has a finite value for that field. Missing or invalid data
prints a blank amount, not zero or a partial sum. Explicit zero, signed values
and comma-formatted values are preserved. The original sale's tax, taxable
amount, discount and subtotal cannot feed these rows. Combined receipt totals
retain their existing sales controls, independently of these return-only rows.

Optional top-level return-item discount is now preserved by model parsing and
transaction print transport. Original nested cart discount remains excluded.
The fixtures explicitly supply zero discount; this does not assert the live
API supplies it. The summary switch test covers all 16 independent control
combinations, English/Arabic/bilingual, filled/empty English, complete and
incomplete allocations, invalid/nonfinite values, zero, signed values and
refund integrity.

Remarks (53) now prints under its own control, independently of the signatory.
A remarks_text body supplied in resolved_labels survives the model cache and
prints literally using the document language rules. An absent body stays blank.
The currently saved Remarks Text (54) is still absent from the live response;
this new capability does not remove that source failure. Separate body fixtures
use English, both languages and Arabic with English empty; they are isolated
from actual API captures. All three thermal footer families and the bilingual
PDF body were visually checked. Initial body audit failures were caused by raw
PDF drawing order reversing Latin word chunks inside an RTL paragraph. Spatial
extraction and visual inspection confirmed the visible English sentence; the
checker now uses spatial extraction for the body while retaining drawing-order
marker checks for labels. No production change was made to hide that audit.

Regenerated 115 live-config outputs and 69 isolated body-fixture outputs. All
184 pass geometry. The summary audit checks 30 live-config PDFs and 18 body
fixture PDFs: zero missing summary/remarks labels, amount-pair failures or body
failures. All six English PDF themes pair subtotal/taxable total with SAR20.35,
tax with SAR0.65 and discount with SAR0.00. Supplier audit still passes 30 PDFs
and 75 thermal aliases. A further 23 58mm/A5 outputs pass after the latest
changes. The final regression suite passes 63 tests; the focused summary/
prices/supplier suite passes 8. Final analysis has no errors/warnings and
55 informational findings in the examined production/model/test files; the
new summary test file separately reports no issues.

The hot-reloaded native Return Bill reprint retains refund SAR360.00, prints
the four unknown allocation labels without fabricated amounts, and prints
the enabled remarks label with its missing body blank. Evidence:
2026-09-29_native_return_summary_remarks_ORD-004460.pdf and its page-one PNG;
2026-09-29_return_summary_audit.json; 2026-09-29_return_both_remarks_pdf.png;
2026-09-29_return_remarks_{standard,premium,premium2_bilingual}_footer.png.
Verification tool: tool/verify_live_return_summary.py. No backend changes or
admin edits were performed in this continuation.

Historical findings at the end of that continuation: the independent
showTaxSummary table was not represented by the shared return section. The
Orders print route used the sale date and sale number for the return identity.
These client defects are fixed in the continuation below. The observed order_returns response supplies id=758
and item id=985 but its only keys are id, return_total_amount and return_items;
it provides no return creation date. The native shown date must not be claimed
as the actual return date. Supplier state and customer place-of-supply data,
missing source text and live return allocations also remain unresolved.
The active objective is not complete.

Final full-matrix rerun after the summary/remarks changes completed all 345 cases. All 90 PDF text checks pass with zero theme differences or unexpected English markers, and all 345 outputs pass geometry. This confirms the existing checked markers across all five documents and five language scenarios; it does not certify the unresolved independent tax-summary and return identity/date logic. Evidence: receipt-full-summary-remarks-matrix.log, receipt-full-summary-remarks-text-audit.log, and the full matrix's updated audit JSON files.


## Return identity, tax summary and missing-total continuation

Return prints now use the return record ID (758 in the observed partial
return), with the original sale reference in its separate row. A valid return
created_at is preserved through the summary model and used by the Orders
route. The transaction model tracks whether created_at actually existed, so
its fallback current timestamp cannot become a printed credit-note date.
Both transaction list entry points and the details modal use the same return
identity helper. The observed summary response has no created_at; its printed
Credit Note Date is blank. The original sale date remains in the original
invoice date row. No new credit-note numbering convention is invented.

The independent showTaxSummary control now renders a table across all six
PDF themes and all three thermal families. Rows group return lines by their
explicit tax rate and sum only complete, finite return allocations. Known
zero rates and amounts remain zero. Unknown rates remain blank; wholly empty
groups are omitted. Missing allocations do not become zero or partial sums.
Totals are independent of item-column and aggregate-summary switches. Arabic
column order mirrors English; absent bilingual English captions stay absent.

Regenerated all five live language cases: 115 production-builder/store-fixture
outputs, plus 23 selective-English 58mm/A5 outputs. All 138 pass geometry.
All 30 PDFs pass spatial rate/amount checks (18%: taxable 10.35, tax 0.65;
0%: taxable 10.00, tax 0.00; total 20.35/0.65). These are explicit synthetic
allocations, not data supplied by the native partial-return endpoint.
Supplier/summary audits still pass 30 PDFs and 75 thermal alias comparisons.
The previously isolated remarks fixtures retain their 18 checked PDF bodies.
Thermal Standard and Premium 2 bilingual footers, Premium English footer,
and Premium 2 selective-English 58mm footer were visually inspected.

A further builder audit found missing refund totals converted to zero before
rendering. Orders and transaction parsing now preserve that missing state.
The production builder and layouts share one refund/unit-price resolver:
finite explicit totals, including zero, take precedence; missing/invalid or
nonfinite totals fall back to returned quantities and their unit prices.
Matching original cart unit prices may supply a rate without borrowing its
original sold quantity or tax allocation. formattedTotal, rendered totals
and amount-in-words now agree. New builder tests cover all three languages,
missing/invalid/NaN/infinite totals, zero, comma formatting, and the 2 returned
units at 180 from an original 7-unit cart line.

The missing, zero and comma-total builder cases generated another 69 outputs.
All 69 pass geometry; all 18 PDFs pair both refund total labels with SAR21.00
for missing/comma totals and SAR0.00 for explicit zero. These runs preserve
the missing value at the builder boundary rather than substituting a fixture
sale total. Evidence: receipt-return-builder-matrix-{missing,zero,comma}.log
and 2026-09-29_return_refund_total_audit.json.

Latest native Open PDF jobs reprinted sales, combined and return with the new
tax-summary code. Sale amounts remain 1440, subtotal 1220.33, tax 219.67,
paid 1800, current balance 341 and saved 160. Combined remains purchase 1800,
refund 360, final 1440, saved 200. Return identity is 758, original reference
ORD-004460, refund 360 and returned MRP 400. All three native PDFs have zero
out-of-page glyphs. A final native return after the builder correction retains
these same values. The tax-summary table prints its captions with unknown
amounts blank, matching the native response's missing allocations.

Evidence: receipt-latest-return-regression.log (71 passed),
receipt-latest-focused-analyze.log (no errors/warnings, three pre-existing
matrix-test informational findings), receipt-return-builder-total-analyze.log
(no errors/warnings, two existing context informational findings),
receipt-return-identity-tax-summary-analyze.log (one existing unused modal
method warning and 68 informational findings; the new missing import was
fixed). git diff --check passes. The extended analyzer warning is unrelated
to the changed print callback and remains reported rather than hidden.

Artifacts: 2026-09-29_native_return_tax_summary_758.pdf,
2026-09-29_native_return_refund_builder_758.pdf,
2026-09-29_native_{sales,combined}_tax_summary_ORD-004460.pdf,
2026-09-29_native_tax_summary_audit.json,
2026-09-29_return_tax_summary_audit.json and the dated tax_summary footer PNGs.
Tools: verify_live_return_tax_summary.py and verify_live_return_refund_totals.py.
Chrome access was rechecked; all five admin records remain English + Arabic.
No configuration, backend or unrelated business-record mutations occurred in
this continuation. Physical printer delivery, unavailable supplier/state/place
metadata, missing configured API text and actual return allocations remain
unverified or failed. This is progress on the active objective, not a claim
that every scenario has passed.


## Combined-template coverage correction and fresh verification

The earlier English/Arabic combined captures enabled only 52/63 controls for
record 27 and 8/63 for record 843. They are retained as historical evidence,
but are insufficient proof of all enabled fields. Fresh en_full, ar_full and
both_full captures now have all 63 controls enabled for both records. Each
ordinary language editor's 49 fields was filled, including previously empty
bilingual Terms and Conditions field 38. Separate rich Terms editor behavior
remains covered by its earlier priority tests and source-omission findings.

Generated 51 thermal outputs (17 themes/aliases x three languages) and 18 A4
PDFs (six themes x three languages). All 69 pass geometry. The refreshed
language audit combines these fresh A4 cases with the existing empty-English
and table-only cases: 30 PDFs, zero missing supplied English labels, zero
unwanted English labels and zero theme differences. All ten captured combined
cases have zero disabled controls. Footer field 3 is an intentional fallback
for Thank You field 37, rather than a second body when both are supplied.

The stronger audit still exits 2 for source completeness: return titles 4/5
are absent from both combined records' API responses in all language cases;
bilingual English header/subheader/footer 1/2/3 are also absent. These are
saved-content/API omissions, not repaired by substituting hardcoded labels.
No backend edits were made. All configured fields cannot be certified while
those omissions remain.

Visually inspected all nine 80mm thermal layouts (Standard, Premium and
Premium 2 bilingual in English, Arabic and bilingual), using twelve full-width
comparison bands. Supplied sales and return headings, summary labels, contact
metadata, Terms and Thank You remain visible. Long synthetic headings wrap
within narrow table columns. Fixture purchase 40, refund 21 and final 19 are
consistent across all nine layouts; saving 8 is placed differently by theme
but retained. Fifteen Standard aliases are pixel-identical in each language
(45 comparisons). This is visual inspection of these fixture outputs, not
physical-printer delivery or exhaustive real-business-data coverage.

Evidence: 2026-09-29_sales_return{,_a4}_{en,ar,both}_full.json;
receipt-sales-return{,-a4}-{en,ar,both}-full-matrix.log;
2026-09-29_sales_return_language_audit.json;
2026-09-29_combined_full_{en,ar,both}_band{1,2,3,4}.png.
The native sales/combined tax-summary PDFs above predate these latest admin
content changes; they prove the client arithmetic, not the new saved labels.

Access rechecked: Marionette connects on port 58638 and inspects the filtered
native Orders list; branch remains integrate/b2b-plus-gokul-dev. Chrome visibly
shows all five admin records as English + Arabic. Chrome screenshot export
continues to time out, so no fresh admin screenshot is claimed or substituted.


## Positioned Arabic audit and PDF column corrections

The new verify_live_arabic_fields.py audits all supplied numbered Arabic
labels in Bill A4, Sales and Return Bill A4 and Return Bill: four Arabic-bearing
language cases per document, six themes, 72 PDFs and 3408 required field
instances. It normalizes glyph forms and checks positioned words, including
centered/right-aligned wrapped marker parts and the Arabic prefix. Footer 3
is an explicit Thank You fallback. Sales title 4 is conditional: these fixtures
are B2B and print title 5. Return state 18 and place of supply 24 have no fixture
business values and remain separately unverified, not fabricated.

This stronger check found a real dense-return-heading defect. With all 12
return columns enabled, five PDF themes split serial field 31 into eight small
lines, including individual Arabic letters and digits. Increased its flex
width from 0.6 to 1.0 in all five specialized themes. Both language captions
remain present; the widened bilingual cell groups the Arabic marker intact
and wraps the English marker in two chunks. The classic table was already
wider and was left unchanged. Before/after PDFs and page-2 PNGs are saved as
2026-09-29_return_dense_heading_{before,after}.

A spatial column-order check then found those same five themes' Arabic sales
and return tables laid out left-to-right while classic mirrored them. Both
item tables now explicitly reverse columns on Arabic-only pages, including
matching values and widths; Arabic return names align right. English and
bilingual column order stays as before. The Arabic audit passes all 72 PDFs,
with 20 table instances across all 18 Arabic-only PDFs verified by field
coordinates. Six negative checks remove the Arabic serial marker while
retaining the English text; the checker detects every removal. This checks
caption presence and positions, not every character's visual readability.

Regenerated the five Return Bill language cases (115), five combined A4 cases
(30), missing/zero/comma refund cases (69), selective-English 58mm/A5 return
case (23), and Arabic Bill A4 (6): 243 unique final outputs, all geometry passes.
Superseded runs are not counted again. Refreshed verifiers prefer these
current filtered sales outputs and return store-fixture outputs. All three
language audits retain zero renderer failures but exit 2 for source omissions.
Return supplier, summary, tax-summary and refund-total audits pass; their
separate source/business-data limits remain as stated above. Visually inspected
the widened bilingual return table and the Arabic return page with mirrored
serial/total columns, correct rate/quantity pairs and explicit allocations.

The final focused suite passes 36 tests. All five edited PDF files analyze
with no issues. git diff --check passes. Evidence: receipt-return-pdf-column-
regression.log, receipt-return-dense-heading-analyze.log,
receipt-pdf-column-geometry.log, receipt-arabic-field-audit.log,
2026-09-29_arabic_field_audit.json and the per-verifier pdf-column logs.

Hot reloaded the native app, resynced document configurations using its UI,
and reprinted the existing ORD-004460 sale, return 758 and combined bill through
Open PDF. Verified output timestamps after asynchronous generation before
preserving the final PDFs. Sales retains 1440, subtotal 1220.33, tax 219.67,
paid 1800, balance 341 and saved 160. Return retains refund 360 and MRP 400.
Combined retains purchase 1800, refund 360, final 1440 and saved 200; its latest
saved English Terms 38 and all return headings 44-49 are present. All three
have zero out-of-page glyphs. This native audit checks known amount presence
and captions, not exhaustive value-to-label associations.

Evidence: 2026-09-29_native_sales_pdf_column_ORD-004460.pdf,
2026-09-29_native_return_pdf_column_758.pdf,
2026-09-29_native_combined_full_column_ORD-004460.pdf,
2026-09-29_native_pdf_column_audit.json. These supersede the earlier native
PDFs for current code/configuration proof. No backend, configuration or business
record edits occurred during this continuation. Full completion remains
unproven: missing response text/real return allocations, conditional B2C
render coverage and exhaustive business-data/physical-output review remain.


## Consumer sales coverage and thermal token wrapping

Reconnected Marionette to port 58638 and verified the workspace branch remains
integrate/b2b-plus-gokul-dev. Chrome can read the five admin records; each remains
English + Arabic. A fresh read-only configuration capture has no print-relevant
changes from the saved final cases. It retains all enabled controls: 61 each for
Bill/Bill A4, 63 each for combined, and 42 for Return Bill. No backend, admin or
business-record edits occurred during this continuation.

The output matrix now accepts RECEIPT_CUSTOMER_TYPE=B2C, with separate output
folders, a consumer title and empty customer VAT/CR values. Its default B2B data
is unchanged. Generated five cases for Bill (85 thermal) and Bill A4 (30 PDFs),
then regenerated all 85 thermal outputs after the token correction. An additional
bilingual 58mm run generated 17 outputs. All 132 final outputs pass geometry.

The new B2C auditor checks every active caption supplied by the saved response,
consumer title 4, absence of B2B title 5 and absent customer VAT/CR captions 18/19,
no English configuration markers in Arabic/English-empty output and selected
English table markers only in the table case. All 30 PDFs pass. It also checks
330 caption/value associations, selecting the nearest numeric value on each
caption baseline so swapped totals across a row cannot pass merely by containing
both numbers. Fixture calculations: item totals 22 + 20, discount 2, tax 4,
subtotal 38, net 40, MRP 48, saved 8, two items and six units; balance 100 + 40 - 15
= 125. A first checker version assigned the wrong field IDs to these totals;
this was a checker defect, not a client monetary defect. The final mapping was
confirmed against the captured display options. Both SAR prefixes and suffixes
are handled. All 75 Standard thermal alias comparisons pass pixel equality.

Visual review of bilingual thermal headers found the token label/value cut off
by single-line cells in Standard and Premium. Those two metadata rows now use
the existing multiline row painter; both languages and token 42 remain visible
on 80mm and 58mm. Premium2 already retains the complete token. Reviewed all five
B2C language headers across three families, bilingual body/summary samples and
bilingual, English-empty and selective-English PDF pages. Configured long stress
markers still wrap densely in narrow item headings; caption presence and geometry
do not certify every glyph's visual quality or physical printer delivery.

Focused routing/configuration regression: 33 tests passed before the thermal
change. Post-change identity/return identity/thermal totals/configuration suite:
34 tests passed. Analyzer reports no errors or warnings in the two changed
thermal files, with 46 informational findings in existing surrounding code;
the matrix has three informational findings. Hot reload succeeded. Evidence:
2026-09-29_b2c_sales_audit.json, 2026-09-29_b2c_current_state.json,
receipt-b2c-sales-audit.log, receipt-b2c-token-wrap-geometry.log,
receipt-token-wrap-regression.log, receipt-token-wrap-analyze.log and
2026-09-29_b2c_*_after.png comparisons.

The B2C auditor exits 2 because saved source completeness still fails: bank
caption fields 37-42 in both languages, and bilingual English header/subheader/
footer 1-3 are missing from the response. Those omissions remain separate from
zero renderer failures. Real return allocations and other response omissions
listed earlier also remain unresolved. No claim of complete end-to-end or
hardware verification is made.


Post-fix regeneration completed: all five B2B Bill cases (85 thermal), all five
combined thermal cases (85 thermal), and all five Return Bill store-builder
cases (85 thermal + 30 PDF) passed their render runs. Including the 132 B2C
outputs above, the aggregate audit checks 417 unique final outputs with zero
geometry failures and 315 Standard-family comparisons with zero pixel
differences. Regenerated files supersede prior artifacts with the same role;
repeat generations are not counted as additional outputs. Reviewed bilingual
combined/return header samples after the change. The native app was hot reloaded.

Evidence: 2026-09-29_token_wrap_regeneration_audit.json,
receipt-token-wrap-geometry.log and per-language receipt-token-wrap render logs.
The B2C coverage gap stated in the previous continuation is closed for these
synthetic data cases. Source omissions, missing real return allocation fields
and exhaustive business-data/physical printer verification remain unresolved.


Final refreshed checks after regeneration: the three language verifiers retain
zero rendering failures and exit 2 for source completeness. The positioned
Arabic audit passes 72 PDFs; return supplier passes 30 PDFs and 75 aliases;
return summary passes 30 live PDFs and 18 isolated remarks fixtures; tax-summary
passes 30 PDFs; refund-total passes 18 PDFs. These are distinct check scopes,
not extra unique outputs. Per-check receipt-token-wrap-verify_live_* logs retain
the results. git diff --check passes. No checks certify physical printer jobs.

## Individual controls, customer master switch and footer verification

Fresh read-only capture 2026-09-29_footer_current_state.json matches the prior
capture for all five configurations' language, display options, resolved labels,
header, subheader, footer and terms. All five remain bilingual. No backend,
admin configuration or business-record changes were made in this continuation.
The branch remains integrate/b2b-plus-gokul-dev; native hot reload succeeded.

The matrix now supports an isolated control sweep. Each synthetic fixture turns
off exactly one source display option and retains all other captured settings.
Five language cases (English, Arabic, both filled, English empty and selected
English table headings), three document types and six PDF themes produced 4,980
PDFs: 61 Bill A4 options, 63 combined A4 options and 42 Return Bill options per
language. All 15 generation runs pass. The final audit checks complete coverage,
caption disappearance where the all-on baseline supplies a witness, selected
customer/bank/delivery/payment values and page boundaries. All 4,980 pass those
checks. The 30 repaired PDFs replace matching cases; they are not extra outputs.

The sweep found a real defect in receipt_sections.dart: combined return metadata
checked the customer-name child option without checking showCustomerNameAndPhone.
The shared section builder now requires the master option, preserving existing
child behavior. The thermal return metadata helper consumes the same rows.
All 30 corrected PDFs hide customer name, masked phone and address and pass page
boundaries. Five synthetic master-off thermal fixtures produce 85 outputs with
zero geometry failures and 75 Standard-family pixel comparisons with zero
differences. Reviewed bilingual headers and return tails across three families.
The regression checks both master states in three languages and preserves the
return total. The focused suite passes 29 tests; the final return identity,
price, summary and tax-column suite passes 13 tests. These suites overlap and
their counts are not a unique-test total. Analysis of the three changed files
reports no errors or warnings and three informational findings in the matrix.
git diff --check passes.

Evidence: 2026-09-29_control_sweep_plan.json,
2026-09-29_control_sweep_audit.json and its five per-language reports;
2026-09-29_customer_master_fix_audit.json;
2026-09-29_customer_master_thermal_audit.json; receipt-customer-master-regression.log;
receipt-customer-master-final-regression.log and receipt-customer-master-final-analyze.log.
Artifacts and audit JSONs are under build/receipt_live_audit; render logs are in build.

Footer verification uses explicitly synthetic clones of captured configurations.
Fallback fixtures empty the thank-you option's text while leaving it visible;
hidden fixtures only turn off that option. Source captures remain unchanged.
All 30 document/language render groups pass, producing 414 outputs including
108 PDFs. The checker proves the intended single-option changes, checks supplied
English/Arabic footer field 3 in fallback PDFs and its disappearance when hidden,
and checks page boundaries. There are zero checked failures and all 270
Standard-family pixel comparisons match. Reviewed the bilingual thermal footer
across all three families. The existing footer/field-text contract suite passes
15 tests. No production footer change was necessary. Evidence:
2026-09-29_footer_variant_plan.json, 2026-09-29_footer_variant_audit.json,
receipt-footer-variant-audit.log and receipt-footer-contract-regression.log.

The sweep also exposed a checker error: a numeric return item count of 3 below
an already complete Arabic caption was attributed to footer field 3. The Arabic
marker matcher now avoids extending complete caption anchors and uses the first
aligned suffix for wrapped anchors. Five negative/positive marker tests pass;
the refreshed positioned Arabic audit passes 72 PDFs. B2C caption/amount checks
still pass 30 PDFs and 75 aliases; its exit 2 remains a source-completeness result.
The control and geometry checkers also support Windows extended paths because
some generated verification filenames exceeded 260 characters. Production
receipt filenames were not changed.

Verification remains incomplete. The final sweep explicitly records 870 checks
without a visible baseline caption or selected-value witness (150 English and
180 in each other language). Some summary captions are supplied through resolved
labels rather than display-option text, so the checker needs further coverage;
untagged dates, words, totals and alternate inactive titles also need direct
evidence. These are not 870 proven renderer failures or 870 proven backend
omissions. Thermal individual-option coverage beyond customer/footer controls,
real return allocation completeness, known response omissions, exhaustive visual
review and physical printer delivery remain unresolved. The full goal stays active.

## Resolved labels and active consumer-title control coverage

The prior goal turn made progress by fixing the shared customer master switch,
generating actual outputs and identifying 870 missing comparison witnesses.
This continuation inspected the current section definitions, captured resolved
labels and actual baseline PDFs before strengthening the audit. No production,
backend, admin configuration or business-record changes were made this turn.

The control auditor now maps Return Bill switches to their owned resolved
captions, including table headers, credit-note identity, subtotal/discount/MRP,
return count, refund and amount-in-words. It does not indiscriminately attribute
every resolved label to a disabled control. Five full 996-PDF audits pass; these
resolved-label checks reduce missing witnesses from 870 to 600. Separate direct
checks for fixture dates, invoice identities, amount-in-words, payment breakdowns
and generic summary captions reduce the missing witnesses to 296.

Drawing order alone fragments some mixed Arabic/Latin strings. The checker now
also uses spatially extracted, normalized text for actual comments, payment
breakdowns and Arabic summary rows. Arabic generic return subtotal and final
refund share a caption: switching either off must reduce its occurrence count
while retaining the independently enabled row. The checker explicitly checks
that reduction rather than incorrectly requiring every occurrence to disappear.
This closes the remaining 266 active business-fixture gaps. Incremental passes
recheck previously unwitnessed rows; existing successful rows retain their
evidence and assert the selected artifact path has not changed. All artifacts
were unchanged throughout these runs. Earlier intermediate per-language reports
are preserved as control_sweep_resolved_audit_* and control_sweep_direct_audit_*.

The ordinary business sweep retains 30 missing witnesses: showInvoiceTitle is
the consumer title and is intentionally inactive for the B2B customer. Generated
30 new consumer title-off PDFs (five languages by six themes), using the existing
consumer all-on PDFs as baselines. Every case has a supplied active title marker;
all disappear when disabled. The currency amount multiset, including repeated
amounts, remains identical to its baseline in every PDF. Baseline and disabled
page boundaries also pass. Six checker tests guard caption ownership, original
invoice versus credit-note identity, missing resolved labels, adjacent currency
prefix/suffix parsing and detection of changed/missing amounts.

The combined coverage report links each inactive business title case to its
matching active consumer print: 4,980 business switch PDFs plus 30 consumer PDFs,
zero checked failures and zero missing suppression witnesses. The ordinary
sweep report still records the 30 inactive titles explicitly. This closes the
previous witness gap without claiming that inactive captions printed in the
business fixture or that source completeness passed. All processes completed;
git diff --check passes. No hardware jobs were sent.

Evidence under build/receipt_live_audit:
2026-09-29_control_sweep_audit.json and its five language reports,
2026-09-29_b2c_title_control_audit.json,
2026-09-29_control_coverage_audit.json. Logs in build:
receipt-control-sweep-resolved-*, receipt-control-sweep-direct-*,
receipt-control-sweep-spatial-*, receipt-b2c-title-off-*,
receipt-b2c-title-control-audit.log, receipt-control-coverage-audit.log and
receipt-control-caption-source-tests.log. These scopes prove supplied-caption/
selected-value suppression and geometry, not every possible business calculation,
visual glyph quality or physical delivery. Remaining work includes equivalent
individual thermal-control coverage and the source/data limits stated above.

## Thermal single-control sweep: pilot complete, full workers running

The preceding turn made progress by closing the 870 PDF comparison gaps and
producing active consumer-title evidence. This turn extended the existing actual
output matrix to thermal single-option sweeps. Each thermal theme now gets an
all-on baseline followed by every captured switch disabled independently. The
original PDF sweep behavior and output directories are retained; thermal traces
and PNGs use isolated directories. Return cases use the production return/store
builder, as in the earlier verified baseline. No backend, admin configuration or
business records were changed.

Added a nullable test observer in ArabicPrinterHelper. An assert invokes it
after every row has actually been painted, passing an unmodifiable row list.
The callback invocation is disabled in release builds. The matrix records exact
text/QR rows and measured positions alongside the actual generated PNGs, handles
all registered production row types, and rejects unsupported types. Ordinary
single-line table cells report the actual painter's didExceedMaxLines flag.
This exposes truncation without replacing the renderer or mistaking intended
input text for OCR proof of visible glyphs. The remaining visual limits stay
explicit. The observer is reset in finally after each print.

The bilingual Bill pilot checks customer master visibility, net amount and
thank-you visibility plus an all-on baseline in all 17 registered themes:
68 actual PNG outputs, zero checked failures, zero missing comparison witnesses
and 60 Standard-family comparisons with identical pixels. The thermal auditor
also requires changed painted semantic content to change the PNG, checks row
positions/nonnegative heights and raster widths, and checks configured English/
Arabic caption removal and selected business values. Shared Arabic refund
captions use occurrence reduction; QR visibility is checked against actual QR
rows. These tests do not claim physical delivery or complete glyph readability.

One widget test verifies that the observer sees completed painting, receives a
read-only list and leaves actual black/white image pixels intact. Four negative
marker tests ensure quantities do not become Arabic caption suffixes, bilingual
isolates/line breaks survive normalization, another document's marker cannot
count, and long numeric business data is not accepted as a caption ID. The
existing customer-control/configuration/balance regression suite passes 29 tests.
Final analysis has no errors or warnings, with 12 informational findings in the
helper and matrix. git diff --check passes. Current observed all-on English PNGs
are pixel-identical to previously verified sales, combined and return baselines.

Started three live full-sweep workers, one per document family, each processing
all five captured language cases. The plan contains 61 sales options, 63 combined
options and 42 Return Bill options. With 17 themes and all-on baselines this is
14,365 planned outputs across 15 groups. The workers audit each group after its
generation finishes and stop on a render/audit failure. At the last actual live
handle check, English sales had 146/1,054 outputs, combined 119/1,088 and Return
Bill 125/731; none of the full groups had completed verification yet. These are
generation progress counts, not passing verification results. Do not restart
these workers just because a later observation times out.

Live process handles: sales 97349, combined 39288, return 32650. Plan:
build/receipt_live_audit/2026-09-29_thermal_control_sweep_plan.json. Runner:
tool/run_thermal_control_sweep.ps1. Per-group logs:
build/receipt-thermal-control-{sales|combined|return}-{case}.log and corresponding
-audit.log. Per-root evidence is manifest.json, *.rows.json, PNG files and
thermal_control_audit.json after audit completion. Pilot evidence:
receipt-thermal-control-pilot.log, receipt-thermal-control-pilot-audit.log and its
root's thermal_control_audit.json; receipt-thermal-render-observer-test.log;
receipt-thermal-trace-marker-tests.log; receipt-thermal-trace-regression.log;
receipt-thermal-trace-final-analyze.log and
2026-09-29_thermal_observer_baseline_comparison.json. Full thermal verification,
known source/business-data omissions and physical output remain incomplete.

## Full English thermal results and QR timestamp provenance fix

The preceding turn made progress by adding actual thermal row/PNG evidence and
starting three live workers. They remain the same processes; none was restarted.
This continuation audited completed themes while the workers kept generating.
Partial audits only select themes with an all-on baseline and every captured
option present; they never treat a partial manifest as a completed full group.
Their reports remain distinct from the eventual full reports. Early complete
themes passed all checked controls and measured truncation. A date witness gap
was caused by inconsistent colon normalization between expected text and rows;
the checker now normalizes both identically. No printer date fix was needed for
that comparison issue.

Strengthened the thermal audit with source-language checks: English outputs
cannot contain Arabic configuration captions; Arabic outputs cannot contain
English configuration markers; English markers in bilingual output must be
supplied by that selected configuration. Both Arabic and Latin document-ID
digits are recognized. Title switches also preserve the complete multiset of
printed decimal amounts, including repeated values. Reports retain snapshot and
verifier SHA-256 hashes. Eight marker/normalization/amount parser tests pass.

Full English results: Bill 1,054 outputs, zero failures, 930 alias comparisons;
combined 1,088 outputs, zero failures, 960 comparisons; Return Bill 731 outputs,
zero failures, 645 comparisons. Combined/Return have no missing control witness.
Bill's 17 missing witnesses are the consumer title, inactive for the B2B fixture.
Total completed full English output scope is 2,873; 2,535 comparisons pass.

Separate consumer title baseline/off runs in all five language cases generate
170 outputs (34 per language), with zero failures/missing witnesses and 150
matching alias comparisons. All active title captions disappear when disabled;
every printed decimal amount remains unchanged. Decoded all 170 painted QR input
strings: timestamp 2026-09-26T10:00:00Z, invoice total 40.00 and VAT 4.00. These
are QR input checks, not camera decoding of the PNG or physical scanner proof.
Final source-language/title checks were rerun on the existing outputs with the
latest verifier. Evidence: 2026-09-29_thermal_b2c_title_control_audit.json and
receipt-thermal-b2c-title-{case}[-audit].log, plus each root's audit/traces/PNGs.

A separate inspected provenance defect was reproduced in a failing test:
ZatcaQrHelper.generateQrForInvoice substituted DateTime.now when its transaction
date was missing or unparseable. It now returns no invoice QR in that case.
The six PDF _qrData helpers now return that result directly for a registered
invoice, matching thermal behavior; they cannot fall through to a configured
manual payment QR under the invoice QR caption. Valid parsed dates retain the
same timestamp and encoding path. The existing UTC/zoned/business-timezone tests
continue to pass. No backend data was edited or fabricated.

The new regression covers empty, whitespace, unparseable and literal-null date
strings. Together with return identity tests, six tests pass. Rendered two
explicitly synthetic bilingual date variants (missing and unparseable) with an
active manual gateway fixture: 12 PDFs across all six themes and 34 thermal PNGs
across all 17 themes, 46 outputs total. All omit the configured invoice QR caption;
all thermal traces contain no QR row, all checked geometry/truncation passes and
all 30 thermal alias comparisons match. This verifies the payment fallback is
not substituted in these registered invoice cases. Evidence:
receipt-qr-missing-date-before.log (reproduced failure),
receipt-qr-missing-date-regression.log,
receipt-qr-{missing|invalid}-{pdf|thermal}.log,
receipt-qr-missing-date-render-audit.log and
2026-09-29_missing_date_qr_audit.json. Analysis of the helper, six PDF files and
tests reports no errors/warnings, with six informational findings in the matrix.
git diff --check passes. Native hot reload succeeded after the fix.

Full workers remain live: sales 97349, combined 39288, return 32650, advancing
through Arabic and subsequent cases. Consumer worker 34818 and negative-date
worker 7991 completed successfully; partial-audit workers also completed.
2026-09-29_thermal_control_progress.json records actual completed versus pending
groups. Do not count generation alone as a verified result. Remaining full
language sweeps, source/business-data completeness and physical/visual limits
remain unresolved, so the full goal stays active.

# Receipt language verification — 2026-09-26

Status: IN PROGRESS. Generation is not equivalent to complete verification.

## Requested scope

Five admin documents: Bill 1102, Bill A4 802, Sales and Return Bill 27,
Sales and Return Bill A4 843, Return Bill 28. Test English, Arabic, bilingual
with both sources filled, bilingual with English empty, and bilingual with
selected English table labels only. Cover all applicable 17 thermal and six
PDF themes, field visibility, calculations, return logic, and rendered output.

## Current evidence

- Branch integrate/b2b-plus-gokul-dev. Changes are uncommitted.
- Marionette connected to supplied VM. Chrome browser id2 is available.
- 53 existing focused contract/resolver/PDF tests passed earlier.
- Opt-in test/receipt_output_matrix_test.dart generates 345 artifacts through
  production rendering: 255 thermal cases and 90 PDFs across five document
  flows and five language cases. Output build/receipt_output_matrix_full.
- Initial 345-case run exposed return-only PDF omission of comment, bank and
  QR sections. Added return_pdf_support_sections.dart and integrated into five
  themes, excluding sections each theme already prints elsewhere.
- Rerun after that fix passed generation; PDF text audit reported zero English
  field-marker differences across themes, zero unexpected markers in Arabic
  and blank-English cases, and correct selective English sale-table markers.
- Audit now exits nonzero on theme differences, not just wrong-language markers.
- Another full generation run is in progress after adding six return columns,
  return counts/totals and enabling real warranty data. Session 85436;
  log %TEMP%/receipt-output-matrix-full.log. Poll it before starting another.
  The earlier successful audit does NOT cover these newest fixture changes.

## Live configuration and restoration

- Valid original API backup: build/receipt_live_audit/baseline/active.json.
- English UI field backup: baseline/bill_1102_english_ui.json (51 text inputs).
- Temporarily populated those 51 Bill English fields with QA content and
  activated English. Confirmed API capture bill_english.json.
- Restored all 51 original English values and active language Arabic, saved.
  API capture build/receipt_live_audit/restored.json compared recursively:
  all five document configs match baseline except Bill.updated_at timestamp.
  Browser independently showed active ar and editing ar after fresh navigation.
- The English baseline had only nine table headers populated; all other ordinary
  text fields empty. Rich Terms was never changed. Other languages and four
  documents were never saved/modified.
- Browser proof screenshot timed out; no screenshot file yet.
- API language=en on unfiltered endpoint ignored language and returned active
  configs. Type queries either failed500 or ignored language. Do not use the
  lowercase per-type JSON files left from an unsuccessful early probe; they
  contain invalid empty/stale captures. Use only named valid files above.
- tool/capture_live_receipt_configs.ps1 captures the five configs read-only,
  authenticating from app prefs without displaying credentials.

## Live print attempt

- App Sales list first order ORD-004683, print action tapped once.
- Logs confirm PrintService fetched order, found no returns, selected Microsoft
  Print to PDF, and used cached Bill A4 bilingual configuration. Therefore this
  does NOT prove the temporary English Bill admin settings reached the printer.
- No new output/save dialog was confirmed. Avoid blindly repeating the action.
- App prefs: ordinary paper A4, B2B A5, printer Microsoft Print to PDF;
  development printer selected=false. No app prefs were changed.

## Important outstanding work

1. Finish newest run and rerun Python audit. Inspect actual thermal images and
   PDF pages (text equality alone misses clipping, duplication, missing Arabic).
2. Fixture still uses a superset of bill fields. Add exact live document field
   sets and proper separate Return Bill config/resolved labels. Add combined
   final-summary flags showFinalPurchase/Return/NetAmount/AmountInWords.
3. Potential real defect discovered by source search: showReturnAmountInWords
   exists in live Return Bill config but no production renderer references it.
   PDF/thermal return words currently require resolved credit-note metadata and
   totals. Need reproduce, fix consistent visibility, and test before declaring.
4. Many Return Bill-specific fields (original invoice, HSN, tax columns, reason,
   remarks, authorized signatory) need individual mapping/coverage audit. Current
   synthetic fixture does not prove them. Do not silently treat them as tested.
5. Cover blank-field fallback, off toggles, header/footer/logo/icon, B2C and B2B,
   actual return builder, paper widths/sizes and admin-to-app cache refresh.
6. Live UI all-language testing is still incomplete for all five documents.
   Back up each language durably before edits; restore afterwards.
7. Most legacy thermal IDs delegate to StandardReceiptLayout; premium and
   premium2_bilingual are separate. The manifest preserves requested theme IDs.
8. Live UI hints treat store fields as overrides, while app sometimes treats
   them as labels + store data; audit requirement before changing semantics.

## Commands

flutter test test/receipt_output_matrix_test.dart --dart-define=RECEIPT_OUTPUT_MATRIX=true --reporter expanded
python -X utf8 tool/verify_receipt_output_matrix.py

Bundled Python: C:/Users/gokul/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe
pdfplumber rendering works; fitz is unavailable.

Goal remains active; do not claim full completion or mark it complete.

## Later update in the same verification session

- Expanded 345-output run (with actual return-table columns and warranty) passed.
  PDF text audit again found no theme field-marker differences.
- Added regression test test/receipt_return_words_test.dart. It failed on the
  original implementation when showReturnAmountInWords=true and return totals
  hidden. Fixed receipt_sections.dart plus standard, premium, and
  premium2_bilingual thermal renderers: words now use their own visibility
  control and configured language label, independently of total-row controls.
- 54 focused tests now pass. A new 345-output run is active as session 41346
  to validate this second production fix. Earlier session 85436 is complete.
  Follow with tool/verify_receipt_output_matrix.py; it now explicitly requires
  all ten return markers EN62X..EN71X in English and fully bilingual return PDFs.
- The open return-words defect in item3 above is now fixed at shared/unit level;
  full rendered-output validation of that fix is still pending this newest run.
- Visually inspected classic bilingual return page2 with populated return table,
  bank and QR: readable and no obvious clipping. This was BEFORE the words fix.
  Screenshot: build/receipt_output_matrix_full/return-both-classic-page-2.png.
- Browser screenshot repeated with clipped viewport still timed out. DOM and API
  restoration confirmation succeeded. No screenshot proof file was obtained.
- No live configuration remains modified by this test session.

## Return Bill coverage gap found by source scan

The live Return Bill API contains these15 controls with no literal references
anywhere in lib (not merely missing from one theme): showGstSubtitle,
showSupplierDetails, showSupplierGstin, showCustomerGstin, showOriginalInvoice,
showHsnCode, showUnitPrice, showTaxRateColumn, showTaxAmountColumn,
showTaxableColumn, showGstBreakdown, showTaxRow, showTaxSummary,
showCreditNoteRemarks, showAuthorizedSignatory. These need data-source and
rendered-behavior analysis and implementations/tests as appropriate. A source
scan alone is not a rendered proof; do not dismiss or claim them covered.

Visual follow-up: latest English Return Bill premium and standard thermal PNGs
show the new EN71X heading + Eleven Riyals Only, confirming the words fix in
those paths. They also reveal serial-number return header EN62X truncated to
EN6... (single-line ReceiptTableRow). Investigate using common
MultiLineReceiptTableRow for all return-table headers, not only bilingual.
Premium imports common/layout_rows.dart; premium2 currently uses base rows from
utils/arabic_printer_helper.dart and would need the shared multiline row import.
Full visual review of other headers/themes remains pending.

Thermal clipping fix applied after newest matrix started: all sale/return table
headers in standard/premium/premium2 now use the shared multiline header row.
It shrinks to the configured minimum then wraps rather than ellipsizing. Needs
fresh generation/visual verification; active session41346 compiled before this
change. Do not count its PNGs as verification of the header-clipping fix.

Latest completion: session41346 generated all345 cases successfully after the
return-words fix; Python audit session67202 exited0, including the new required
EN62X..EN71X return-field expectations in all applicable English/bilingual PDFs.
Header wrapping changes compiled and passed11 relevant tests, but were applied
after session41346 compiled. A fresh full output pass is the next verification.
Current active output run: session66855 (header-wrapping verification). Poll before restarting. After completion run Python audit, then visually inspect English return thermal EN62X no longer ellipsized. Live admin remains restored; goal active.

## Current continuation: real-admin Return Bill coverage

- Previous turn was progress. Session66855 finished all345 artifacts and Python
  audit9478 exited0. Visually checked standard English Return thermal: serial
  label EN62X now wraps rather than ellipsizes. Other effective thermal themes
  still need visual checks (source paths all use shared multiline header rows).
- Inspected actual Return Bill admin layout. Confirmed one customer-block flag
  showCustomerNameAndPhone, while old rendering checked sales-specific flags.
  Also confirmed credit-note number/reason controls were bypassed by resolved
  labels. New test receipt_return_controls_test reproduced failure.
- Fixed shared return-section controls. Added common/return_metadata_rows.dart
  and routed standard, premium, premium2 thermal metadata through it, removing
  duplicate logic. Customer phone shares existing masking/walk-in privacy.
  Updated one source-architecture test to expect shared helper use; behavioral
  regression checks now live in receipt_return_controls_test.dart.
- Added RECEIPT_CONFIG_SNAPSHOT dart-define to output harness. With an API JSON
  snapshot, it renders69 cases (all applicable themes across the five document
  configs) using DocumentConfig.fromJson and preserves real field/control sets.
  Output root build/receipt_live_render_<snapshot filename stem>.
- Rendered restored.json successfully (session17224). All six Return PDFs show
  customer/name/phone/address and omit hidden Damaged reason. Evidence file:
  build/receipt_live_render_restored/return_controls_audit.json.

### Live Return Bill edits and restoration (important)

- Saved bilingual activation on28 to inspect API, then restored English.
  Admin automatically normalized previously-null theme to simplified_tax_invoice.
  No empty theme choice exists in the UI. This theme change remains saved.
- Populated all57 ordinary English translation inputs with ER1X..ER57X markers,
  using valid dummy email/phone. Did NOT change rich Terms, company settings,
  flags, or other languages. The inputs are arranged across Header (0..12),
  Parties (13..28), Items (29..41), Totals & tax (42..50), Footer (51..56).
  DOM getClientRects visibility includes inactive panel fields; use these known
  ranges after selecting the correct tab, not global element visibility.
- Durable baseline fields: build/receipt_live_audit/baseline/return_28_english_ui.json.
  CUA variable qaReturnEnglishFields retains original fields; contact values in
  tool output may be redacted. Durable JSON has exact contacts from baseline API.
- Saved English test response return_english_filled.json, then activated bilingual
  and captured return_bilingual_english_filled.json.
- Restored all57 original English inputs and active English; verified against
  restored.json using capture return_content_restored.json: all four other docs
  identical; Return differs ONLY theme and updated_at. No test content remains.
- qaReturnTab is claimed user tab1393685561, currently list page after save;
  user tabs persist without a handoff mark. No new ephemeral page to preserve.

### Confirmed backend gap — user question pending

- With custom English credit-note fields populated ER26X(number), ER20X(customer
  name), ER51X(words), bilingual API returns generic credit_note_number/default,
  customer_name/default and amount_in_words/default, NOT the typed English text.
- In the same bilingual response showReturnParticulars.default correctly carries
  ER32X. Thus English table labels are transmitted but credit-note metadata
  English labels are lost upstream. Do not substitute generic English defaults
  or infer typed values from master resolved_labels.
- Asked user asynchronously for backend/admin source repository or local path.
  Not blocked overall: many independent renderer/admin tests remain.

### Additional renderer fixes from live English markers

- All six PDFs initially omitted five real configured labels: ER20X customer
  name, ER21X phone, ER22X address, ER40X grand-total header, ER51X words heading.
- ResolvedLabels now preserves additionalLabels from JSON and toJson; text(key)
  allows new credit-note fields without discarding them. Shared return sections
  consume those labels. All three thermal table headers consume grand_total_header.
- 55 focused tests passed after these fixes. Snapshot rerun1112 passed69 outputs;
  text extraction showed all five markers now present in every PDF theme.
- That comparison revealed boxed_bilingual omitted document header/subheader
  ER1X/ER2X. Added them above its metadata strip, consistent with other themes.
- New tool/verify_live_return_output.py asserts the27 visible ER markers across
  all six PDFs, explicitly not claiming store override/thermal/other-language
  coverage. Hidden fields retain original off switches; footer ER3X is currently
  a fallback to populated thank-you ER56X (shared existing contract).
- Active run32688 is regenerating69 outputs after boxed header fix. Poll then run
  Python verifier above. No other rendering process is pending.

### Still outstanding

Original full scope remains.15 missing Return controls remain mostly unimplemented,
all-language live admin test sequence for all five docs incomplete, full image QA,
logo/width/paper tests, all flags/data/calculations coverage outstanding. Also check
store-text override semantics: admin hints say override actual store data, while
some app fields currently label + append active-store data (e.g. store address,
telephone/email). Do not count marker presence alone as correct value semantics.
Run32688 completed69 outputs successfully. No rendering processes remain. verify_live_return_output.py result is recorded in build/receipt_live_render_return_english_filled/english_marker_audit.json.
Visual QA: boxed-return-english-page-1.png in live render output is a single readable page with all27 expected markers. It also directly shows the store override issue (5550100: 555 and configured email: store email). Fix value semantics next; marker equality alone does not validate that. No processes remain. Backend path question still pending.

### Current continuation state
Return28 is currently active Arabic with all57 ordinary Arabic fields filled test values. Arabic original UI backup: build/receipt_live_audit/baseline/return_28_arabic_ui.json. English is restored; bilingual not yet edited. Browser editing language en_ar only (unsaved). Must restore Arabic and activeEnglish after tests. Theme normalization exception remains.
Return price fixes preserve nested cart unit_price, cartItemId and MRP through return models/list actions and shared rate resolution; explicit zero honored. New return price regressions included;62 focused tests passed. Full345 render70898 and Arabic snapshot69 render43574 exited0; audits pending. Fixture now has two sale/return items and final-summary markers72..75.
Store override semantics and backend source questions pending user answer; continue independent verification.

### Return bilingual live cases completed and restored
- Saved actual admin/API cases return_bilingual_both_filled.json, return_bilingual_empty_english.json and return_bilingual_table_english.json. Each generated69 outputs without exceptions (42770,89210,22313 complete).
- Bilingual Arabic fields used distinct `ثنائي N` markers (not Arabic-only `عربي N`), English ERnX. Table-only English fields31,32,34,36,40,41.
- tool/verify_live_return_bilingual_output.py records honest failing results: both-filled0/6 PDF themes (15 English labels missing); empty-English6/6 marker checks; table-English0/6 (ER40X Grand Total missing). API contains generic grand_total_header_default rather than typed ER40X, same as metadata gap. Backend source still needed. Audit scope excludes raster, Arabic visual completeness and unmarked generic English leakage.
- Original English/Arabic/bilingual57 fields restored via UI; activeEnglish restored. Actual API return_all_languages_restored.json matches return_content_restored.json for every top-level configuration field across all five docs. Earlier null-theme normalization exception persists; original terms/company/flags untouched. No test text remains in ordinary translation inputs after restoration.
- Full345 generation completed;90PDF text checks passed with no theme marker differences. Final summary72..74 present across all6 English SalesReturn A4 PDFs. Verifier now requires them for en/both.
- Visual selective-English simplifiedPDF has proper two distinct return rates11 and5, totals11 and10, refund21. Evidence return-selective-english-page1.png. Shows missingEnglish grand-total label and unresolved store override ambiguity.
- Visual standard80mm thermal has same correct return prices but adjacent header labels touch. Added4pixel minimum gutter to common multiline table headers; rerender32881 running (receipt-live-table-gutter.log). Needs visual verification before counting fixed. Analyzer1944 running (receipt-price-analysis.log).
- Full remaining scope unchanged: other four live-admin full sequences, missing15 credit-note controls, all flags/layout visual checks and cache/native routing. Goal active, not complete.
Rerender32881 completed69 outputs successfully after4pixel gutter. Inspected updated standard80mm thermal standard_QA59_80mm_1790407207207496.png: English labels retained (longSLmarker wraps), return values11/5 and21total correct; overall headers remain dense, so broader58mm/theme visual QA still required. Analyzer1944 has not returned; no clean-analysis claim. Backend failures retained by new live bilingual verifier (exit1 expected until fixed).

### Continued credit-note controls audit
- Previous turn classified progress (new live bilingual failure evidence and fixes). Analyzer1944 completed: no compiler errors;19 diagnostics including existing style/context notices and unused build_dialog_box import. No process1944 remains.
- Implemented showGstSubtitle and showAuthorizedSignatory in shared ReceiptReturnsSection, all6PDF themes and3thermal implementations used by17theme registrations. Visibility false suppresses populated labels. Thermal signatory helper and PDF signature line retain label beneath a writing area.
- Live Return28 English test enabled both switches and populated LIVE SUBTITLE CHECK / LIVE SIGNATORY CHECK; captured return_extra_controls_on.json. Then disabled switches while keeping text, captured return_extra_controls_off.json. Each69 render succeeded. PDF extracted-content checks: exactlyonce whenon andzero whenoff in all6themes; saved extra_controls_pdf_audit.json. Standard80mm on-image visually inspected successfully.
- Restored both textfields empty and switchesfalse throughUI. return_controls_restored.json differs from prior baseline ONLY Return28.updated_at. No other doc or flag changes; previous null-theme normalization remains.
-50 focusedtests passed after controls implementation. Full345 matrix now includes markers76subtitle/77signatory across all5languagecases, verifier requires them for returndocs en/both. Run94195 stilllive (receipt-output-extra-controls.log), not yet audited.
- Visual controls test exposed return-only blank-title fallback INVOICE. Changed shared default to CREDIT NOTE / إشعار دائن, thermal3now use shared invoiceTitleText insteadduplicateddefault.18 relevant tests passed. Latestliveon snapshot rerender in receipt-credit-title-render.log pending to verify all6PDF/17thermal with new fallback; noadminchange needed.
- Remaining unimplemented Returncontrols now13, including supplier/customer tax, originalinvoice, tax/itemextra columns andremarks. APIalsoomits filled remarksbodyER54X (must confirm backendmapping; never substitute heading forcontent). BackendmissingEnglishlabels andstoreoverridequestion remain pending. Wholegoalnotcomplete.
Latest rerender21191 completed69 outputs. All6ReturnPDFs contain CREDIT NOTE fallback (no INVOICE title) and exactlyone enabledsubtitle/signatory. Saved title_audit.json in live extra-controls-on root. This fallback problem affected directrenderer params; production ReturnBill builder already had a title override, so do not overstate it as provenliveapp titlefailure. Removed unused sales_return_list build_dialog_box import; gitdiffcheck passed.
Full345 run94195 confirmedstilllive after21191 ended; poll94195 next, thenrun tool/verify_receipt_output_matrix.py redirecting verboseoutput tolog. Current matrix includes76/77 markers; titlefallback codechanged after94195 began, so use21191 for titleproof.
Independentnextaudit: salesReturnItemUnitPrice currently prefers positivecartprice but drops explicitzero and chooses summarylineprice before hydratedloadedunitprice. CartItem parser defaults missingunitprice to0.00, so preserve presence if fixingfree-item path. Existingzero testonlycovers OrderReturnItem/renderlookup, nottransactionhelper; need regression forhelper. Backend repository search in D:/Projects/ENKE for composer.json/DocumentPrintConfiguration foundnone. Otherliveadmin language sequences and13controls still outstanding.
Run94195 completed345 outputs and verifier30068 passed90PDF checks including new76/77fields and finalsummary72..74; no theme differences or unexpectedEnglishmarkers in Arabic/emptyEnglishcases. All processes from this round are terminal. Fullgoal remainsactive with explicitlyrecordedgaps.

### Current BillA4 live test state
Previous turnprogressconfirmed. Free-item/loadedprice regression initiallyfailed(actual60expected0). AddedhasUnitPricepresence tosummaryCartItem andSalesReturnCart, preserveoriginalpresencewhenparserfillsUIpricefallback, preferexplicitcart/loadedunitprices inclzero, guardmissingcartID0match.8relevanttestspassed. Originalambiguoussummarypricefallbackunchanged; needsconfirmedAPIsemanticswhenbothunitpricesabsent.
BillA4(802)nowtemporarilyactiveEnglish, originalactiveen_ar. No testtextsavedyet. OriginalEnglish51fields in browserqaA4Original.en; originalbilingual51fields inqaA4Original.en_ar. OriginalAPIbilingual inreturn_controls_restored.json; Englishbaseline bill_a4_english_original.json. Arabic notyetvisited. Contactsoriginalbilingual tel+966112345678(withspaces), emailinfo@example.com, deliveryphone+966501234567(withspaces) capturedactualAPI. Workingbrowserhandle qaReturnTab nowshows802 (namehistorical). User802tabclaimfailedtransientCDP, reusedworkingtab; existingbrowser2connected.

### BillA4 all five live-language cases captured and restored
- BillA4 802 editedall51 ordinarytextfields for English A4EnX, Arabic `عربي N`, bilingual `ثنائي N`. TestedallEnglishblank thenonly8visible tableheaders20,21,23,24,25,26,27,28. RichtextTermswasnull inallbaselineAPIcaptures, unchanged. Saved bill_a4_english_filled, bill_a4_arabic_filled, bill_a4_bilingual_both_filled, bill_a4_bilingual_empty_english, bill_a4_bilingual_table_english JSONs; each69generatedoutputs.
- tool/verify_live_bill_a4_output.py provides30PDFtheme checks. English0/6: configuredbank/accountfields37..42missing; APIall6valuesnull althoughfilledUI. Bilingualboth0/6: same6banklabelsplusEnglishheader1/subheader2missing. Arabic/emptyEnglish/selectiveEnglish6/6eachEnglish-markerchecks(noassertionofArabicvisualcompleteness). TableEnglishexact8markersallthemes. Bank label loss isadmin-to-API issue; couldbesavingormapping, backendneededtodistinguish.
- Allthreeoriginal51fieldsetsrestoredfrombrowserbackup plusactualAPIcontacts (browserredacts3bilingualcontacts andEnglishdeliveryphone; replacedwithknownoriginalvalues). Activeen_ar restored; bill_a4_restored.json differsfromreturn_controls_restored.json onlyBillA4.updated_at. Noordinarytesttextleft, otherdocsunchanged.
- APIoriginalEnglish baseline captureinitiallywrong en_ar dueconcurrentreactiveselects; overwrittenafterverifyingrealEnglishactive andcapturingagain. Currentbaselinefilescorrectlanguage. BrowserqaA4Original holds3fieldsets, qaReturnTabhistoricalname now802/list.
- Visual boxedheaderA4 selectiveEnglishpage inspected:8headingsshown, onlySLmarker wraps, Arabiclabelsreadable; genericbanklabelsconfirmmissingtypedbanklabels. Foundfixturetaxinconsistency: twoitems tax2each butapiTax2; changedfixtureapiTotalTaxto4forsales,0forreturnonly (consistentwithproductionbuilder). Alloldermarkerchecksremainusefulbutdonotclaimoldnumericfixtureasaccountingproof. SelectiveA4rerender63721 live toverifycorrectednumericfixture; logbill-a4-table-tax-fixture.log. Needregeneratebill-a4-page1.png afterrun.
- Remaininglivefullsequences: Bill1102 (onlyEnglishdoneearlier), SalesReturn27, SalesReturnA4843. Return28andBillA4802 all5capturedwithknownfailures.13Returncontrols +broaderflags/width/logo/paper/cache/nativeprint remain. No backendrepo found inD:/Projects/ENKE; userbackendpath/storeoverrideanswerspending.
Run63721 completed69 outputs. Correctfixture arithmetic is pre-discount subtotal38 - discount2 +tax4 =net40 (initialad-hoc expectation36 waswrong; source/printedrows show38consistentallthemes). SixPDF amounttokenchecks passed38/4/40; savedamount_token_audit.json, regeneratedboxedheaderpage1image. This checks tokensandknownfixtureequation, notallrealtransactionaccounting. Allprocessesfromthisroundterminal; goalactive.

### Customer block and tax-row continuation
- Previousgoalturnprogress. Regressionprovedblankcustomername incorrectly suppressedphone/address; sharedreturnsSection nowtests eachavailablevalue withinenabledcustomerblock.20focusedtests passed (receipt_return_controls, prices, sharedfields, layoutcontract).
- showCustomerGstin nowprints existingcustomerVatNumber with configuredcustomer_gstinlabel; taxrowrequiresparentcustomerblock andownswitch. This isPARTIALcontrolcoverage: placeofsupplynotcarriedinparamsyet. Do not decrementremaining13controlsasfullycomplete.
- ActualadminReturn28 customerGSTswitchenabledwith LIVE CUSTOMER TAX ID thenoffwithlabelretained. Captured return_customer_tax_on/off.json, each69renderswithnew --dart-define=RECEIPT_CUSTOMER_NAME_EMPTY=true; outputroot suffix_no_customer_name avoidsoverwritingnormalfixtures. TwelvePDFchecks passedtaxlabelonceon/zerooff, phone+addresspresent, QACustomerabsent. Reportcustomer_tax_pdf_audit.json. Standard80mm onPNGvisuallyverifiedreadablephone,address,taxrowwithoutname.
- Originaltaxlabel(empty) andswitchfalse restored; return_customer_tax_restored.json differsfrombill_a4_restored.json onlyReturn.updated_at. Othersunchanged. Noexternallysavedtestsettingsremain.
- Fullmatrix now includesmarker78showCustomerGstin, verifierrequires78forreturnen/both; run33221 currentlyliveinreceipt-customer-full-matrix.log. Pollthenrunverifier; nootherpendingprocess.
- Added docs/receipt-backend-contract-gaps.md withconfirmedpayloadfailures, sourcepairsemantics and retestgates. Distinguishesbackendconfirmedmissingtypedvaluesfromdatafieldsstillunderinvestigation. No backendpath/userstoreoverrideanswer received.
AdditionalflatAPIpricefix: SalesReturnItemparser no longer overwritesexplicitflatunit_price withsummarypricewhen nestedcartunitpriceabsent. Addedassert5unitpricevs60lineprice;8price/modeltests passed inreceipt-flat-price-tests.log. Fullmatrix33221 doesnotexerciseparser directly; dedicatedtestsproveparserfix.

### Current Bill1102 live sequence
Full345customer run33221completed;10775PDFauditpassed90including78. SalesReturnA4 843inspectednotsaved: APIthemenullmapsClassic,UIhasneitherunsetnorClassic; savingwouldforceSimplifiedandcannotrestorethroughobservedUI. Addedbackendgap; deferdependentliveeditsuntilrestorepath/finalthemepreferenceknown. No843changesmade.
Bill1102currentlyhas51Englishfields B1EnX and51Arabicfields `عربي N` testcontent, activeen_ar afterbaselinecapture; bilingualfieldsstilloriginalatthischeckpoint. OriginalarAPI=return_customer_tax_restored.json; originalenAPI=baseline/bill_1102_english_original.json; originalbilingualAPI=baseline/bill_1102_bilingual_original.json. BrowserqaBill1102Original.en/ar/en_ar backup51fields, butcontactredactionsneedoriginalAPIvaluesbeforeRestore. Originalactivear, themesimplified_tax_invoice. Mustrestoreallthreefieldsourcesandactivear.
AddedoptionalRECEIPT_DOCUMENT_FILTERtoharness; defaultstill345. SnapshotBillfilteroutputs17thermalthemesinroot_only_Bill. Unknownfilterfails; validatesexpectedcount17. Avoidsrerenderingunchangedotherdocs. Runs62572English/48887Arabicstarted; pollbeforeaudits. Thisfiltersapplicableflow, doesnotclaimPDFtestingforBill1102.

### Bill1102 five live captures complete, restoration verified
All5casesEnglish/Arabic/bothfilled/emptyEnglish/sevenEnglishheadingscapturedand17thermaloutputspercasegenerated. Original51fieldsinallthreeEnglish/Arabic/bilingualsourcesrestoredthroughUI; redactedcontactsrecoveredfrombaselineAPIvalues. Originalactivear restored. bill_1102_restored.json differsfromreturn_customer_tax_restored.json onlyBill.updated_at; otherfourdocsunchanged. OriginalArabicrichTerms(nonempty) neveredited; English/bilingualrichTermsnull. Thisordinaryfieldsequence doesnotproveeditable-richtermscoverage.
Visualstandardboth/empty/tableimagesinspected. SevenEnglishheadingsvisibleintablecase, non-tableEnglishmarkersabsent; emptycasehasnone; bothcaseconfirmsEnglishheader1/subheader2andbank37..42missinglikeBillA4. Storeoverrideambiguitypersists. Noallthemevisualpassclaimed.
Factoryinspection:15themeIDs(includingstandard) shareStandardReceiptLayout, remainingpremiumandpremium2_bilingualareindependent. ChangedharnessorderNumberfrompercaseQAserialtofixedQA-VERIFY soaliaspixelscancompareexactly. Sequentialrun57275rerenderingall5Billcases(85images)withstabledata;eachcasehaslogbill-1102-stable-CASE.log. Poll57275thenrunnewtool/verify_live_bill_thermal_equivalence.py. ItcomparesactualRGBApixelhashesandmustnotbepresentedasOCR/correctnesscheck. Outputsreport3distinctvisualreviewfilespercase;reviewremainingimagesafterequivalenceaudit.

### Bill thermal visual review and new totals fixes
- Run57275 completed85 stable-ID outputs. Pixel audit passed all15 standard aliases in all5cases. Visually inspected all15 distinct images (3renderers x5cases). EmptyEnglish showed no configured English markers; selectiveEnglish retained7headings. Bothfilled confirms knownmissingEnglishheader/subheader and banklabels. Allcases showbankgenericfallback; noallfields-passclaim.
- Visualreview found independent MRP total omitted byStandard/Premium andall6PDFs whilePremium2printed48. SharedtotalsandthermalStandard/Premium nowseparate showSubTotal (38) andshowMRPTotal (48), labelsandvisibilityindependent. Shared mrpTotalValue uses existingnet+savings. AddedfallbackMRPtext. Regressiontests fourvisibilitycombinations pass. PDFmatrixverifier nowrequiresEN34XandEN49X onsalesen/both.
- Premiumtotals rowheight used fontsize+8 insteadactualArabicfontheight, causingcrowding/separatortouching. ReplacedduplicateboxdrawingwithsharedmeasuredStandardBoxedTotalsRow adapter, preservingitemvalues/scales/icons. DedicatedloadedArabicfontheightregressionpassed.
- Tokenlabelsendingdigit (Arabicmarker8) mergedwithtoken42as842. SharedtokenTextnowaddsseparatorfordigitendinglabels; symbol#remainsattached. Regressionacross3languagespassed.
-18focusedMRP/shared/layouttestspassed;10shared/token/thermalspacingtestspassed. Full345run6395 stillrunning (receipt-mrp-full-matrix.log); startedafterMRPbutbeforetoken/spacingfixes, useitforMRP/PDFproofonly. Run38207completed85MRPoutputs beforefinaltoken/spacing; supersededby26041 currentlyrerendering5Billcases withallfixes (bill-1102-final-CASE.log). Needpoll26041thenrerunpixelhashauditandinspectupdatedPremiumtotals/token/MRPimages. Analyzer41841 stillrunningreceipt-mrp-analyze.log.
- SalesReturn27 admin inspected, NOTsaved. Like843 itsAPIthemeisnull whileUIselectsSimplifiedwithnoblankoption; deferliveeditsuntilrestorabletheme/backendpathresolved. No newadminchanges thisround; allpriorrestorationstate retained.
Finalrun26041completed85allfixesoutputs, pixelaliasauditpassed15/15each5cases. UpdatedPremiumArabicimagevisuallyconfirmsdistincttokenlabel8andvalue42(separatedcolon), MRP48andnet38separate, totalsglyphs/separatorwithcleargaps. UpdatedPremiumandStandardbothfilledimagesalsoinspectedMRP48andspacing. Nohardwareproof. Full345run6395completed; PDFaudit52657 resultpendingpoll. Analyzer41841completed35diagnostics,noerrors; includedunusedproductNamewarningremovedandtwo newconstinfosfixed; remainingstyleinfosnotacleananalysisclaim. Allrenderprocessesterminal.
PDFaudit52657completed exit0: all90PDFtextchecks passed, including independent MRP EN34X andsubtotal EN49X for sales English/both. No processes from this round remain. Goal remainsactive: backendmapping, two live SalesReturn language sequences/theme restoration, remaining13Returncontrols and wider physical/native/58mm/A5/logo/richterms/visibility cases still outstanding.

### Narrow paper and real return builder continuation
Previous goalturnprogress. AddedexplicitRECEIPT_THERMAL_PAPER/PDF_PAPER harnessoptions withisolatedrootsandpaper inmanifest. Run98438finished345outputs58mm/A5. Existing90PDFmarkerchecks39255passed. Newverify_receipt_paper_geometry.py31700checkedall345:correct384pxthermal/A5pages andnoPDFglyphoutsidepage;0failed. Thisdoesnotproveallvisualreadability. InspectedEnglish58mmstandardandall3bilingualSalesReturn58mmimages:9sale/6returncolumnsretained,verydenseSLlabels wrapseverallines; totals40/return21/final19consistent. InspectedfirstpagesArabicClassicA5(3pages)andBoxedHeaderA5(2pages);allpages/fullthemevisualQA stilloutstanding.
Realbuilderregression50016failed expectedBusinessreturnactualSalesReturn:blankbaseinvoicetitle causedReturnBillLayoutParamsBuildertooverrideconfiguredB2Btitle. Removedredundanttitleoverride/helper soReceiptLayoutParamsownsconfiguredtitle/visibility/defaults. Fivebuilder/mobile-title/return-controls tests81145passed acrossEnglish/Arabic/bothandhiddentitles. Noadminchanges.
NewoptinRECEIPT_RETURN_BUILDERforcesReturnBillfilter, usesrealbuilderandblankbasewithconfiguredB2Btitle. Run11604currentlyrendering115outputs (5casesx23) rootbuild/receipt_output_matrix_full_builder_only_Return-Bill. Needpollthenruntool/verify_return_builder_title.py (30PDFtitlechecks and85rasterdimensionchecks) andvisuallyinspectbilingualthermal+PDFtitle. Nootherprocesspending. Fullgoalstillactive withbackend/liveSalesReturntheme/restoration/13controls/native/otherdata+visibility coverage outstanding.
Run11604completed115real-builderoutputs. verify_return_builder_title.py passed30PDFtitlechecks: configuredEN31X exactlyonceEnglish/both, noneinArabic/emptyEnglish/tableEnglish, noSalesReturnoverride;85thermalimagescorrect576pxdimensions. Visuallyinspectedstandard80mmbothandBoxedHeaderA4bothPDF:configuredArabic31+EnglishEN31Xtitlebothpresent, returnrates11/5andrefund21correct. Duplicatecustomerblocks presentinall these syntheticReturnconfigs (noresolvedcredit-note metadata); notclaimedcomprehensivevisualpass. Allprocessesterminal. Pendingfullgoalunchanged;thisturnprogresswithnarrowformatcoverage+productionbuilderfixandprintretest.

### Independent Return Unit price column verified
- Admin Items tab explicitly labels Rate as a duplicate of Unit price. Added independent showUnitPrice column using the existing return unit rate to shared PDF sections and all three thermal renderers; label fallback supports English/Arabic. No invented price source.
- Four visibility combinations (Unit price/Rate) and positive/explicit-zero rates covered by regression; 13 focused tests passed. Synthetic matrix now includes EN79X for Unit price. Full run65710 completed345 outputs; verifier39724 passed all90 PDF marker checks including new79 for Return English/both.
- Saved actual Return28 Unit price on with LIVE UNIT PRICE; captured return_unit_price_on.json. Saved switch off retaining label; captured return_unit_price_off.json. Rendered23 outputs per case (six PDF,17 thermal). New tool/verify_live_return_unit_price.py passed12 PDF checks: label once on, absent off, rates11/5 present with independent Rate column. These value-token checks do not prove table cell coordinates.
- Visually inspected all three distinct thermal on images: seven headings retained, Unit price11/5 matches Rate11/5, quantity1/2 and totals11/10 preserved. Long test label wraps into three lines without overlap. Existing mixed Arabic product-name direction differs between Standard/Premium2 and Premium; not treated as complete visual parity.
- Restored original empty Unit price text and disabled switch. Fresh before baseline/return_unit_price_before.json versus return_unit_price_restored.json matches all five documents except updated_at. Earlier Return28 null-theme normalization exception remains; no new restoration exception.
- Company tab inspection confirms separate company name/GST/state/address controls; captured API lacks a corresponding company-detail data object. Those overrides remain unresolved pending backend/source semantics.
- Remaining Return controls count now12, including partially supported customer GST/place-of-supply. Full goal remains active: backend bilingual metadata/header/bank/remarks mapping, two SalesReturn live sequences/theme restoration, remaining controls and native/hardware/other data and visual coverage. All processes from this round are terminal. No live test values remain.

### Final-summary amount-in-words visibility regression
- Previous goal turn was progress (Unit price implementation, live on/off print verification and restoration).
- New regression reproduced incorrect PDF final words when Final Net Amount is hidden: it used the last visible row (e.g. refund21 instead of final balance19). All three thermal renderers and PDF sections also suppressed final words when every numeric summary row was hidden.
- Shared finalSummaryWordsLines now computes order total minus return total independently of row visibility and honors its own switch. All six PDF layouts allow words-only sections without an empty table; three registered thermal implementations allow words-only sections too. Return-only callers remain excluded from final sales-minus-return summary.
- Regression covers16 flag combinations in each of3languages (48 combinations). Focused words/control/layout run39472 passed13tests. Analyzer54020 ended with43 style/dependency infos, no errors or warnings; not a clean-analysis claim.
- Added RECEIPT_FINAL_VISIBILITY mask to synthetic renderer harness; masks0 (everything off),8 (words alone),10 (return numeric row + final words). Snapshot inputs are disallowed for this override. New tool/verify_final_words_visibility.py expects90PDFchecks across masks/themes/languages; NOT RUN yet.
- Process87997 is RUNNING: sequential6render jobs (3masks x thermal SalesReturn85 + A4SalesReturn30) for345 outputs total. Latest observed mask0 bothdocs complete115; mask8 next. Logs TEMP/final-words-MASK-Sales-and-Return-Bill[-A4].log. Do not restart; poll87997. After terminal success run verifier, inspect English/Arabic words-only thermal and PDF outputs. No admin edits this round.
- Independent source inspection identified a next numeric edge: Premium/Premium2 return block parses comma-formatted return_total_amount without stripping commas while final summary strips them; missing return totals also use0in return block vsline-sum in final summary. Not fixed or tested yet; follow with shared total resolution and focused regression if confirmed.

### Final words print audit and return-total consistency
- Previous goal turn was progress. Run87997 completed345visibility outputs (masks0/8/10 across all5languagecases and17thermal/6PDF SalesReturn themes). Verifier83246 passed90PDFchecks. Arabic extraction uses NFKC plus observed visual word-order sequence, not a false assumption of logical glyph order. Inspected Standard/Premium English and Premium2Arabic words-only thermal plus ClassicArabic PDF page2: final19words present without numeric final rows. Dense Arabic return headers remain a visual QA concern; not an all-layout readability pass.
- Regression confirmed missing return_total_amount printed0in return block while final summary used21fromlines. Introduced shared returnTotalValue: explicit numeric (including0, strippingcomma/whitespace) wins; missing/invalid uses returned quantity*shared unit rate. Shared PDF totals/refund words/finalsummary/finalwords and3thermal renderers use it. Premium/Premium2 previously failed comma-formattedrefund parsing.
- Six focused tests passed afterfix, including missing/empty/invalidtotal, comma1200.50, explicitzero, ordinary21andvisibility/languages. Synthetic harness adds total_case missing/comma/zero andscenariofilteren withisolatedroots. Process47894completed87outputs (3cases x Return23+SalesReturnA46). tool/verify_return_total_cases.py passed36PDFwordchecks (refund21or0; final19or40). Thermal Premium zero andPremium2comma imagesvisuallyverified totalsandwords. Thischecks declared refund authority evenwherezero deliberatelydiffersfromlines; notanassertionrealtransactionrefund alwaysdiffers.
- Actual ReturnBillLayoutParamsBuilder regression83884failed expected21.00 actual0.00 for0,021.00. Normalizedcommas/whitespace inbuildertotal andfallbackcarttotal. Sixbuilder/price/wordtests88975passed. Render30284completed23outputs viarealbuilderwithcommafixture;6PDFchecks confirmed refund21andwords. Harness nowpassesfixture.orderReturns.returnTotalAmount intobuilderwhenavailable.
- Analyzer79192 reportednoerrors/warnings,3infos:twoexistingasynccontextnotices andnewmissingbraces;newbracesfixed. No functionalchangesafterprintchecks.
- No admin configuration edits thisround. Allprocesses87997/47894/30284/6740/88975/83246/79192terminal. Goalactive; unresolvedbackendmapping, liveSalesReturn27/843theme restoration,12Returncontrols, other data/visual/native/hardware cases unchanged. Need investigate denseArabicreturnheaders andactualappcache/printingroute withoutclaimingdeveloperoutputsashardwareproof.

### Thermal header geometry and configuration-cache refresh
- Previous goal turn was progress. New receipt_header_spacing_test renders seven realistic Arabic/bilingual return headings at384/576px with production MultiLineReceiptTableRow andloadedNotoSansArabic. All central4pxgutters remainblank;4savedimages underbuild/receipt_header_spacing inspected. Nooverlapfound;58mmEnglishandArabicheadingswrapheavily (includingwordfragmentation), so this isgeometryproof,notanall-densityreadabilitypass. Noheaderproductionchange made.
- Investigated actualprint refreshcalls: PrintPage andReturnBillPrint fetch fullconfiguration endpoint, andreturnselection prefersCreditNote aliasbeforeReturnBill. Fullfetch persistednewentries butneverremovedobsoleteHivekeys. Newdocument_config_refresh_test reproduced staleCreditNote stillreturned afterserverfullpayloadonlyReturnBill; couldshadownewdocument oncurrentlookup/restart. ThiswasmockedAPI/persistentcache regression,notanobservedliveusertransaction.
- Fixedfullfetchto removeobsoleteHivekeys aftersavingcurrentconfigs; language-specificfetchbehaviorunchanged. Non200responsekeepslastcache. Noactualusercache wascleared: testsusefreshownedtemporaryHiveandmockprefs/http.
- Added5scenario x5document refresh/reloadchecks:languagesen/ar/en_ar, Englishfilled/bothfilled/emptyEnglish/table-onlyEnglish, ArabicvaluesanddisabledMRPflagpersist. Lasttable-onlysnapshot also survivesemptyHiveviaSharedPreferencesbackup;clearAllCachesremovesbackupandmemory. Storeid7request verifiedinthetest. IntentionalblankEnglishnotfilledfromoldcache.
- Sevencombinedrefresh/resolver/header tests passed; subsequenttwo cachetestsincludingbackup/clear passed. ScopedanalyzerfoundoneexistingforEachstyleinfo,noerrorsorwarnings. Noadmineditsorphysicalprintertestthisround. Allprocessesterminal.
- Fullgoalstillactive: backendAPIomissions, twoSalesReturnlive5case sequences/theme restoration,12Returncontrols, remainingdata/native/hardware/visualcases. Thisroundmadeprogressoncacheandgeometry,notcompletion.

### Live app reconnection and print-route data audit
- Previous goal turnprogress. Reconnected Marionette to original58943VM successfully;hotreloadcompletedsuccessfully. NavigatedSalesReturnthenfirstrowORD-004682(12units,total60)printaction. LiveReturnBillprintscreenopened,A4,configurationloadingcompleted. Noreturncreated/edited,noprinterselected,nohardwarejobsubmitted,noadminchanges.
- Marionette screenshotnowworksandvisuallyconfirmedprintscreen. Threedeviceslisted:TwoPilotsDemoPrinter,MicrosoftPrinttoPDF,HPDeskJet2300. InitialcommentaryinterpretedNotavailableasstatus;CORRECTEDafterreadingreturn_bill_print.dart:subtitleisprinter.address??general.not_available. ItisNOTprinteravailability. Selectbuttonsareenabled. HardwareavailabilityremainsUNVERIFIED,notblockedbythislabel.
- Actualread-onlylist-return-ordersAPIforORD-004682 confirmedcustomeruserkeysonlyid/name,customerkeysonlyid/user_id/laravel_through_key/user. Returnlistscreenpassesnameonly;noextracustomerdataavailablefromthisresponse. Do notinventfieldsorsaydroppingpresentcontactdata;detailfetch/enrichedresponse needed. Backendgapsdocupdated.
- APIoriginalorderhasorder_number/order_date/issued_at/receipt_numberandfinancialtotals;cartitemhastax_rate/tax_amount/unit_price/mrp. Thischangesthenextaction:originalinvoiceandtaxcontrolsnowhaveconfirmedsourcekeys,needsemantics/pipelineauditbeforeimplementation. Onlykeynamesprinted,nocredentials/rawcustomerpayload.
- CurrentappUI isPrintReturnBillforORD-004682,A4,noexplicitprinterselection. NativeComputerUsepluginavailablevia mcp__node_repl__js and@oai/sky despiteCUA nativeAPI beingdisabled. SKILL.mdread;guidanceonlyfirst65linesreadthisround (earlierhistorymayhavereadfull);beforeSkyworkreadentireguidance/API/confirmations. NoSkycalls thisround. Do notclaimWindowscontrolunavailable basedonCUArestriction.
- No tests/buildprocessesrunning. Goalactive,progress throughlivehotreload/navigationandauthoritativedatasourceaudit. Remainingfullscopeunchanged.

### Original invoice control wired and rendered
- Admin Return28 Parties tab recovered after a read-only reload. Confirmed independent Show original invoice details switch plus Original invoice label (creditNoteOrderLabel) and Invoice date label (creditNoteInvoiceDateLabel). No settings were changed or saved this round.
- Added optional originalInvoiceNumber/originalInvoiceDate from the original order through all four ReturnBillPrintPage call sites (two sales-return list layouts, detail modal, PrintService), both thermal/PDF services, and the production return builder into ReceiptLayoutParams. Original return creation date remains separate; absent original values stay absent.
- Shared return metadata now honors showOriginalInvoice independently of showInvoiceNumber, formats the original date using the existing business-date helper, and uses language-aware label resolution. Separated the details-section heading key from the original-order label key to prevent label collisions. Backend typed English original-invoice label omissions remain part of the existing metadata contract gap; this client fix does not manufacture missing server values.
- Two focused regression tests passed, covering switch independence, both switches enabled, missing/blank number/date, custom resolved label, and original value preservation through the real builder. Scoped analyzer reported no errors; 31 existing lint findings including an unused detail-table method remain.
- Generated 115 return outputs through the production builder: all five language scenarios x (17 registered thermal themes + six PDF themes). All rendering completed successfully. tool/verify_original_invoice_outputs.py verifies original number/date exactly once and English label presence/absence in all 30 PDFs; passed. The first attempted render omitted the opt-in environment flag and skipped; it was rerun with the flag, yielding the successful 115 outputs.
- Visually inspected Standard Arabic, Premium bilingual, Premium2 bilingual thermal and Boxed Bilingual PDF. Original invoice values/labels visible without collisions. Synthetic full-field table headings still wrap densely on thermal; this is not a hardware-print or universal readability pass. Evidence: build/receipt_output_matrix_full_builder_only_Return-Bill/manifest.json and original_invoice_audit.json; build/original_invoice_bilingual_pdf.png.
- Full goal remains active: live admin Original Invoice on/off capture, remaining return controls/tax semantics, backend missing metadata, two SalesReturn live five-case sequences/theme restoration, and remaining device/visual/data-edge checks still outstanding. No printer selection or physical job this round. Render and analyzer processes completed.

### Saved admin Original Invoice on/off and actual label mapping
- Previous turn made progress. Captured all five baseline configs in baseline/return_original_invoice_before.json. Saved Return28 English with Original Invoice enabled and labels LIVE ORIGINAL / LIVE ORIGINAL DATE, then disabled retaining those labels, capturing return_original_invoice_on/off.json. Both saved cases rendered through the production builder across all17thermal/6PDF themes (46outputs).
- Authoritative API exposed a prior implementation mistake: the typed original-number label is display_configuration.showOriginalInvoice.value, not showCreditNoteOrder. Fixed shared metadata to consume showOriginalInvoice; synthetic harness corrected to keys80(originalnumber)/81(originaldate). Invoice date exists only in resolved_labels.invoice_date in the observed API. Its bilingual metadata omission remains a backend contract issue.
- New regression checks verify actual switch-key label precedence and English/Arabic/bilingual Englishfilled/blank behavior. Two focused tests passed. Re-rendered all115 five-case builder outputs after the mapping correction; all30 PDF original-invoice checks passed again. tool/verify_live_original_invoice.py confirms both number/date and labels present exactly as expected in12 live-configPDFchecks.
- Restored labels empty and original switch off. First rapid clear/save did not persist the clearing; the verifier correctly failed. Reopened, cleared and blurred each field, allowed updates to settle before saving separately. The final API verification confirms ALLFIVE configurations equal baseline except updated_at. No remaining test labels. Current admin tab is Return28 Totals & tax; no unsaved changes.
- Visually inspected Premium2 thermal outputs for live on/off. APIoriginalnumber/date switch now works; physical printing still not performed. All test/render processes terminal.
- Read-only next audit: Return28 Totals & tax has Taxable row, Tax row, Discount row, MRP total row, Items count row, Total amount row, Credit note total row, Amount in words, rate-wise tax summary. Return model currently drops confirmed original-cart tax_rate/tax_amount before print; production return builder sets apiTotalTax=0. Need exact return-tax basis (partial quantities and original discount allocation) before calculation changes. Admin preview two lines quantity2+1 shows Total Items3.00 whereas shared returnsSection currently counts items.length (2); investigate intended return-only quantity semantics next. Do not assume original full-line tax equals partial return tax.
- Goal remains active; frontend live switch proof advances scope but does not resolve backend metadata, twoSalesReturnfive-case/theme restoration, remaining controls, native/hardware and full visual/data checks.

### Return-only item-count correction
- Previous turn progress. Rechecked current source and admin evidence: Credit Note preview counts returned quantity (two lines quantity2+1 yields3), while returnsSection, Standard and Premium printed line count2. Premium2/PDF already consume the shared count row.
- Corrected return-only count to sum quantities through shared formatQuantity, preserving fractional quantities. Combined sales/return documents retain existing line-count semantics pending their own admin comparison. Standard and Premium now consume the same shared label/value pair as Premium2 and PDFs. Corrected count label resolution to actual showReturnItemsCount rather than an invented showCreditNoteItemsCount field, so a configured label wins over resolved fallback.
- Regression covers hidden count,2+1=3,1.5+.25=1.75,zero quantities, configured-label precedence, and combined-document line counts.11focused/control-contract tests passed. Generated all115ReturnBilloutputs across5languages through productionbuilder; render passed. tool/verify_return_item_count.py checks3adjacentto68countlabelinall30PDFs; passed. Original-invoice30PDFchecks also passed after rerender. Visually confirmed StandardArabic and PremiumEnglish thermal count3. Evidence return_count_audit.json in build/receipt_output_matrix_full_builder_only_Return-Bill.
- Scopedanalyzercompletedwith38existinglintfindings; noerrorsintroduced. No live admin edits, cache clearing or physical printerjobthisround. Allprocessescompleted. Fullgoalactive; nextindependentreturntotalscontrolcanbeMRPtotal(sumreturnedquantity*MRP), whiletaxbasisneedscontinuedsourceaudit. Backendmetadata andtwoSalesReturnlivecase/theme-restorationgaps remain.

### Return MRP total control
- Previous turn progress. Confirmed showMRPTotal existed in the live Return28 API but was ignored by the return block. Added returnMrpTotalRow shared label/calculation, using returned quantity times the same MRP source/fallback as each table line. Enabled only for return-only documents so combined-sale MRP totals are not duplicated. Six PDFs use shared totalRows; Standard, Premium and Premium2 thermal summary boxes include the row independently of refund-total switches.
- Regression covers hidden switch, combined-document exclusion, fractional quantities, explicitzeroMRP,comma-formattedMRP,missingMRP'sexistingratefallback, and unchangedexplicitrefund. Four focused control/price tests passed.115syntheticReturnBillrenderspassed; tool/verify_return_mrp.py verified24.00besidemarker34inall30PDFs acrossfivecases (1x12+2x6), separatelyfromrefund21. Scopedanalyzer39existingstyleinfos,noerrors; complete.
- Saved actual Return28 MRPtotal switch on with LIVE RETURN MRP. APIcapture return_mrp_on.json confirms visibletrue,valueNULL,resolved_labels.mrp_totalcustomlabel; current labelresolverhandlesEnglishresolvedlabel. Rendered23actual-configoutputs. Restoredoriginalfalse/blanklabel viaUI, capturedreturn_mrp_restored.json. Baselineall5configs savedin baseline/return_mrp_before.json. Newverifier tool/verify_live_return_mrp.py checks12PDFs for enabled/disabled24value/customlabel and unchanged21refund, plusallfiveconfigrestorationexcludingupdated_at.
- VisuallyinspectedlivePremium2thermalMRP24/refund21/count3. No physical printjob, no printersettingschanged. Fullgoalactive; returntax/discount/HSNandbackendmissingbilingualmetadata plusotherdocumentlivecases/restoration/devicechecks remain. BilingualMRPtypedEnglishmissingfromAPI remainsacontractgapdespitesyntheticlanguageproof.

### Return HSN/rate source preservation and financial-source evidence
- Previous turn progress. Read existing return creation/calculation code and live GET projections. Current list-return-orders has original tax_rate/tax_amount/product.hsn_code but lacks return refund_breakdown/tax allocation. Redacted financial projection saved to build/receipt_live_audit/return_financial_source_audit.json and concrete discrepancies documented in docs/receipt-backend-contract-gaps.md. Return717 prediscountline25/tax3.814 vsdiscount5/refund20/ordertax3.050 proves original tax cannot blindly be used. Return758 is2of7units. Return772 quantity14/price1445/unit100 vsoriginal14.450 reveals stored-data inconsistency. No returns were created/changed.
- Inspected actual order-details endpoint forORD004682. It has percartline discounted_total/base/tax andline_discount, butnoHSN/taxrate; returnitems containonlyid/name/quantity/reason, withoutcartid. Thisroute needsenrichment/backenddata before sameclassificationcoveragecanbeclaimed. Docs describeconfirmedkeys; existingbackend-requestmarkdownnotassumeddeployed.
- Added nullable HSN/taxRate toOrderReturnItem withJSONroundtrip, productHSN andtaxratepresence to salesreturnlistmodels, andforwardingfrom buildTransactionReturnPrintItems. Explicit0ratepreserved;missing/invalid/nonfinite/negativeratesrenderblank. HSNremainsstringpreserving leadingzeros. No speculative return-tax amount/discount computation added.
- Implemented showHsnCode/showTaxRateColumn in sharedPDFreturncolumnsandall3thermalfamilies. Harnessmarkers82/83 appended, fixtureHSN090121/090240andrates18%/0%.115outputsrenderedthroughproductionbuilderall5cases; tool/verify_return_tax_fields.py verifiesvaluesexactlyonceandEnglishheadingpresence/absenceinall30PDFs. Passed. Initialverifierassumedheadingexactlyonce; correctedforlegitimate repeated multipage tableheaders (data remains exactlyonce).
- Firstthermalrenderexposedtouchingdensevalues. Returnvaluetablerowsnowuse MultiLineReceiptTableRow with8pxintercellgutters. Rerendered115outputsafterfix, visuallyinspectedPremium2English/PremiumBilingual. Sixfocusedmodel/control/geometrytests passed; expandedgeometrytest thenpassed12rastercases (7/9headingsand9numericcells x2widths x2modes) withclearcentral4pxgutters. LongHSNstillwrapsatdensewidths; notall-densityreadabilityapproval.
- Scopedanalyzerfinished55styleinfos,noerrors/warnings. Livehotreloadrequestedafterchanges. No admineditsinthisround; latestsettingsremainrestored. No hardwareprint. Alltests/renderprocessesterminal.
- Remaining: liveadminHSN/rate on/off andrealsourcedata printcheck; order-detailsroute enrichment; taxamount/taxable/discount/taxsummary semantics; backendlabelmetadata/twoSalesReturnfivecase/theme restoration; physical/native/data/visualscope. ObservedClassicbilingualPDF repeatsreturntableheaderonpage2, withheadernearpage1bottom; checkorphanheading/pagination ratherthanassuming markerpass proveslayout. Fullgoalactive.
- Live reload initially found Marionette disconnected; reconnect to the user-provided58943VM succeeded. Reissuedhotreloadafterconnection (see toolresult); no app restart or cache clearing.

### Read-only pagination verification after backend scope clarification
- Previous continuation was a status/clarification turn, not completed test progress. User explicitly says backend is maintained by others and deployed: do not edit backend code or backend data. Further work uses local app code and saved/read-only evidence; do not mutate live admin configurations under the newer restriction.
- Revalidated suspected Classic bilingual return-table orphan against current saved PDF. Extracted page1 contains Coffee under its heading; page2 repeats headings above Tea. Rendered both pages with Poppler and visually inspected: heading and item are together on both pages. Prior suspicion is not a confirmed defect for this fixture; no production pagination change justified.
- Added tool/verify_return_pagination.py and ran against all30 ReturnBill PDFs (6themes x5languagecases),48pages. Every detected table header shares its page with an item. Detector requires at least one header per document and handles observed Arabic visual extraction order. An initial exploratory detector missed reversed Arabic glyph order; corrected before recording pass. Evidence: return_pagination_audit.json in current ReturnBill builder output root.
- Scope limit: existing two-item A4 fixture only; no claim for arbitrary long rows, A5 or all receipt lengths. Remaining language/API-mapping, combined-document live cases, financial allocation, dense thermal readability and physical/native printing work remains. Goal active. No backend/admin changes and no print jobs this round.

### Current deployed language-query and client mapping audit
- Previous goal turn made progress: closed the suspected orphaned table heading for the saved 30-PDF fixture with page-level and visual evidence.
- Respected user restriction: only three authenticated GET requests to the existing document-configs endpoint; no admin/backend writes. Requested en, ar, en_ar with current store_id. Each of the five documents returned byte-equivalent serialized configuration across all three language requests. Actual active languages are Bill ar, BillA4 en_ar, SalesReturn ar, SalesReturnA4 en, Return en. Evidence language_query_{en,ar,en_ar}.json and language_query_comparison.json under build/receipt_live_audit. This verifies only the unfiltered endpoint; does not establish behavior of every possible endpoint or require backend changes.
- Inspected current raw response and model. Added opt-in receipt_live_config_mapping_test.dart, passed against fresh language_query_en.json. For all five documents, every resolved-label key/value and display option active/default text survives initial parsing and model serialization/reload. Also verified language/header/subheader/theme preservation. This rules out those parser/cache steps dropping supplied labels in the current snapshot; it does not prove every renderer uses every field or that blank English can be obtained separately.
- No production edits justified by this evidence. Test process12929 finished success, no running jobs. Full goal remains active; missing-source cases require an available source or precise integration clarification, while remaining app rendering/financial/physical checks still need work.

### Updated smaller-paper matrix and selective return-heading coverage
- Previous turn progress: fresh read-only language-query/model preservation audit. No live/admin/backend writes in this round.
- Initial run71364 rejected invalid harness combination (return-builder requires Return Bill filter) before rendering; terminal exit1. Corrected invocation45433 completed345outputs for58mm/A5 with current production changes, fivecases/fivedocuments. This run compiled the original table_en fixture before the subsequent coverage correction below.
- Audit42490 completed:345correct raster/page geometry cases withnoout-of-pagePDFglyphs;90PDFmarkerchecks,0themedifferences,0unexpectedEnglishmarkers. Returnpagination audit covers30PDFs/65pages;everydetectedtableheader hasitemon samepage. Root build/receipt_output_matrix_full_58mm_A5. These are automated bounds/content checks, not universal visual approval.
- Visually inspected ReturnEnglishPremium2 andbilingualPremium58mm plusfirstpagebilingualBoxedHeaderA5. Retained HSN/rate/count/MRP/refund. Dense9columnthermalheadingsfragmentandHSNwraps;readability remains a concern, not a pass solelyfrom geometry.
- Found fixture gap: ReturnBill table_en previously filled sales headings that return-only renderer doesnot use. Corrected harness table_en forReturnBill tofillseven actualreturnheadings (62..67and79);otherEnglishfieldsblank. Otherdocumentskeep originalselectedsalesheadings.
- Focusedrun38745completed23outputs58mm/A5usingproductionReturnBillbuilder forcorrectedtable_encase. tool/verify_return_selected_english.py passedallsixPDFs:exactsevenconfiguredEnglishmarkers,noadditionalENmarkers,HSN090121/090240and18%/0%eachonce. Root build/receipt_output_matrix_full_58mm_A5_builder_lang_table_en_only_Return-Bill. Premium2thermal selectedcasevisuallyinspected. Existingfull345run retainsoldReturntablefixture;usefocused23caseevidenceforthiscorrection,rerunfullmatrixwhenbroaderchangesrequireit.
- Allprocesses71364/45433/42490/38745terminal. No physical printjobs. Fullgoal remainsactive: remaininglivecases underno-backend-data-write restriction, unavailableEnglishsourcefields, financialallocation/sourceenrichment, densethermalreadability anddevice/fullvisualchecks stillunverified.

### Independent return serial/product visibility fix
- Previous goal turn progress: updated345smallpaperoutputs andcorrected23selectiveEnglishreturncases. Currentturn inspected dense thermal return-row source andfounda realvisibilityfault: all3activeimplementations printedproductname whenever showReturnSLNumber wason, evenwithshowReturnParticularsoff. PDFcolumnselectionalreadyrespectsvisibility.
- Added sharedReceiptSections.returnItemHeading anduseditinStandard,Premium,Premium2Bilingual. Serial-only nowcontainsnumberonly;product-onlycontainsnameonly;bothpreserveboth;neitherisempty. Existingvariant-formattednames passedbyStandard/Premiumremainintactwhenenabled. Didnotchangewidths,arithmeticorbackends.
- Newreceipt_return_heading_visibility_test coversEnglish/Arabic/mixednameswithvariantsandall4switchcombinationsplusblankname. Combinedwithreturncontrolregression,run3293passed3tests.
- AddedsyntheticharnessRECEIPT_HIDE_RETURN_NAMESwithisolatedroot. Run50676completed115outputs (5cases x17thermal/6PDF) usingrealReturnBillbuilderat58mm/A5. verify_hidden_return_names.py passed30PDFchecks:noproductnames/noproductheadingmarker,serialheadingretainedwhereEnglishconfigured,HSN/ratesexactlyonce. Visuallyinspectedall3activebilingualthermalfamilies: serial1/2remain,namesabsent,quantities/lineamounts/count3/MRP24/refund21retained. Root build/receipt_output_matrix_full_hidden_return_names_58mm_A5_builder_only_Return-Bill.
- Analyzer40535completed47infos,noerrors/warnings. Alltest/render/analyzerprocessesterminal. Requestedlivehotreload(seetoolresult). No liveadmin/backendeditsorphysicalprinting. Denseall-columns-onreadability remainsunresolved;visibilityfixdoesnotclaimtosolveit. Fullgoalactivewithremaininglanguage/data/live/hardwarechecks.

### Return variant consistency
- Previous goalturnprogress:fixedindependentthermalserial/productvisibility andverified115outputs. NewsourceauditfoundPremium2BilingualusedrawreturnItem.productNamewhileStandard/Premium/PDFsalreadyincludedvariantattributes. FixedPremium2Bilingualto useparams.itemNameLines, retainingthevisibilityhelperfrompreviousround.
- AddedtypedOrderReturnItemregressiontosharedfieldtests:English/Arabic/bilingualmodes,Size+Colourattributes,already-suffixedname(noduplication),absentvariants. Combinedsharedfield/visibilityrunpassed12tests. ExpandedmainrendererfixturewithCoffeeLarge/TeaSmallvariants sofuturematricesexercisevariants.
- Run51136finished115ReturnBilloutputs80mm/A4usingproductionbuilderacross5cases. verify_return_variants.py passed30PDFsexactlyoneLarge/Smallvalueeach. verify_return_selected_english.py passed6PDFswithcorrectedsevenselectedreturnheadingmarkers. VisuallyinspectedPremium2Bilingualbothfilledthermal:Large/Smallnowpresentbesideproducts,totalsunchanged. Currentrootbuild/receipt_output_matrix_full_builder_only_Return-BillnowhasupdatedvariantfixturesandcorrectedselectiveEnglishcase.
- Scopedanalyzer14071finishedoneexistingbracesstyleinfo,noerrors/warnings. Allprocessesterminal.Hotreloadsuccessful.Noadmin/backenddataeditsorphysicalprints. Fullgoalactive:remainingliveconfigscenarios,missingsourcefields,returnfinancialallocation,densereadabilityanddevice/fullvisualchecksnotcomplete.

### Missing explicit return-unit-price fallback
- Previous goalturnprogress:Premium2returnvariantsfixed/tested/rendered. SourceauditnowfoundsalesReturnItemUnitPrice returnedsummarylinepriceunchangedwhenbothcartandloadedunitpriceswereabsent. LiveGETschemaearlierconfirmedpriceisreturnedlinevalue. A12unitlinevalued60thusbecameunit60andcouldmultiplyto720. Updatedexistingregressionpreviouslyexpecting60andaddedfractional/commavalue/zeroquantitycases; prefixtestrunfailed2tests(actual60versusexpected5),confirmingdefect.
- Helpernowprefersexplicitvalidnonnegativefinitecartunitprice,thenmatchedloadedunitprice(includingzero);onlythen derivesratefromreturnedlinevalue/returnedquantity. Commasnormalizedandprecisionretaineduntilrendering. Missing/invalidpriceorinvalid/nonpositivequantityreturnsblankratherthantreatinglinevalueasunitprice. Doesnotcomputeanytaxallocationorchangebackendrecords.
- Combinedreturnprice/controlrun92275passed6tests. AddedintegrationcaseAPI-shapedsummary -> buildTransactionReturnPrintItems -> JSONroundtrip -> productionreturnItemRate:2.5units,line12.50,unit5,computedline12.50. Subsequentpricefilepassed5tests. Scopeisfallbackwhennounitpricesupplied;explicitpricesarestillauthoritative.
- Analyzer39800finishedonly2bracesinfosonmodifiedhelperlines;addedbracesafterwardwithoutbehaviorchange. Livehotreloadsuccessfulbeforebraces-onlycleanup. Allprocessesterminal.Noadmin/backendwritesorphysicalprints. ExistingrenderercoverageconsumesthesameOrderReturnItem.unitPricefield;didnotclaimnewall-templateimagesforthisfallback. Fullgoalactivewithremainingfinancialsource/language/live/device/visualgaps.

### Live admin testing reauthorized; browser connection failure
- Previous goalturnprogress:unit-pricefallbackfixedandregression/integrationverified. Recheckedcurrentbranch integrate/b2b-plus-gokul-dev. Marionetteget_interactive_elements works; app iscurrentlyonWeighmachineproductpage,notpreviousReturnPrintpage. Didnotnavigateorinterruptthatpage.
- Userclarifiedexplicitly: 'You can edit the configuration as you want. There is no issue in that. Don't want to restore also'. Thisauthorizeseditingallfivetemplateconfigsandleavingfinaltestedsettings;backendcodeandunrelatedbusinessdataremainoutsidechanges. Removesnull-theme/restorationconstraintforSalesReturn27/843. Do notaskagainforconfigurationeditpermission.
- TriedCUAChromeid2afterrewriteDocumentationandlistBrowserssuccess. createBrowserTabtoobservedSalesReturn27editorURLfailedtwicewith 'Unable to load browser request-header policy. Retry the browser command.' listTabs(browser2)failedwithsameconnection/policyloaderror. No pageaccessoreditoccurred. Thisisnotanapprovalreviewrejection;nonewbackend/adminmutation. Browserneedsconnectionrecoverybeforelivesequencescanproceed. Failureobservedthisgoalturnonly;donotmarkgoalblockedfromthreecallsinoneturn.
- Nextlivework:SalesReturn27then843fivecases, allowedthemefromeditorandnorestorationrequirement. LeavefinalbilingualselectedEnglishsettingsaslasttestedunlessusersteers. SaveAPIcapturesandrenderallapplicablethemespercase;preciselyretainknownsourceomissionsasfailures. Fullgoalactive;browserfailuredoesnotinvalidatecompletedlocalfixes/tests.

### Browser blocker revalidation, second consecutive goal turn
- RecheckedChrome listTabs: same request-header-policy loading failure. ResettheCUAkernel(non-destructive;doesnotcloseuserapps)andreinitializedwithgetState: samefailure, apps/browsersinventoryemptywithBrowserserror. No livehandle/jobawaitingcompletion;thisisaconnectionblocker,notaverifiedwait.
- Browserrecoveryattemptdidnotrestoreaccess. No adminchanges.Needexternalconnectorrecoverybeforetheauthorizedlive27/843languagecasescanproceed. Thisissecondconsecutivegoalturnwithsameblocker;goalremainsactiveandnotcomplete. Localproofcannotreplaceunperformedliveconfigurationscenarios.

### Browser blocker confirmed, third consecutive goal turn
- Chrome listTabs againfailedbeforepageaccesswithsame 'Unable to load browser request-header policy' error. Previouskernelresetandfreshinventoryalsodidnotrecover. Threeconsecutivegoalturnsnowconfirmthissameexternalblocker;notthreecallsinoneturn.
- Completionauditfails:SalesReturn27/843livefive-languageconfigurationsequencesremainunperformed;backend/source-labelandfinancialallocationissuesremainunresolved;physical/nativeandfullvisualverificationremainunproven. Userhasauthorizedtemplateeditswithoutrestoration;permissionisnotblocking. Existinglocalrenders/testsdo notsubstituteforremainingliveevidence.
- No runningtest/renderprocesses.No liveadminchangesduringtheseconnectionfailures. Markgoalblockedpendingbrowserconnectionrecovery/externalinput,notcomplete. Preserveallworktreechangesandcurrentevidence. Onresume,recheckbrowseraccessandproceedwith27then843livecaseswithoutaskingeditpermissionagain.

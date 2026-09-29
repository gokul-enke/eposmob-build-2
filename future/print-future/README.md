# Print documentation and future work

This folder collects print and receipt documentation. Moving a document here
does not mean its described fixes are unfinished. Use the latest verification
report for tested behavior and the future-work checklist for remaining work.

| Document | Purpose / status |
| --- | --- |
| [FUTURE_WORKS.md](FUTURE_WORKS.md) | Remaining API/configuration gaps, client metadata mapping and physical-printer verification. |
| [document-configuration-label-value-sources.md](document-configuration-label-value-sources.md) | Current field-by-field guide: five configurations, 290 display options, English / Arabic / bilingual label and value sources. |
| [receipt-verification-final-2026-09-29.md](receipt-verification-final-2026-09-29.md) | Latest concise result: tested rendered matrix passed; full source completeness remains blocked. |
| [receipt-verification-2026-09-29.md](receipt-verification-2026-09-29.md) | Detailed verification evidence and chronological checkpoints. Later final status supersedes earlier pending counts. |
| [receipt-language-verification-progress.md](receipt-language-verification-progress.md) | Historical progress and regression notes. |
| [receipt-backend-contract-gaps.md](receipt-backend-contract-gaps.md) | Captured admin/API discrepancies and return-data findings; older examples remain historical evidence. |
| [RECEIPT_TEMPLATE_NORMALIZATION_PLAN.md](RECEIPT_TEMPLATE_NORMALIZATION_PLAN.md) | Shared receipt-contract plan; use the final report to determine what is already verified. |
| [print-template-architecture-guide.md](print-template-architecture-guide.md) | Print architecture and contributor reference. Check current source before implementing older guidance. |
| [proposed_template_sharing_architecture.md](proposed_template_sharing_architecture.md) | Historical proposal, superseded for implementation decisions by the architecture guide. |
| [pdf_sharing_implementation.md](pdf_sharing_implementation.md) | PDF generation/sharing implementation reference. |
| [classic_pdf_layout_fix.md](classic_pdf_layout_fix.md) | Historical Classic PDF corruption fix. |
| [backend-offline-receipt-identity-and-returns.md](backend-offline-receipt-identity-and-returns.md) | Separate offline receipt identity / backend return integration request; its backend completion status was not certified by the print-language matrix. |
| [print-barcode-variants-multiunit.md](print-barcode-variants-multiunit.md) | Barcode variants and sale-unit printing reference. |
| [Thermal print multilanguage review](thermal%20print%20multilanguage%20review.md) | Historical thermal language review; current source guide and final verification take precedence where behavior differs. |

Local PDF/thermal outputs, API captures and machine-readable audits remain in
`build/receipt_live_audit` and the related local render directories. Their paths
in historical reports are relative to the repository root, not this folder.

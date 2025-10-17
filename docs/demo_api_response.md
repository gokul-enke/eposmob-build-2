# Expected API Response for Supplier Statement Document Configuration

## Overview
This document shows the **expected API response** for the "Supplier Statement" document configuration. The backend needs to add the missing column visibility controls to match the mobile app requirements.

---

## Current API Response (Incomplete ❌)

```json
{
  "status": "success",
  "document_configurations": {
    "Supplier Statement": {
      "id": 47,
      "company_id": 1,
      "type": "Supplier Statement",
      "logo": null,
      "show_logo": 0,
      "number_prefix": null,
      "discount_method": null,
      "header": "EPosenke",
      "subheader": "Supplier Statement",
      "terms": null,
      "footer": "This is a computer-generated document. No signature is required.",
      "accent_color": null,
      "font": null,
      "template": "supplier_statement",
      "item_name": {
        "option": null
      },
      "tax_name": null,
      "unit_name": null,
      "price_name": null,
      "amount_name": null,
      "created_by": null,
      "updated_by": null,
      "created_at": "2025-09-26T05:34:02.000000Z",
      "updated_at": "2025-10-09T05:33:33.000000Z",
      "display_configuration": {
        "showHeader": {
          "visible": true,
          "value": null
        },
        "showSubheader": {
          "visible": true,
          "value": null
        },
        "showFooter": {
          "visible": true,
          "value": null
        },
        "showDates": {
          "visible": true,
          "value": null
        },
        "showSupplierName": {
          "visible": true,
          "value": null
        },
        "showSupplierEmail": {
          "visible": true,
          "value": null
        },
        "showSupplierPhone": {
          "visible": true,
          "value": null
        },
        "showSupplierAddress": {
          "visible": true,
          "value": null
        },
        "showTotalCredit": {
          "visible": true,
          "value": null
        },
        "showTotalDebit": {
          "visible": true,
          "value": null
        },
        "showBalance": {
          "visible": true,
          "value": null
        },
        "showStatus": {
          "visible": true,
          "value": null
        }
      },
      "resolved_labels": {
        "item_name": "PRT",
        "unit_name": "QTY",
        "price_name": "Rate",
        "tax_name": "Tax",
        "amount_name": "AMT"
      }
    }
  }
}
```

**Problem:** Missing table column visibility controls!

---

## Expected API Response (Complete ✅)

```json
{
  "status": "success",
  "document_configurations": {
    "Supplier Statement": {
      "id": 47,
      "company_id": 1,
      "type": "Supplier Statement",
      "logo": null,
      "show_logo": 0,
      "number_prefix": null,
      "discount_method": null,
      "header": "EPosenke",
      "subheader": "Supplier Statement",
      "terms": null,
      "footer": "This is a computer-generated document. No signature is required.",
      "accent_color": null,
      "font": null,
      "template": "supplier_statement",
      "item_name": {
        "option": null
      },
      "tax_name": null,
      "unit_name": null,
      "price_name": null,
      "amount_name": null,
      "created_by": null,
      "updated_by": null,
      "created_at": "2025-09-26T05:34:02.000000Z",
      "updated_at": "2025-10-13T03:54:00.000000Z",
      "display_configuration": {
        "showHeader": {
          "visible": true,
          "value": null
        },
        "showSubheader": {
          "visible": true,
          "value": null
        },
        "showFooter": {
          "visible": true,
          "value": null
        },
        "showDates": {
          "visible": true,
          "value": null
        },
        "showSupplierName": {
          "visible": true,
          "value": null
        },
        "showSupplierEmail": {
          "visible": true,
          "value": null
        },
        "showSupplierPhone": {
          "visible": true,
          "value": null
        },
        "showSupplierAddress": {
          "visible": true,
          "value": null
        },
        "showTotalCredit": {
          "visible": true,
          "value": null
        },
        "showTotalDebit": {
          "visible": true,
          "value": null
        },
        "showBalance": {
          "visible": true,
          "value": null
        },
        "showStatus": {
          "visible": true,
          "value": null
        },
        
        "// ========== NEW FIELDS TO ADD ========== //": "Table Column Visibility Controls",
        
        "showSlNumber": {
          "visible": true,
          "value": null
        },
        "showDate": {
          "visible": true,
          "value": null
        },
        "showReference": {
          "visible": false,
          "value": null
        },
        "showTransactionType": {
          "visible": false,
          "value": null
        },
        "showDebit": {
          "visible": true,
          "value": null
        },
        "showCredit": {
          "visible": true,
          "value": null
        },
        "showPaymentMethod": {
          "visible": false,
          "value": null
        },
        "showBalanceColumn": {
          "visible": false,
          "value": null
        }
      },
      "resolved_labels": {
        "item_name": "PRT",
        "unit_name": "QTY",
        "price_name": "Rate",
        "tax_name": "Tax",
        "amount_name": "AMT"
      }
    }
  }
}
```

---

## Fields to Add to Backend

### Table Column Visibility Controls

Add these **8 new fields** to the `display_configuration` object for "Supplier Statement":

```json
{
  "showSlNumber": {
    "visible": true,
    "value": null
  },
  "showDate": {
    "visible": true,
    "value": null
  },
  "showReference": {
    "visible": false,
    "value": null
  },
  "showTransactionType": {
    "visible": false,
    "value": null
  },
  "showDebit": {
    "visible": true,
    "value": null
  },
  "showCredit": {
    "visible": true,
    "value": null
  },
  "showPaymentMethod": {
    "visible": false,
    "value": null
  },
  "showBalanceColumn": {
    "visible": false,
    "value": null
  }
}
```

---

## Field Descriptions

| Field Name | Type | Default | Description |
|------------|------|---------|-------------|
| `showSlNumber` | boolean | `true` | Show/hide serial number column in transaction table |
| `showDate` | boolean | `true` | Show/hide date column in transaction table |
| `showReference` | boolean | `false` | Show/hide reference/invoice number column |
| `showTransactionType` | boolean | `false` | Show/hide transaction type column (Purchase/Payment/Return) |
| `showDebit` | boolean | `true` | Show/hide debit amount column |
| `showCredit` | boolean | `true` | Show/hide credit amount column |
| `showPaymentMethod` | boolean | `false` | Show/hide payment method column (Cash/Card/UPI) |
| `showBalanceColumn` | boolean | `false` | Show/hide running balance column in table (balance shown in summary instead) |

---

## Current UI Design (Based on Mobile App)

The mobile app displays the following columns by default:

### Visible Columns:
1. **SL** (Serial Number)
2. **Date** (Transaction Date)
3. **Debit** (Debit Amount - Red color)
4. **Credit** (Credit Amount - Green color)
5. **Status** (Paid/Pending/Initiated)

### Hidden Columns (Not shown in table):
- Reference
- Transaction Type
- Payment Method
- Balance (shown in summary section instead)

### Summary Section (Bottom):
- Total Credit
- Total Debit
- Balance

---

## Database Schema Suggestion

If you're storing this in a database, here's a suggested structure:

### Table: `document_configurations`

```sql
-- Add these columns to the display_configuration JSON field
ALTER TABLE document_configurations 
MODIFY COLUMN display_configuration JSON;

-- Example update query to add the new fields
UPDATE document_configurations 
SET display_configuration = JSON_SET(
  display_configuration,
  '$.showSlNumber', JSON_OBJECT('visible', true, 'value', null),
  '$.showDate', JSON_OBJECT('visible', true, 'value', null),
  '$.showReference', JSON_OBJECT('visible', false, 'value', null),
  '$.showTransactionType', JSON_OBJECT('visible', false, 'value', null),
  '$.showDebit', JSON_OBJECT('visible', true, 'value', null),
  '$.showCredit', JSON_OBJECT('visible', true, 'value', null),
  '$.showPaymentMethod', JSON_OBJECT('visible', false, 'value', null),
  '$.showBalanceColumn', JSON_OBJECT('visible', false, 'value', null)
)
WHERE type = 'Supplier Statement';
```

---

## Implementation Notes for Backend Developer

1. **Add to Existing Structure**: Don't replace existing fields, just add the new ones
2. **Maintain Consistency**: Use the same structure as other display configuration fields
3. **Default Values**: Set sensible defaults as shown above
4. **Validation**: Ensure `visible` is always boolean, `value` can be null or string
5. **Migration**: Create a migration script to update existing records
6. **API Endpoint**: Ensure the GET `/api/document-configurations` endpoint returns these fields

---

## Testing Checklist

After implementation, verify:

- [ ] API returns all 8 new fields in `display_configuration`
- [ ] Each field has `visible` (boolean) and `value` (null/string) properties
- [ ] Existing fields are not affected
- [ ] Mobile app can read and use these settings
- [ ] Settings can be updated via admin panel (if applicable)

---

## Questions?

If you have any questions about these fields or need clarification on the structure, please contact the mobile development team.

**Contact**: Mobile Dev Team  
**Date**: October 13, 2025  
**Version**: 1.0

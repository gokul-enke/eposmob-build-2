# Grouped Stock Custom Price Behavior

## Recommended Behavior

When a user applies a custom price to a grouped-stock cart row, the custom price should belong to that specific cart row only.

### Rules

1. If quantity increases within the same grouped stock selection, keep the custom price.
2. If quantity spills into a different stock group, do not silently copy the old custom price to the new row.
3. Create a new cart row for the new stock group with its default stock price.
4. If needed, prompt the user with a confirmation such as: "Apply custom price to new stock group too?"

## Why This Is Ideal

- A custom price is typically a user override for one chosen commercial unit, not a blanket override for all future stock sources.
- Different stock groups can represent different pricing batches, so automatically reusing the custom price can hide pricing mistakes.
- It keeps pricing behavior auditable and predictable.
- The original grouped row remains user-overridden, while the new row remains system-priced unless the user explicitly overrides it.

## Recommended UX Model

- Same row, same stock group: preserve custom price.
- New row, new stock group: use default price and let the user decide whether to override it.

## POS Recommendation

For POS workflows, the safest default is:

- Preserve custom price only for the same grouped row.
- Do not auto-propagate custom price to a newly created row from another stock group.

This reduces hidden pricing errors while keeping the cashier flow understandable.

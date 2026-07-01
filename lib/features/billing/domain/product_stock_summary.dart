/// Pure stock-availability check shared by mobile product display widgets.
///
/// This is a display hint only — it must never gate add-to-cart. Stock
/// enablement/fallback/modal behavior is decided by `ProductCartHelper`.
bool hasAvailableStock(Iterable<num?>? quantities) {
  if (quantities == null) return false;
  num total = 0;
  for (final quantity in quantities) {
    total += quantity ?? 0;
  }
  return total > 0;
}

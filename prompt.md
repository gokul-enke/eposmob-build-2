can you write every single billing logics in feature sub folder way ? c:\Users\gokul\Desktop\Projects\Enke\eposmob\wikidata\billing @lib/features/billing/
  presentation/pages/billing_page.dart only this page and other files mentioned in it logics need to write @lib/providers/local_product_provider.dart , can split
  in to multiple md files , also can us sub agents , write correctly without lossing any single logics.



  The thing i am doing is i have a billing desktop page which is not good archetecture but most of my users using that screen , so without breaking that screen iam trying to create new screen in mobile in good archetecture , so i need all logics in new archetecture without breaking old screen. then after my tester confirming mobile ui is working with all logics correctly i will start to make my desktop screen archetecture by rewritting it to a new screen , how is the plan ? 



  is it safe to pull from origin/mubashir-dev , can you review changes carefully and make sure none of my feature will broke , first give a review , is the fixes are correct or need any updation also 














  I want you to make @lib/screens/settings  (and its related widget files) fully responsive, UX-friendly, and visually polished — like a modern Shopify admin UI — and it should look very good on mobile especially. Do the same kind of work we did on the dashboard.

Scope / files: @lib/screens/settings @lib/controllers/sidebar_controller.dart @lib/widgets/side_menu_mobile.dart@lib/widgets/side_menu.dart First read them fully and map out how the page is composed on mobile vs desktop.

Hard constraints (do NOT violate):

UI ONLY. Do not change, rename, or remove any business logic, state, data fetching, providers, navigation, SideBarController.index.value assignments, permission checks (currentUserHasPermissionSync), provider/API/model calls, or callback behavior. Only change presentation (layout, spacing, colors, typography, responsiveness, purely-visual widget structure).
Preserve all Obx, Consumer, Provider.of, Get.find, and onTap/onChanged behavior exactly.
Follow the app's existing conventions: ColorManager, FontManager, StyleManager/buildCustomStyle, build_container_box, and the existing 600px phone breakpoint used in main.dart. Reuse the shared widgets already created for the dashboard (dashboard_responsive.dart → ResponsiveStatGrid, DashboardStatCard, DashboardSectionHeader) if they fit, instead of duplicating.
What to deliver:

Responsive layout via LayoutBuilder/MediaQuery (or responsive GridView/Wrap) so nothing overflows horizontally at any width from ~320px phones up to desktop. No clipped or cut-off content.
Modern, clean Shopify-like style: consistent radius, subtle shadows/borders, good whitespace, clear typographic hierarchy, tidy badges/pills, aligned section headers.
Mobile polish: comfortable tap targets (≥44px), correct SafeArea + responsive padding, proper scrollability, headers/filters/action buttons that wrap gracefully on small screens.
Any tables/lists/forms on the page should reflow well on mobile (e.g. stack or horizontal-scroll wide tables rather than clipping).
Keep the desktop/wide layout looking good — don't regress it.
Page background should be white (Colors.white), with cards kept visually distinct via subtle border/shadow.
Approach: Extract shared visual helpers to reduce duplication where sensible, but never move or alter logic. If the page is large, you may split the work internally.

Verify before finishing: Grep to confirm no index.value = assignments, permission strings, or provider method calls were changed (counts must match pre-edit). Run flutter analyze on the touched files and fix any new issues you introduced (leave pre-existing lints alone).

Report: files changed, responsive strategy used, key visual improvements, confirmation that no logic changed, and flutter analyze results.
/// Shared, feature-agnostic UI kit for management screens.
///
/// Import this one file: `import 'package:pos_machine/core/ui/ui.dart';`
///
/// The location picker is imported separately
/// (`core/ui/location/location_picker_dialog.dart`) because it pulls in the
/// WebView and geolocator plugins.
library;

export 'buttons/app_buttons.dart';
export 'display/app_avatar.dart';
export 'display/app_badge.dart';
export 'display/app_icon_tile.dart';
export 'display/app_metric.dart';
export 'display/info_row.dart';
export 'feedback/app_dialog.dart';
export 'feedback/app_empty_state.dart';
export 'feedback/app_loading_view.dart';
export 'feedback/app_toast.dart';
export 'filters/collapsible_filter_tile.dart';
export 'filters/filter_field.dart';
export 'filters/filter_panel.dart';
export 'form/app_form_fields.dart';
export 'form/app_input_decoration.dart';
export 'form/app_radio_group_field.dart';
export 'form/app_search_dropdown_field.dart';
export 'form/form_actions_bar.dart';
export 'layout/app_surface.dart';
export 'layout/detail_page_scaffold.dart';
export 'layout/list_page_scaffold.dart';
export 'layout/page_header.dart';
export 'layout/section_card.dart';
export 'list/app_adaptive_list.dart';
export 'list/app_card_list.dart';
export 'list/app_data_table.dart';
export 'list/app_list_card.dart';
export 'list/app_pagination_bar.dart';
export 'list/table_cells.dart';
export 'tokens/app_colors.dart';
export 'tokens/app_sizes.dart';
export 'tokens/app_spacing.dart';
export 'tokens/app_text_styles.dart';

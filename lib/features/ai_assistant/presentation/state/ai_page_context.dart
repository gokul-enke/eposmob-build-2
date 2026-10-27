import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../controllers/sidebar_controller.dart';
import '../../domain/ai_models.dart';

/// Knows which screen the user is on, so the assistant can answer questions
/// like "explain this order". Most specific source wins:
///   1. details a page registered with [AiPageContextScope] (e.g. the open order),
///   2. the top pushed route's name (GetX names routes after their page),
///   3. the active sidebar screen.
class AiPageContext {
  AiPageContext._();

  static final AiPageContext instance = AiPageContext._();

  /// Add to the app's navigatorObservers.
  late final NavigatorObserver observer = _AiRouteObserver(this);

  final List<String?> _routeNames = [];
  final Map<Object, AiPageInfo> _scopes = {};

  /// Overridable for tests; defaults to the sidebar's current screen.
  String? Function() sectionLabel = _sidebarScreenLabel;

  AiPageInfo? current() {
    if (_scopes.isNotEmpty) return _scopes.values.last;
    final route = _routeNames.isEmpty ? null : _routeNames.last;
    final routeLabel = route == null ? null : humanizeScreenName(route);
    if (routeLabel != null && _routeNames.length > 1)
      return AiPageInfo(screen: routeLabel);
    final section = sectionLabel();
    return section == null ? null : AiPageInfo(screen: section);
  }

  void _register(Object owner, AiPageInfo info) {
    _scopes.remove(owner);
    _scopes[owner] = info;
  }

  void _unregister(Object owner) => _scopes.remove(owner);

  @visibleForTesting
  void resetForTest() {
    _routeNames.clear();
    _scopes.clear();
    sectionLabel = _sidebarScreenLabel;
  }
}

String? _sidebarScreenLabel() {
  if (!Get.isRegistered<SideBarController>()) return null;
  final sidebar = Get.find<SideBarController>();
  final index = sidebar.index.value;
  if (index < 0 || index >= sidebar.screens.length) return null;
  return humanizeScreenName(sidebar.screens[index].runtimeType.toString());
}

/// "/SalesOrderDetailsPage" or GetX's "/() => SalesOrderDetailsPage" →
/// "Sales order details". Null for root or unnamed routes.
String? humanizeScreenName(String raw) {
  final identifiers = RegExp(r'[A-Za-z_][A-Za-z0-9_]*').allMatches(raw);
  if (identifiers.isEmpty) return null;
  var name = identifiers.last.group(0)!;
  name = name.replaceAll(RegExp(r'(Page|Screen|Widget|Responsive|View)+$'), '');
  final words = name
      .replaceAllMapped(
          RegExp(r'(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])'),
          (_) => ' ')
      .replaceAll('_', ' ')
      .trim()
      .split(RegExp(r'\s+'));
  if (words.isEmpty || words.first.isEmpty) return null;
  final sentence = words
      .map((w) => w.length > 1 && w == w.toUpperCase() ? w : w.toLowerCase())
      .join(' ');
  return sentence[0].toUpperCase() + sentence.substring(1);
}

class _AiRouteObserver extends NavigatorObserver {
  _AiRouteObserver(this._context);

  final AiPageContext _context;

  // Only full pages count; dialogs and popups keep the page underneath.
  bool _isPage(Route<dynamic>? route) => route is PageRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isPage(route)) _context._routeNames.add(route.settings.name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isPage(route) && _context._routeNames.isNotEmpty)
      _context._routeNames.removeLast();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      didPop(route, previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (_isPage(oldRoute) && _context._routeNames.isNotEmpty)
      _context._routeNames.removeLast();
    if (_isPage(newRoute)) _context._routeNames.add(newRoute!.settings.name);
  }
}

/// Tells the assistant what this page shows while it is on screen.
///
/// ```dart
/// AiPageContextScope(screen: 'Order details', details: 'Order #123, total SAR 200', child: ...)
/// ```
class AiPageContextScope extends StatefulWidget {
  const AiPageContextScope(
      {super.key, required this.screen, this.details, required this.child});

  final String screen;
  final String? details;
  final Widget child;

  @override
  State<AiPageContextScope> createState() => _AiPageContextScopeState();
}

class _AiPageContextScopeState extends State<AiPageContextScope> {
  void _publish() => AiPageContext.instance._register(
      this, AiPageInfo(screen: widget.screen, details: widget.details));

  @override
  void initState() {
    super.initState();
    _publish();
  }

  @override
  void didUpdateWidget(AiPageContextScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.screen != widget.screen ||
        oldWidget.details != widget.details) _publish();
  }

  @override
  void dispose() {
    AiPageContext.instance._unregister(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

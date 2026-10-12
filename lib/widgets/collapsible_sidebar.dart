import 'dart:async';

import 'package:flutter/material.dart';

import '../providers/shared_preferences.dart';

class CollapsibleSidebar extends StatefulWidget {
  final Widget child;
  final Widget sidebarContent;
  final SharedPreferenceProvider? preferences;

  const CollapsibleSidebar({
    super.key,
    required this.child,
    required this.sidebarContent,
    this.preferences,
  });

  /// Subscribes menu widgets to presentation changes without remounting them.
  static CollapsibleSidebarState? of(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<_SidebarPresentation>();
    return context.findAncestorStateOfType<CollapsibleSidebarState>();
  }

  @override
  CollapsibleSidebarState createState() => CollapsibleSidebarState();
}

class CollapsibleSidebarState extends State<CollapsibleSidebar> {
  static const double _expandedWidth = 200;
  static const double _collapsedWidth = 60;
  static const Duration _animationDuration = Duration(milliseconds: 200);

  late final SharedPreferenceProvider _preferences;
  bool _isPinnedExpanded = true;
  bool _isHoverExpanded = false;
  bool _preferencesLoaded = false;
  bool _hasToggled = false;
  bool _suppressHoverUntilExit = false;
  Future<void> _pendingSave = Future<void>.value();

  /// Whether labels and the full menu are currently visible.
  bool get isExpanded => _isPinnedExpanded || _isHoverExpanded;

  /// The explicit choice saved on this device; hovering never changes it.
  bool get isPinnedExpanded => _isPinnedExpanded;

  @override
  void initState() {
    super.initState();
    _preferences = widget.preferences ?? SharedPreferenceProvider();
    unawaited(_restorePreference());
  }

  Future<void> _restorePreference() async {
    var expanded = true;
    try {
      expanded = await _preferences.getNavigationSidebarExpanded();
    } catch (error) {
      debugPrint('Could not restore the navigation sidebar: $error');
    }
    if (!mounted) return;
    setState(() {
      // An explicit choice made while loading must win over the older value.
      if (!_hasToggled) _isPinnedExpanded = expanded;
      _preferencesLoaded = true;
    });
  }

  Future<void> toggleSidebar() {
    setState(() {
      _hasToggled = true;
      _isPinnedExpanded = !_isPinnedExpanded;
      _isHoverExpanded = false;
      // Keep an explicit collapse closed beneath a stationary mouse.
      _suppressHoverUntilExit = !_isPinnedExpanded;
    });
    final expanded = _isPinnedExpanded;
    // Serialize writes so rapid clicks cannot save an older choice last.
    _pendingSave = _pendingSave.then((_) async {
      try {
        await _preferences.saveNavigationSidebarExpanded(expanded);
      } catch (error) {
        debugPrint('Could not save the navigation sidebar: $error');
      }
    });
    return _pendingSave;
  }

  void _enterSidebar() {
    if (_isPinnedExpanded || _suppressHoverUntilExit || _isHoverExpanded) {
      return;
    }
    setState(() => _isHoverExpanded = true);
  }

  void _exitSidebar() {
    _suppressHoverUntilExit = false;
    if (_isHoverExpanded) {
      setState(() => _isHoverExpanded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mount the initial layout only after restoration, avoiding an expanded
    // sidebar flash and a content resize on launches with a collapsed setting.
    if (!_preferencesLoaded && !_hasToggled) {
      return const SizedBox.expand();
    }

    final visibleWidth = isExpanded ? _expandedWidth : _collapsedWidth;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _animationDuration;

    return Stack(
      fit: StackFit.expand,
      children: [
        Row(
          children: [
            // Only the saved choice reserves space in the page layout.
            AnimatedContainer(
              key: const ValueKey('navigation-sidebar-reserved-space'),
              duration: duration,
              curve: Curves.easeInOut,
              width: _isPinnedExpanded ? _expandedWidth : _collapsedWidth,
            ),
            Expanded(child: widget.child),
          ],
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: visibleWidth,
          child: MouseRegion(
            key: const ValueKey('navigation-sidebar-hover-region'),
            onEnter: (_) => _enterSidebar(),
            onExit: (_) => _exitSidebar(),
            // The complete open width accepts the pointer immediately, even
            // while the reveal animates, so entering quickly never flickers.
            child: Align(
              alignment: Alignment.topLeft,
              child: AnimatedContainer(
                key: const ValueKey('navigation-sidebar-panel'),
                duration: duration,
                curve: Curves.easeInOut,
                width: visibleWidth,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(2, 0),
                    ),
                  ],
                ),
                child: ClipRect(
                  // Lay out labels at their final width throughout the
                  // reveal rather than squeezing them into the icon rail.
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: visibleWidth,
                    maxWidth: visibleWidth,
                    child: ExcludeFocus(
                      // Preserve the billing page's existing Tab order.
                      child: _SidebarPresentation(
                        isExpanded: isExpanded,
                        isPinnedExpanded: _isPinnedExpanded,
                        child: widget.sidebarContent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SidebarPresentation extends InheritedWidget {
  final bool isExpanded;
  final bool isPinnedExpanded;

  const _SidebarPresentation({
    required this.isExpanded,
    required this.isPinnedExpanded,
    required super.child,
  });

  @override
  bool updateShouldNotify(_SidebarPresentation oldWidget) =>
      isExpanded != oldWidget.isExpanded ||
      isPinnedExpanded != oldWidget.isPinnedExpanded;
}

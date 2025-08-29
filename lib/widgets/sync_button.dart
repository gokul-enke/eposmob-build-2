import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sync_provider.dart';
import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';
import '../components/build_dialog_box.dart';

/// Reusable sync button widget that can be placed anywhere in the app
/// Similar to the keyboard icon implementation, this provides a consistent
/// sync interface across all screens.
class SyncButton extends StatelessWidget {
  final double? size;
  final bool showTooltip;
  final bool showText;
  final VoidCallback? onSyncComplete;
  final VoidCallback? onSyncError;

  const SyncButton({
    Key? key,
    this.size,
    this.showTooltip = true,
    this.showText = false,
    this.onSyncComplete,
    this.onSyncError,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncProvider>(
      builder: (context, syncProvider, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sync Icon Button
            IconButton(
              icon: syncProvider.isSyncing
                  ? SizedBox(
                      width: (size ?? 24) * 0.8,
                      height: (size ?? 24) * 0.8,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          ColorManager.kPrimaryColor,
                        ),
                        value: syncProvider.syncProgress > 0 
                            ? syncProvider.syncProgress 
                            : null,
                      ),
                    )
                  : Icon(
                      syncProvider.hasError
                          ? Icons.sync_problem
                          : Icons.sync,
                      color: syncProvider.hasError
                          ? Colors.red
                          : syncProvider.lastSyncTime != null
                              ? ColorManager.kPrimaryColor
                              : Colors.grey.shade600,
                      size: size ?? 24,
                    ),
              tooltip: showTooltip ? _getTooltipText(syncProvider) : null,
              onPressed: syncProvider.isSyncing
                  ? null
                  : () => _handleSyncPress(context, syncProvider),
            ),
            
            // Optional text display
            if (showText) ...[
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    syncProvider.isSyncing 
                        ? 'Syncing...' 
                        : syncProvider.hasError 
                            ? 'Sync Failed'
                            : 'Sync Data',
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s10,
                      0.16,
                      syncProvider.hasError 
                          ? Colors.red 
                          : ColorManager.textColor,
                    ),
                  ),
                  if (syncProvider.lastSyncTime != null)
                    Text(
                      'Last: ${syncProvider.getFormattedLastSyncTime()}',
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s8,
                        0.12,
                        Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  String _getTooltipText(SyncProvider syncProvider) {
    if (syncProvider.isSyncing) {
      return syncProvider.syncMessage.isNotEmpty 
          ? syncProvider.syncMessage 
          : 'Syncing data...';
    }
    
    if (syncProvider.hasError) {
      return 'Sync failed. Tap to retry.';
    }
    
    if (syncProvider.lastSyncTime != null) {
      return 'Last sync: ${syncProvider.getFormattedLastSyncTime()}\nTap to sync again';
    }
    
    return 'Sync all data';
  }

  void _handleSyncPress(BuildContext context, SyncProvider syncProvider) async {
    // Clear any previous errors
    if (syncProvider.hasError) {
      syncProvider.clearError();
    }

    try {
      await syncProvider.syncAllData(context);
      
      // Show success message using existing component
      if (context.mounted) {
        showScaffold(
          context: context,
          message: 'Data synced successfully!',
        );
        
        // Call completion callback if provided
        onSyncComplete?.call();
      }
    } catch (e) {
      // Show error message using existing component
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'Sync failed: ${e.toString()}',
        );
        
        // Call error callback if provided
        onSyncError?.call();
      }
    }
  }
}

/// Floating sync button that can be positioned anywhere on screen
/// Similar to a floating action button but specifically for sync operations
class FloatingSyncButton extends StatelessWidget {
  final Alignment alignment;
  final EdgeInsets margin;
  final VoidCallback? onSyncComplete;
  final VoidCallback? onSyncError;

  const FloatingSyncButton({
    Key? key,
    this.alignment = Alignment.bottomRight,
    this.margin = const EdgeInsets.all(16),
    this.onSyncComplete,
    this.onSyncError,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: Container(
          margin: margin,
          child: Consumer<SyncProvider>(
            builder: (context, syncProvider, child) {
              return FloatingActionButton(
                heroTag: "sync_fab", // Unique hero tag to avoid conflicts
                onPressed: syncProvider.isSyncing
                    ? null
                    : () => _handleSyncPress(context, syncProvider),
                backgroundColor: syncProvider.hasError
                    ? Colors.red
                    : ColorManager.kPrimaryColor,
                child: syncProvider.isSyncing
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          value: syncProvider.syncProgress > 0 
                              ? syncProvider.syncProgress 
                              : null,
                        ),
                      )
                    : Icon(
                        syncProvider.hasError ? Icons.sync_problem : Icons.sync,
                        color: Colors.white,
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleSyncPress(BuildContext context, SyncProvider syncProvider) async {
    // Clear any previous errors
    if (syncProvider.hasError) {
      syncProvider.clearError();
    }

    try {
      await syncProvider.syncAllData(context);
      
      // Show success message using existing component
      if (context.mounted) {
        showScaffold(
          context: context,
          message: 'Data synced successfully!',
        );
        
        // Call completion callback if provided
        onSyncComplete?.call();
      }
    } catch (e) {
      // Show error message using existing component
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'Sync failed: ${e.toString()}',
        );
        
        // Call error callback if provided
        onSyncError?.call();
      }
    }
  }
}
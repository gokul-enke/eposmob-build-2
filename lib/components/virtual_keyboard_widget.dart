import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:provider/provider.dart';
import 'package:virtual_keyboard_custom_layout/virtual_keyboard_custom_layout.dart';

class VirtualKeyboardWidget extends StatefulWidget {
  final TextEditingController controller;
  final VirtualKeyboardType keyboardType;
  final double height;
  final double width;
  final Color textColor;
  final VoidCallback? onClose;
  final VoidCallback? onConfirm;
  final bool shouldReplaceOnFirstInput;

  const VirtualKeyboardWidget({
    Key? key,
    required this.controller,
    required this.keyboardType,
    this.height = 300,
    this.width = 400,
    this.textColor = Colors.black,
    this.onClose,
    this.onConfirm,
    this.shouldReplaceOnFirstInput = false,
  }) : super(key: key);

  @override
  State<VirtualKeyboardWidget> createState() => _VirtualKeyboardWidgetState();
}

class _VirtualKeyboardWidgetState extends State<VirtualKeyboardWidget> {
  bool _isFirstInput = true;

  @override
  void initState() {
    super.initState();
    _isFirstInput = widget.shouldReplaceOnFirstInput;
  }

  @override
  void didUpdateWidget(covariant VirtualKeyboardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller ||
        oldWidget.shouldReplaceOnFirstInput !=
            widget.shouldReplaceOnFirstInput) {
      _isFirstInput = widget.shouldReplaceOnFirstInput;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Theme(
        data: ThemeData(
          textTheme: const TextTheme(
            bodyLarge: TextStyle(fontWeight: FontWeight.w600),
            bodyMedium: TextStyle(fontWeight: FontWeight.w600),
          ),
          splashColor: Colors.blue.withAlpha(90),
          highlightColor: Colors.blue.withAlpha(90),
          // Set canvas color for containers
          canvasColor: Colors.white,
        ),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Draggable header
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    // Drag handle
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: 20,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Title
                    Expanded(
                      child: Text(
                        widget.keyboardType == VirtualKeyboardType.Numeric
                            ? 'Numeric Keyboard'
                            : 'Virtual Keyboard',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    // Close button
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Keyboard content
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // Virtual keyboard - Fixed container to prevent overflow
                      Expanded(
                        child: SizedBox(
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return SizedBox(
                                  width: constraints.maxWidth,
                                  height: constraints.maxHeight,
                                  child: VirtualKeyboard(
                                    borderColor: Colors.grey[100],
                                    height: constraints.maxHeight,
                                    width: constraints.maxWidth,
                                    textColor: widget.textColor,
                                    fontSize: 18,
                                    type: widget.keyboardType,
                                    textController: widget.controller,
                                    onKeyPress: (key) {
                                      if (key.keyType ==
                                          VirtualKeyboardKeyType.String) {
                                        if (_isFirstInput &&
                                            widget.shouldReplaceOnFirstInput) {
                                          widget.controller.text = key.text;
                                          widget.controller.selection =
                                              TextSelection.fromPosition(
                                            TextPosition(
                                                offset: widget
                                                    .controller.text.length),
                                          );
                                          _isFirstInput = false;
                                        }
                                      } else if (key.keyType ==
                                          VirtualKeyboardKeyType.Action) {
                                        if (key.action ==
                                            VirtualKeyboardKeyAction
                                                .Backspace) {
                                          _isFirstInput = false;
                                        } else if (key.action ==
                                            VirtualKeyboardKeyAction.Return) {
                                          if (widget.onConfirm != null) {
                                            widget.onConfirm!();
                                          } else if (widget.onClose != null) {
                                            widget.onClose!();
                                          }
                                        }
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      // Action buttons (only show for numeric keyboard)
                      if (widget.keyboardType == VirtualKeyboardType.Numeric)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              // Clear button
                              Expanded(
                                child: Container(
                                  height: 40,
                                  margin: const EdgeInsets.only(right: 4),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      widget.controller.clear();
                                      _isFirstInput = true;
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[200],
                                      foregroundColor: Colors.grey[700],
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.clear, size: 16),
                                        SizedBox(width: 4),
                                        Text('general.clear'.tr,
                                            style: TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Confirm button
                              Expanded(
                                flex: 2,
                                child: Container(
                                  height: 40,
                                  margin: const EdgeInsets.only(left: 4),
                                  child: ElevatedButton(
                                    onPressed:
                                        widget.onConfirm ?? widget.onClose,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[600],
                                      foregroundColor: Colors.white,
                                      elevation: 1,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check, size: 16),
                                        SizedBox(width: 4),
                                        Text('general.confirm'.tr,
                                            style: TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GlobalVirtualKeyboard extends StatefulWidget {
  const GlobalVirtualKeyboard({Key? key}) : super(key: key);

  @override
  State<GlobalVirtualKeyboard> createState() => _GlobalVirtualKeyboardState();
}

class _GlobalVirtualKeyboardState extends State<GlobalVirtualKeyboard> {
  Offset _position = const Offset(50, 200);
  bool _isDragging = false;
  bool _isResizing = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<KeyboardProvider>(
      builder: (context, keyboardProvider, child) {
        if (!keyboardProvider.showKeyboardFeature ||
            !keyboardProvider.showKeyboard ||
            keyboardProvider.controller == null) {
          return const SizedBox.shrink();
        }

        VirtualKeyboardType keyboardType =
            keyboardProvider.keyboardType == 'number'
                ? VirtualKeyboardType.Numeric
                : keyboardProvider.keyboardType == 'text'
                    ? VirtualKeyboardType.Alphanumeric
                    : VirtualKeyboardType.Alphanumeric;

        // Get screen dimensions
        final screenSize = MediaQuery.of(context).size;

        // On PHONES only, render a bottom-docked full-width keyboard
        // Tablets (even Android/iOS) get the floating draggable keyboard
        final platform = Theme.of(context).platform;
        final isPhone = (platform == TargetPlatform.android ||
                platform == TargetPlatform.iOS) &&
            screenSize.width < 600; // Phone threshold

        if (isPhone) {
          final keyboardHeight =
              keyboardType == VirtualKeyboardType.Numeric ? 260.0 : 300.0;
          return Focus(
            canRequestFocus: false,
            descendantsAreFocusable: false,
            child: VirtualKeyboardWidget(
              controller: keyboardProvider.controller!,
              keyboardType: keyboardType,
              height: keyboardHeight,
              width: screenSize.width,
              textColor: Colors.black87,
              shouldReplaceOnFirstInput:
                  keyboardProvider.shouldReplaceOnFirstInput,
              onClose: () => keyboardProvider.hide(),
              onConfirm: () => keyboardProvider.hide(),
            ),
          );
        }

        // Tablets, desktop: floating, draggable keyboard
        final maxWidth = screenSize.width - 20; // Small margin from edges
        final maxHeight = screenSize.height - 100; // Account for status bar/nav

        // Sync local position with provider unless actively moving/resizing
        if (!_isDragging && !_isResizing) {
          _position = keyboardProvider.keyboardPosition;
        }

        // Get current keyboard size from provider
        Size currentSize = keyboardProvider.getKeyboardSize(keyboardType);

        // Ensure size is within bounds
        currentSize = Size(
          currentSize.width,
          currentSize.height,
        );

        return Positioned(
          left: _position.dx,
          top: _position.dy,
          child: Focus(
            canRequestFocus: false,
            descendantsAreFocusable: false,
            child: Stack(
              children: [
                // Main keyboard widget
                GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _isDragging = true;
                    });
                  },
                  onPanUpdate: (details) {
                    if (!_isResizing) {
                      setState(() {
                        _position = Offset(
                          _position.dx + details.delta.dx,
                          _position.dy + details.delta.dy,
                        );
                      });
                      // Persist position
                      keyboardProvider.setKeyboardPosition(_position);
                    }
                  },
                  onPanEnd: (details) {
                    setState(() {
                      _isDragging = false;

                      // Keep keyboard within screen bounds
                      double newX = _position.dx;
                      double newY = _position.dy;

                      // Clamp to screen boundaries
                      newX =
                          newX.clamp(0, screenSize.width - currentSize.width);
                      newY = newY.clamp(
                          0, screenSize.height - currentSize.height);

                      _position = Offset(newX, newY);
                      // Persist clamped position
                      keyboardProvider.setKeyboardPosition(_position);
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    transform: Matrix4.identity()
                      ..scale(_isDragging ? 1.02 : 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _isDragging || _isResizing
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                              ]
                            : null,
                      ),
                      child: Opacity(
                        opacity: _isDragging ? 0.9 : 1.0,
                        child: VirtualKeyboardWidget(
                          controller: keyboardProvider.controller!,
                          keyboardType: keyboardType,
                          height: currentSize.height,
                          width: currentSize.width,
                          textColor: Colors.black87,
                          shouldReplaceOnFirstInput:
                              keyboardProvider.shouldReplaceOnFirstInput,
                          onClose: () {
                            keyboardProvider.hide();
                          },
                          onConfirm: () {
                            keyboardProvider.hide();
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // Resize handle (bottom-right corner)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onPanStart: (details) {
                      setState(() {
                        _isResizing = true;
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        double newWidth =
                            currentSize.width + details.delta.dx;
                        double newHeight =
                            currentSize.height + details.delta.dy;

                        // Clamp only to the upper bound so the keyboard can shrink freely
                        newWidth = newWidth.clamp(0, maxWidth);
                        newHeight = newHeight.clamp(0, maxHeight);

                        Size newSize = Size(newWidth, newHeight);

                        // Update size in provider
                        keyboardProvider.setKeyboardSize(keyboardType, newSize);
                      });
                    },
                    onPanEnd: (details) {
                      setState(() {
                        _isResizing = false;

                        // Ensure keyboard stays within screen bounds after resize
                        double newX = _position.dx;
                        double newY = _position.dy;

                        Size finalSize =
                            keyboardProvider.getKeyboardSize(keyboardType);

                        if (_position.dx + finalSize.width >
                            screenSize.width) {
                          newX = screenSize.width - finalSize.width;
                        }
                        if (_position.dy + finalSize.height >
                            screenSize.height) {
                          newY = screenSize.height - finalSize.height;
                        }

                        _position = Offset(newX, newY);
                        // Persist updated position
                        keyboardProvider.setKeyboardPosition(_position);
                      });
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.8),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: const Icon(
                        Icons.open_in_full_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

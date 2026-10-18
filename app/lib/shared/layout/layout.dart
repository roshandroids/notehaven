import 'package:flutter/widgets.dart';

/// Width (logical px) from which the notes list and editor sit side by side.
const double splitViewMinWidth = 900;

/// Width of the notes list pane in split view.
const double listPaneWidth = 400;

/// True when the window is wide enough for list + detail side by side.
bool isSplitView(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= splitViewMinWidth;

/// True when the user asked the OS to reduce motion; skip decorative animation.
bool reduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);

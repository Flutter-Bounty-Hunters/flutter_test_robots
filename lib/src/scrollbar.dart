import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simulates the user interacting with a Scrollbar.
extension ScrollbarInteractions on WidgetTester {
  /// Drag the scrollbar down by [delta] pixels.
  ///
  /// By default, this method expects a single [Scrollbar] in the widget tree and
  /// finds it `byType`. To specify one [Scrollbar] among many, pass a [finder].
  Future<void> dragScrollbarDown(double delta, [Finder? finder]) async {
    await _dragScrollbar(delta, finder);
  }

  /// Drag the scrollbar up by [delta] pixels.
  ///
  /// By default, this method expects a single [Scrollbar] in the widget tree and
  /// finds it `byType`. To specify one [Scrollbar] among many, pass a [finder].
  Future<void> dragScrollbarUp(double delta, [Finder? finder]) async {
    await _dragScrollbar(-delta, finder);
  }

  /// Drag the scrollbar by [delta] pixels.
  ///
  /// A positive [delta] scrolls down or right, depending on the scrollbar's orientation,
  /// and a negative [delta] scrolls up or left.
  ///
  /// By default, this method expects a single [Scrollbar] in the widget tree and
  /// finds it `byType`. To specify one [Scrollbar] among many, pass a [finder].
  Future<void> _dragScrollbar(double delta, [Finder? finder]) async {
    // Find where the scrollbar's thumb sits.
    final thumbRect = _findThumbRect(finder ?? find.byType(Scrollbar));
    final thumbOffset = thumbRect.center;

    final testPointer = TestPointer(1, PointerDeviceKind.mouse);

    // Hover to make the thumb visible with a duration long enough to run the fade in animation.
    await sendEventToBinding(testPointer.hover(thumbOffset, timeStamp: const Duration(seconds: 1)));
    await pumpAndSettle();

    // Press the thumb.
    await sendEventToBinding(testPointer.down(thumbOffset));
    await pump(const Duration(milliseconds: 40));

    // Move the thumb.
    await sendEventToBinding(testPointer.move(thumbOffset + Offset(0, delta)));
    await pump();

    // Release the pointer.
    await sendEventToBinding(testPointer.up());
    await pump();
  }

  /// Finds the thumb's rect, in global coordinates.
  ///
  /// Adapted from ScrollbarPainter._paintScrollbar.
  Rect _findThumbRect(Finder scrollbarFinder) {
    // Find the Scrollbar's Scrollable.
    final scrollState = state<ScrollableState>(find.descendant(
      of: scrollbarFinder,
      matching: find.byType(Scrollable),
    ));

    // Find the Scrollbar's ScrollbarPainter, which is used to paint the thumb.
    // The ScrollbarPainter is used to gather information necessary to compute the thumb's
    // position and size.
    final scrollbarPainter = widget<CustomPaint>(
      find.descendant(
        of: scrollbarFinder,
        matching: find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.foregroundPainter is ScrollbarPainter,
        ),
      ),
    ).foregroundPainter as ScrollbarPainter;

    final scrollPosition = scrollState.position;
    final isVertical = scrollPosition.axisDirection == AxisDirection.down || //
        scrollPosition.axisDirection == AxisDirection.up;

    final orientation = _resolvedOrientation(scrollbarPainter, isVertical);
    final leadingTrackMainAxisOffset =
        orientation == ScrollbarOrientation.left || orientation == ScrollbarOrientation.right //
            ? scrollbarPainter.padding.top
            : scrollbarPainter.padding.left;

    final leadingThumbMainAxisOffset = leadingTrackMainAxisOffset + scrollbarPainter.mainAxisMargin;

    final traversableTrackExtent = _findTraversableTrackExtent(
      scrollbarPainter: scrollbarPainter,
      scrollPosition: scrollPosition,
    );
    final thumbExtent = _findThumbExtent(
      scrollbarPainter: scrollbarPainter,
      scrollPosition: scrollPosition,
      traversableTrackExtent: traversableTrackExtent,
    );
    final thumbOffset = _getScrollToTrack(
          scrollbarPainter: scrollbarPainter,
          scrollPosition: scrollPosition,
          thumbExtent: thumbExtent,
        ) +
        leadingThumbMainAxisOffset;

    late double thumbX, thumbY;
    late Size thumbSize;

    final scrollableSize = (scrollState.context.findRenderObject() as RenderBox).size;
    switch (orientation) {
      case ScrollbarOrientation.left:
        thumbSize = Size(scrollbarPainter.thickness, thumbExtent);
        thumbX = scrollbarPainter.crossAxisMargin + scrollbarPainter.padding.left;
        thumbY = thumbOffset;
        break;
      case ScrollbarOrientation.right:
        thumbSize = Size(scrollbarPainter.thickness, thumbExtent);
        thumbX = scrollableSize.width -
            scrollbarPainter.thickness -
            scrollbarPainter.crossAxisMargin -
            scrollbarPainter.padding.right;
        thumbY = thumbOffset;
        break;
      case ScrollbarOrientation.top:
        thumbSize = Size(thumbExtent, scrollbarPainter.thickness);
        thumbX = thumbOffset;
        thumbY = scrollbarPainter.crossAxisMargin + scrollbarPainter.padding.top;
        break;
      case ScrollbarOrientation.bottom:
        thumbSize = Size(thumbExtent, scrollbarPainter.thickness);
        thumbX = thumbOffset;
        thumbY = scrollableSize.height -
            scrollbarPainter.thickness -
            scrollbarPainter.crossAxisMargin -
            scrollbarPainter.padding.bottom;
        break;
    }

    final scrollbarRenderBox = element(scrollbarFinder).findRenderObject() as RenderBox;
    return scrollbarRenderBox.localToGlobal(Offset(thumbX, thumbY)) & thumbSize;
  }

  /// Converts between a scroll position and the corresponding position in the
  /// thumb track, in ScrollBar's coordinates.
  ///
  /// Copied and adapted from ScrollbarPainter._getScrollToTrack.
  double _getScrollToTrack({
    required ScrollbarPainter scrollbarPainter,
    required ScrollPosition scrollPosition,
    required double thumbExtent,
  }) {
    final scrollableExtent = scrollPosition.maxScrollExtent - scrollPosition.minScrollExtent;
    final axisDirection = scrollPosition.axisDirection;

    final fractionPast = (scrollableExtent > 0)
        ? clampDouble((scrollPosition.pixels - scrollPosition.minScrollExtent) / scrollableExtent, 0.0, 1.0)
        : 0.0;

    final isReversed = scrollPosition.axisDirection == AxisDirection.up || //
        scrollPosition.axisDirection == AxisDirection.left;

    final isVertical = axisDirection == AxisDirection.down || //
        axisDirection == AxisDirection.up;
    final totalTrackMainAxisOffset =
        isVertical ? scrollbarPainter.padding.vertical : scrollbarPainter.padding.horizontal;
    final trackExtent = scrollPosition.viewportDimension - totalTrackMainAxisOffset;
    final traversableTrackExtent = trackExtent - (2 * scrollbarPainter.mainAxisMargin);

    return (isReversed ? 1 - fractionPast : fractionPast) * (traversableTrackExtent - thumbExtent);
  }

  /// Returns the position where the Scrollbar is painted.
  ///
  /// The scrollbar can be painted in the left or right edge when it's vertical,
  /// or at the bottom when it's horizontal.
  ///
  /// Copied from ScrollbarPainter._resolvedOrientation.
  ScrollbarOrientation _resolvedOrientation(ScrollbarPainter scrollbarPainter, bool isVertical) {
    if (scrollbarPainter.scrollbarOrientation == null) {
      if (isVertical) {
        return scrollbarPainter.textDirection == TextDirection.ltr
            ? ScrollbarOrientation.right
            : ScrollbarOrientation.left;
      }
      return ScrollbarOrientation.bottom;
    }
    return scrollbarPainter.scrollbarOrientation!;
  }

  // Copied from ScrollbarPainter._setThumbExtent.
  double _findThumbExtent({
    required ScrollbarPainter scrollbarPainter,
    required ScrollPosition scrollPosition,
    required double traversableTrackExtent,
  }) {
    final isVertical = scrollPosition.axisDirection == AxisDirection.down || //
        scrollPosition.axisDirection == AxisDirection.up;
    final totalTrackMainAxisOffsets =
        isVertical ? scrollbarPainter.padding.vertical : scrollbarPainter.padding.horizontal;
    final totalContentExtent =
        scrollPosition.maxScrollExtent - scrollPosition.minScrollExtent + scrollPosition.viewportDimension;

    // Thumb extent reflects fraction of content visible, as long as this
    // isn't less than the absolute minimum size.
    // _totalContentExtent >= viewportDimension, so (_totalContentExtent - _mainAxisPadding) > 0
    final fractionVisible = clampDouble(
      (scrollPosition.extentInside - totalTrackMainAxisOffsets) / (totalContentExtent - totalTrackMainAxisOffsets),
      0.0,
      1.0,
    );

    final thumbExtent = math.max(
      math.min(traversableTrackExtent, scrollbarPainter.minOverscrollLength),
      traversableTrackExtent * fractionVisible,
    );

    final fractionOverscrolled = 1.0 - scrollPosition.extentInside / scrollPosition.viewportDimension;
    final safeMinLength = math.min(scrollbarPainter.minLength, traversableTrackExtent);

    final isReversed = scrollPosition.axisDirection == AxisDirection.up || //
        scrollPosition.axisDirection == AxisDirection.left;
    final beforeExtent = isReversed ? scrollPosition.extentAfter : scrollPosition.extentBefore;
    final afterExtent = isReversed ? scrollPosition.extentBefore : scrollPosition.extentAfter;
    final newMinLength = (beforeExtent > 0 && afterExtent > 0)
        // Thumb extent is no smaller than minLength if scrolling normally.
        ? safeMinLength
        // User is overscrolling. Thumb extent can be less than minLength
        // but no smaller than minOverscrollLength. We can't use the
        // fractionVisible to produce intermediate values between minLength and
        // minOverscrollLength when the user is transitioning from regular
        // scrolling to overscrolling, so we instead use the percentage of the
        // content that is still in the viewport to determine the size of the
        // thumb. iOS behavior appears to have the thumb reach its minimum size
        // with ~20% of overscroll. We map the percentage of minLength from
        // [0.8, 1.0] to [0.0, 1.0], so 0% to 20% of overscroll will produce
        // values for the thumb that range between minLength and the smallest
        // possible value, minOverscrollLength.
        : safeMinLength * (1.0 - clampDouble(fractionOverscrolled, 0.0, 0.2) / 0.2);

    // The `thumbExtent` should be no greater than `trackSize`, otherwise
    // the scrollbar may scroll towards the wrong direction.
    return clampDouble(thumbExtent, newMinLength, traversableTrackExtent);
  }

  /// The full length of the track that the thumb can travel.
  ///
  /// Copied from ScrollbarPainter._traversableTrackExtent.
  double _findTraversableTrackExtent({
    required ScrollbarPainter scrollbarPainter,
    required ScrollPosition scrollPosition,
  }) {
    final isVertical = scrollPosition.axisDirection == AxisDirection.down || //
        scrollPosition.axisDirection == AxisDirection.up;

    final totalTrackMainAxisOffset =
        isVertical ? scrollbarPainter.padding.vertical : scrollbarPainter.padding.horizontal;
    final trackExtent = scrollPosition.viewportDimension - totalTrackMainAxisOffset;

    return trackExtent - (2 * scrollbarPainter.mainAxisMargin);
  }
}

# CI log (run 44905213567)

```
out (package:flutter/src/rendering/object.dart:2923:7)
#62     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#63     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#64     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#65     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#66     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#67     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#68     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#69     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#70     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#71     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#72     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#73     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#74     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#75     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#76     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#77     RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#78     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#79     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#80     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#81     _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#82     _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#83     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#84     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#85     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#86     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#87     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#88     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#89     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#90     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#91     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#92     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#93     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#94     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#95     RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#96     PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#97     PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#98     AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#99     RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#100    SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#101    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#102    AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#105    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#106    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#107    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#110    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#111    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#112    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#113    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:243:5)
<asynchronous suspension>
#114    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#115    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 7 frames from class _AssertionError, dart:async, and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderSliverToBoxAdapter#9939e relayoutBoundary=up1 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  creator: SliverToBoxAdapter ← Viewport ← IgnorePointer-[GlobalKey#9b947] ← Semantics ← Listener ←
    _GestureSemantics ← RawGestureDetector-[LabeledGlobalKey<RawGestureDetectorState>#d57bf] ←
    Listener ← _ScrollableScope ← _ScrollSemantics-[GlobalKey#de90b] ←
    NotificationListener<ScrollMetricsNotification> ← Transform ← ⋯
  parentData: paintOffset=Offset(0.0, 0.0) (can use size)
  constraints: SliverConstraints(AxisDirection.down, GrowthDirection.forward, ScrollDirection.idle,
    scrollOffset: 0.0, precedingScrollExtent: 60.0, remainingPaintExtent: 540.0, crossAxisExtent:
    800.0, crossAxisDirection: AxisDirection.left, viewportMainAxisExtent: 600.0,
    remainingCacheExtent: 790.0, cacheOrigin: 0.0)
  geometry: null
This RenderObject had the following descendants (showing up to depth 5):
    child: RenderPadding#884a8 relayoutBoundary=up2 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderPhysicalShape#1feb2 relayoutBoundary=up3 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderCustomPaint#82b32 relayoutBoundary=up4 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: _RenderInkFeatures#3cee8 relayoutBoundary=up5 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderSemanticsAnnotations#8bed9 relayoutBoundary=up6 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following _TypeError was thrown during performLayout():
Null check operator used on a null value

The relevant error-causing widget was:
  CustomScrollView
  CustomScrollView:file:///home/runner/work/Ideal/Ideal/lib/features/messages/messages_screen.dart:26:12

When the exception was thrown, this was the stack:
#0      RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:842:64)
#1      RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#2      RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#3      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#4      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#5      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#6      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#7      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#8      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#9      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#10     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#11     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#12     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#13     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#14     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#15     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#16     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#17     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#18     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#19     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#20     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#21     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#22     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#23     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#24     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#25     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#26     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#27     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#28     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#29     _RenderLayoutBuilder.performLayout (package:flutter/src/widgets/layout_builder.dart:449:14)
#30     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#31     MultiChildLayoutDelegate.layoutChild (package:flutter/src/rendering/custom_layout.dart:180:12)
#32     _ScaffoldLayout.performLayout (package:flutter/src/material/scaffold.dart:1113:7)
#33     MultiChildLayoutDelegate._callPerformLayout (package:flutter/src/rendering/custom_layout.dart:246:7)
#34     RenderCustomMultiChildLayoutBox.performLayout (package:flutter/src/rendering/custom_layout.dart:417:14)
#35     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#36     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#37     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#38     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#39     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#40     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#41     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#42     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#43     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#44     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#45     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#46     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#47     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#48     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#49     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#50     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#51     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#52     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#53     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#54     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#55     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#56     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#57     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#58     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#59     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#60     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#61     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#62     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#63     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#64     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#65     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#66     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#67     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#68     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#69     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#70     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#71     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#72     RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#73     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#74     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#75     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#76     _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#77     _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#78     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#79     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#80     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#81     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#82     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#83     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#84     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#85     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#86     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#87     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#88     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#89     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#90     RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#91     PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#92     PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#93     AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#94     RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#95     SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#96     SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#97     AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#100    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#101    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#102    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#105    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#106    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#107    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#108    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:243:5)
<asynchronous suspension>
#109    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#110    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 5 frames from dart:async and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderViewport#be138 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  needs compositing
  creator: Viewport ← IgnorePointer-[GlobalKey#9b947] ← Semantics ← Listener ← _GestureSemantics ←
    RawGestureDetector-[LabeledGlobalKey<RawGestureDetectorState>#d57bf] ← Listener ← _ScrollableScope
    ← _ScrollSemantics-[GlobalKey#de90b] ← NotificationListener<ScrollMetricsNotification> ← Transform
    ← StretchEffect ← ⋯
  parentData: <none> (can use size)
  constraints: BoxConstraints(0.0<=w<=800.0, 0.0<=h<=600.0)
  size: Size(800.0, 600.0)
  axisDirection: down
  crossAxisDirection: left
  offset: ScrollPositionWithSingleContext#41d7c(offset: 0.0, range: null..null, viewport: 600.0,
    ScrollableState, AlwaysScrollableScrollPhysics -> ClampingScrollPhysics ->
    RangeMaintainingScrollPhysics, IdleScrollActivity#b5160, ScrollDirection.idle)
  anchor: 0.0
This RenderObject had the following descendants (showing up to depth 5):
    center child: RenderSliverToBoxAdapter#696a0 relayoutBoundary=up1 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderPadding#f1579 relayoutBoundary=up2 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderFlex#4c96b relayoutBoundary=up3 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child 1: RenderParagraph#781c5 relayoutBoundary=up4 NEEDS-PAINT
            text: TextSpan
    child 1: RenderSliverToBoxAdapter#9939e relayoutBoundary=up1 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderPadding#884a8 relayoutBoundary=up2 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderPhysicalShape#1feb2 relayoutBoundary=up3 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderCustomPaint#82b32 relayoutBoundary=up4 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: _RenderInkFeatures#3cee8 relayoutBoundary=up5 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
    child 2: RenderSliverToBoxAdapter#f3c0b NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderPadding#73010 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderClipRRect#691aa NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderBackdropFilter#1fa37 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderDecoratedBox#08e90 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
    child 3: RenderSliverFillRemainingWithScrollable#39375 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderPositionedBox#dc49f NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderSemanticsAnnotations#bcf9a NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderConstrainedBox#68211 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderCustomPaint#77937 NEEDS-LAYOUT NEEDS-PAINT
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following _TypeError was thrown during performLayout():
Null check operator used on a null value

The relevant error-causing widget was:
  CustomScrollView
  CustomScrollView:file:///home/runner/work/Ideal/Ideal/lib/features/messages/messages_screen.dart:26:12

When the exception was thrown, this was the stack:
#0      RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:842:64)
#1      RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#2      RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#3      RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#4      PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#5      PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#6      AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#7      RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#8      SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#9      SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#10     AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#13     TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#14     AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#15     WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#18     TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#19     WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#20     main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#21     main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:243:5)
<asynchronous suspension>
#22     testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#23     TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 5 frames from dart:async and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderViewport#be138 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  needs compositing
  creator: Viewport ← IgnorePointer-[GlobalKey#9b947] ← Semantics ← Listener ← _GestureSemantics ←
    RawGestureDetector-[LabeledGlobalKey<RawGestureDetectorState>#d57bf] ← Listener ← _ScrollableScope
    ← _ScrollSemantics-[GlobalKey#de90b] ← NotificationListener<ScrollMetricsNotification> ← Transform
    ← StretchEffect ← ⋯
  parentData: <none> (can use size)
  constraints: BoxConstraints(0.0<=w<=800.0, 0.0<=h<=600.0)
  size: Size(800.0, 600.0)
  axisDirection: down
  crossAxisDirection: left
  offset: ScrollPositionWithSingleContext#41d7c(offset: 0.0, range: null..null, viewport: 600.0,
    ScrollableState, AlwaysScrollableScrollPhysics -> ClampingScrollPhysics ->
    RangeMaintainingScrollPhysics, IdleScrollActivity#b5160, ScrollDirection.idle)
  anchor: 0.0
This RenderObject had the following descendants (showing up to depth 5):
    center child: RenderSliverToBoxAdapter#696a0 relayoutBoundary=up1 NEEDS-PAINT
      child: RenderPadding#f1579 relayoutBoundary=up2 NEEDS-PAINT
        child: RenderFlex#4c96b relayoutBoundary=up3 NEEDS-PAINT
          child 1: RenderParagraph#781c5 relayoutBoundary=up4 NEEDS-PAINT
            text: TextSpan
    child 1: RenderSliverToBoxAdapter#9939e relayoutBoundary=up1 NEEDS-PAINT
      child: RenderPadding#884a8 relayoutBoundary=up2 NEEDS-PAINT
        child: RenderPhysicalShape#1feb2 relayoutBoundary=up3 NEEDS-PAINT
          child: RenderCustomPaint#82b32 relayoutBoundary=up4 NEEDS-PAINT
            child: _RenderInkFeatures#3cee8 relayoutBoundary=up5 NEEDS-PAINT
    child 2: RenderSliverToBoxAdapter#f3c0b NEEDS-LAYOUT NEEDS-PAINT
      child: RenderPadding#73010 NEEDS-LAYOUT NEEDS-PAINT
        child: RenderClipRRect#691aa NEEDS-LAYOUT NEEDS-PAINT
          child: RenderBackdropFilter#1fa37 NEEDS-LAYOUT NEEDS-PAINT
            child: RenderDecoratedBox#08e90 NEEDS-LAYOUT NEEDS-PAINT
    child 3: RenderSliverFillRemaining#ae398 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderPadding#462d6 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderFlex#8894a NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child 1: RenderConstrainedBox#e8ea0 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderDecoratedBox#798a1 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child 2: RenderConstrainedBox#48b38 NEEDS-LAYOUT NEEDS-PAINT
          child 3: RenderParagraph#ee471 NEEDS-LAYOUT NEEDS-PAINT
            text: TextSpan
          child 4: RenderConstrainedBox#2f43c NEEDS-LAYOUT NEEDS-PAINT
          child 5: RenderParagraph#7d8b5 NEEDS-LAYOUT NEEDS-PAINT
            text: TextSpan
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following message was thrown:
Multiple exceptions (27) were detected during the running of the current test, and at least one was
unexpected.
════════════════════════════════════════════════════════════════════════════════════════════════════
00:04 +0 -3: typed assistant input opens the confirmation sheet [E]
  Test failed. See exception logs above.
  The test description was: typed assistant input opens the confirmation sheet
  
00:04 +0 -3: a stored note appears in the notes tab
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during performLayout():
BoxConstraints forces an infinite height.
These invalid constraints were provided to RenderPadding's layout() function by the following
function, which probably computed the invalid constraints in question:
  ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
The offending constraints were:
  BoxConstraints(0.0<=w<=Infinity, h=Infinity)

The relevant error-causing widget was:
  Row Row:file:///home/runner/work/Ideal/Ideal/lib/ui/widgets/glass_card.dart:118:17

When the exception was thrown, this was the stack:
#0      BoxConstraints.debugAssertIsValid.<anonymous closure>.throwError (package:flutter/src/rendering/box.dart:549:9)
#1      BoxConstraints.debugAssertIsValid.<anonymous closure> (package:flutter/src/rendering/box.dart:614:11)
#2      BoxConstraints.debugAssertIsValid (package:flutter/src/rendering/box.dart:619:6)
#3      RenderObject.layout (package:flutter/src/rendering/object.dart:2823:19)
#4      ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#5      RenderFlex._computeSizes (package:flutter/src/rendering/flex.dart:1237:28)
#6      RenderFlex.performLayout (package:flutter/src/rendering/flex.dart:1329:32)
#7      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#8      RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#9      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#10     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#11     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#12     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#13     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#14     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#15     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#16     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#17     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#18     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#19     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#20     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#21     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#22     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#23     RenderCustomPaint.performLayout (package:flutter/src/rendering/custom_paint.dart:574:11)
#24     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#25     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#26     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#27     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#28     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#29     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#30     RenderSliverToBoxAdapter.performLayout (package:flutter/src/rendering/sliver.dart:2098:12)
#31     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#32     RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:821:13)
#33     RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#34     RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#35     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#36     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#37     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#38     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#39     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#40     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#41     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#42     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#43     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#44     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#45     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#46     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#47     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#48     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#49     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#50     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#51     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#52     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#53     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#54     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#55     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#56     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#57     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#58     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#59     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#60     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#61     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#62     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#63     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#64     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#65     _RenderLayoutBuilder.performLayout (package:flutter/src/widgets/layout_builder.dart:449:14)
#66     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#67     MultiChildLayoutDelegate.layoutChild (package:flutter/src/rendering/custom_layout.dart:180:12)
#68     _ScaffoldLayout.performLayout (package:flutter/src/material/scaffold.dart:1113:7)
#69     MultiChildLayoutDelegate._callPerformLayout (package:flutter/src/rendering/custom_layout.dart:246:7)
#70     RenderCustomMultiChildLayoutBox.performLayout (package:flutter/src/rendering/custom_layout.dart:417:14)
#71     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#72     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#73     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#74     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#75     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#76     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#77     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#78     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#79     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#80     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#81     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#82     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#83     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#84     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#85     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#86     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#87     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#88     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#89     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#90     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#91     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#92     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#93     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#94     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#95     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#96     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#97     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#98     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#99     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#100    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#101    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#102    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#103    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#104    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#105    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#106    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#107    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#108    RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#109    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#110    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#111    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#112    _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#113    _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#114    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#115    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#116    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#117    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#118    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#119    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#120    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#121    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#122    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#123    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#124    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#125    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#126    RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#127    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#128    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#129    AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#130    RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#131    SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#132    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#133    AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#136    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#137    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#138    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#141    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#142    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#143    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#144    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:263:22)
<asynchronous suspension>
#145    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#146    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 5 frames from dart:async and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderFlex#88dd2 relayoutBoundary=up12 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  creator: Row ← Padding ← DecoratedBox ← Container ← Listener ← RawGestureDetector ← GestureDetector
    ← Semantics ← DefaultSelectionStyle ← Builder ← MouseRegion ← Semantics ← ⋯
  parentData: offset=Offset(15.0, 15.0) (can use size)
  constraints: BoxConstraints(w=730.0, 0.0<=h<=Infinity)
  size: MISSING
  direction: horizontal
  mainAxisAlignment: start
  mainAxisSize: max
  crossAxisAlignment: stretch
  textDirection: rtl
  verticalDirection: down
  spacing: 0.0
This RenderObject had the following descendants (showing up to depth 5):
    child 1: RenderPadding#279b9 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderConstrainedBox#7356b NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderDecoratedBox#475ad NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderPadding#01c54 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderLimitedBox#a95f2 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
    child 2: RenderFlex#c5c0d NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child 1: RenderSemanticsAnnotations#5c25d NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderExcludeSemantics#1326e NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderConstrainedBox#d7b34 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderPositionedBox#d8883 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child 2: RenderConstrainedBox#e7ad9 NEEDS-LAYOUT NEEDS-PAINT
      child 3: RenderParagraph#8e1f1 NEEDS-LAYOUT NEEDS-PAINT
        text: TextSpan
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during performLayout():
RenderBox was not laid out: RenderFlex#88dd2 relayoutBoundary=up12 NEEDS-PAINT
NEEDS-COMPOSITING-BITS-UPDATE
'package:flutter/src/rendering/box.dart':
Failed assertion: line 2251 pos 12: 'hasSize'

Either the assertion indicates an error in the framework itself, or we should provide substantially
more information in this error message to help you determine and fix the underlying cause.
In either case, please report this assertion by filing a bug on GitHub:
  https://github.com/flutter/flutter/issues/new?template=02_bug.yml

The relevant error-causing widget was:
  Container Container:file:///home/runner/work/Ideal/Ideal/lib/ui/widgets/glass_card.dart:106:16

When the exception was thrown, this was the stack:
#2      RenderBox.size (package:flutter/src/rendering/box.dart:2251:12)
#3      RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:266:40)
#4      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#5      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#6      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#7      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#8      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#9      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#10     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#11     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#12     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#13     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#14     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#15     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#16     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#17     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#18     RenderCustomPaint.performLayout (package:flutter/src/rendering/custom_paint.dart:574:11)
#19     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#20     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#21     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#22     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#23     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#24     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#25     RenderSliverToBoxAdapter.performLayout (package:flutter/src/rendering/sliver.dart:2098:12)
#26     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#27     RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:821:13)
#28     RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#29     RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#30     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#31     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#32     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#33     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#34     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#35     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#36     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#37     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#38     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#39     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#40     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#41     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#42     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#43     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#44     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#45     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#46     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#47     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#48     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#49     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#50     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#51     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#52     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#53     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#54     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#55     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#56     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#57     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#58     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#59     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#60     _RenderLayoutBuilder.performLayout (package:flutter/src/widgets/layout_builder.dart:449:14)
#61     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#62     MultiChildLayoutDelegate.layoutChild (package:flutter/src/rendering/custom_layout.dart:180:12)
#63     _ScaffoldLayout.performLayout (package:flutter/src/material/scaffold.dart:1113:7)
#64     MultiChildLayoutDelegate._callPerformLayout (package:flutter/src/rendering/custom_layout.dart:246:7)
#65     RenderCustomMultiChildLayoutBox.performLayout (package:flutter/src/rendering/custom_layout.dart:417:14)
#66     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#67     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#68     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#69     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#70     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#71     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#72     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#73     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#74     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#75     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#76     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#77     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#78     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#79     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#80     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#81     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#82     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#83     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#84     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#85     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#86     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#87     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#88     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#89     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#90     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#91     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#92     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#93     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#94     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#95     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#96     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#97     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#98     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#99     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#100    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#101    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#102    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#103    RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#104    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#105    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#106    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#107    _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#108    _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#109    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#110    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#111    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#112    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#113    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#114    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#115    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#116    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#117    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#118    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#119    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#120    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#121    RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#122    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#123    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#124    AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#125    RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#126    SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#127    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#128    AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#131    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#132    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#133    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#136    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#137    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#138    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#139    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:263:22)
<asynchronous suspension>
#140    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#141    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 7 frames from class _AssertionError, dart:async, and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderPadding#1ea85 relayoutBoundary=up11 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  creator: Padding ← DecoratedBox ← Container ← Listener ← RawGestureDetector ← GestureDetector ←
    Semantics ← DefaultSelectionStyle ← Builder ← MouseRegion ← Semantics ← _FocusInheritedScope ← ⋯
  parentData: <none> (can use size)
  constraints: BoxConstraints(w=760.0, 0.0<=h<=Infinity)
  size: MISSING
  padding: EdgeInsets.all(15.0)
  textDirection: rtl
This RenderObject had the following descendants (showing up to depth 5):
    child: RenderFlex#88dd2 relayoutBoundary=up12 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child 1: RenderPadding#279b9 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderConstrainedBox#7356b NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderDecoratedBox#475ad NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderPadding#01c54 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child 2: RenderFlex#c5c0d NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child 1: RenderSemanticsAnnotations#5c25d NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderExcludeSemantics#1326e NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderConstrainedBox#d7b34 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child 2: RenderConstrainedBox#e7ad9 NEEDS-LAYOUT NEEDS-PAINT
        child 3: RenderParagraph#8e1f1 NEEDS-LAYOUT NEEDS-PAINT
          text: TextSpan
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during performLayout():
RenderBox was not laid out: RenderPadding#1ea85 relayoutBoundary=up11 NEEDS-PAINT
NEEDS-COMPOSITING-BITS-UPDATE
'package:flutter/src/rendering/box.dart':
Failed assertion: line 2251 pos 12: 'hasSize'

Either the assertion indicates an error in the framework itself, or we should provide substantially
more information in this error message to help you determine and fix the underlying cause.
In either case, please report this assertion by filing a bug on GitHub:
  https://github.com/flutter/flutter/issues/new?template=02_bug.yml

The relevant error-causing widget was:
  Container Container:file:///home/runner/work/Ideal/Ideal/lib/ui/widgets/glass_card.dart:106:16

When the exception was thrown, this was the stack:
#2      RenderBox.size (package:flutter/src/rendering/box.dart:2251:12)
#3      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:62)
#4      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#5      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#6      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#7      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#8      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#9      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#10     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#11     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#12     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#13     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#14     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#15     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#16     RenderCustomPaint.performLayout (package:flutter/src/rendering/custom_paint.dart:574:11)
#17     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#18     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#19     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#20     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#21     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#22     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#23     RenderSliverToBoxAdapter.performLayout (package:flutter/src/rendering/sliver.dart:2098:12)
#24     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#25     RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:821:13)
#26     RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#27     RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#28     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#29     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#30     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#31     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#32     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#33     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#34     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#35     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#36     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#37     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#38     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#39     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#40     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#41     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#42     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#43     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#44     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#45     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#46     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#47     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#48     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#49     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#50     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#51     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#52     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#53     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#54     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#55     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#56     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#57     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#58     _RenderLayoutBuilder.performLayout (package:flutter/src/widgets/layout_builder.dart:449:14)
#59     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#60     MultiChildLayoutDelegate.layoutChild (package:flutter/src/rendering/custom_layout.dart:180:12)
#61     _ScaffoldLayout.performLayout (package:flutter/src/material/scaffold.dart:1113:7)
#62     MultiChildLayoutDelegate._callPerformLayout (package:flutter/src/rendering/custom_layout.dart:246:7)
#63     RenderCustomMultiChildLayoutBox.performLayout (package:flutter/src/rendering/custom_layout.dart:417:14)
#64     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#65     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#66     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#67     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#68     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#69     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#70     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#71     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#72     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#73     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#74     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#75     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#76     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#77     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#78     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#79     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#80     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#81     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#82     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#83     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#84     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#85     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#86     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#87     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#88     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#89     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#90     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#91     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#92     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#93     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#94     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#95     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#96     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#97     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#98     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#99     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#100    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#101    RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#102    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#103    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#104    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#105    _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#106    _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#107    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#108    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#109    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#110    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#111    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#112    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#113    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#114    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#115    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#116    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#117    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#118    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#119    RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#120    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#121    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#122    AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#123    RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#124    SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#125    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#126    AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#129    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#130    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#131    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#134    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#135    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#136    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#137    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:263:22)
<asynchronous suspension>
#138    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#139    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 7 frames from class _AssertionError, dart:async, and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderDecoratedBox#e8f8d relayoutBoundary=up10 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  creator: DecoratedBox ← Container ← Listener ← RawGestureDetector ← GestureDetector ← Semantics ←
    DefaultSelectionStyle ← Builder ← MouseRegion ← Semantics ← _FocusInheritedScope ← Focus ← ⋯
  parentData: <none> (can use size)
  constraints: BoxConstraints(w=760.0, 0.0<=h<=Infinity)
  size: MISSING
  decoration: BoxDecoration:
    border: Border.all(BorderSide(color: Color(alpha: 0.0600, red: 1.0000, green: 1.0000, blue: 1.0000,
      colorSpace: ColorSpace.sRGB)))
    borderRadius: BorderRadius.circular(22.0)
  configuration: ImageConfiguration(bundle: PlatformAssetBundle#785c1(), devicePixelRatio: 3.0,
    locale: fa_IR, textDirection: TextDirection.rtl, platform: android)
This RenderObject had the following descendants (showing up to depth 5):
    child: RenderPadding#1ea85 relayoutBoundary=up11 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderFlex#88dd2 relayoutBoundary=up12 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child 1: RenderPadding#279b9 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderConstrainedBox#7356b NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderDecoratedBox#475ad NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child 2: RenderFlex#c5c0d NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child 1: RenderSemanticsAnnotations#5c25d NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderExcludeSemantics#1326e NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child 2: RenderConstrainedBox#e7ad9 NEEDS-LAYOUT NEEDS-PAINT
          child 3: RenderParagraph#8e1f1 NEEDS-LAYOUT NEEDS-PAINT
            text: TextSpan
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during performLayout():
RenderBox was not laid out: RenderDecoratedBox#e8f8d relayoutBoundary=up10 NEEDS-PAINT
NEEDS-COMPOSITING-BITS-UPDATE
'package:flutter/src/rendering/box.dart':
Failed assertion: line 2251 pos 12: 'hasSize'

Either the assertion indicates an error in the framework itself, or we should provide substantially
more information in this error message to help you determine and fix the underlying cause.
In either case, please report this assertion by filing a bug on GitHub:
  https://github.com/flutter/flutter/issues/new?template=02_bug.yml

The relevant error-causing widget was:
  InkWell InkWell:file:///home/runner/work/Ideal/Ideal/lib/ui/widgets/glass_card.dart:103:14

When the exception was thrown, this was the stack:
#2      RenderBox.size (package:flutter/src/rendering/box.dart:2251:12)
#3      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:62)
#4      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#5      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#6      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#7      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#8      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#9      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#10     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#11     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#12     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#13     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#14     RenderCustomPaint.performLayout (package:flutter/src/rendering/custom_paint.dart:574:11)
#15     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#16     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#17     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#18     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#19     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#20     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#21     RenderSliverToBoxAdapter.performLayout (package:flutter/src/rendering/sliver.dart:2098:12)
#22     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#23     RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:821:13)
#24     RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#25     RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#26     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#27     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#28     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#29     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#30     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#31     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#32     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#33     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#34     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#35     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#36     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#37     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#38     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#39     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#40     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#41     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#42     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#43     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#44     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#45     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#46     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#47     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#48     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#49     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#50     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#51     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#52     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#53     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#54     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#55     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#56     _RenderLayoutBuilder.performLayout (package:flutter/src/widgets/layout_builder.dart:449:14)
#57     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#58     MultiChildLayoutDelegate.layoutChild (package:flutter/src/rendering/custom_layout.dart:180:12)
#59     _ScaffoldLayout.performLayout (package:flutter/src/material/scaffold.dart:1113:7)
#60     MultiChildLayoutDelegate._callPerformLayout (package:flutter/src/rendering/custom_layout.dart:246:7)
#61     RenderCustomMultiChildLayoutBox.performLayout (package:flutter/src/rendering/custom_layout.dart:417:14)
#62     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#63     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#64     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#65     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#66     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#67     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#68     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#69     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#70     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#71     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#72     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#73     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#74     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#75     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#76     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#77     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#78     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#79     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#80     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#81     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#82     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#83     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#84     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#85     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#86     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#87     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#88     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#89     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#90     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#91     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#92     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#93     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#94     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#95     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#96     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#97     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#98     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#99     RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#100    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#101    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#102    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#103    _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#104    _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#105    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#106    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#107    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#108    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#109    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#110    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#111    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#112    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#113    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#114    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#115    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#116    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#117    RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#118    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#119    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#120    AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#121    RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#122    SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#123    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#124    AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#127    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#128    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#129    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#132    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#133    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#134    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#135    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:263:22)
<asynchronous suspension>
#136    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#137    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 7 frames from class _AssertionError, dart:async, and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderPointerListener#c8fce relayoutBoundary=up9 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  creator: Listener ← RawGestureDetector ← GestureDetector ← Semantics ← DefaultSelectionStyle ←
    Builder ← MouseRegion ← Semantics ← _FocusInheritedScope ← Focus ← _ActionsScope ← Actions ← ⋯
  parentData: <none> (can use size)
  constraints: BoxConstraints(w=760.0, 0.0<=h<=Infinity)
  size: MISSING
  behavior: opaque
  listeners: down, panZoomStart
This RenderObject had the following descendants (showing up to depth 5):
    child: RenderDecoratedBox#e8f8d relayoutBoundary=up10 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderPadding#1ea85 relayoutBoundary=up11 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderFlex#88dd2 relayoutBoundary=up12 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child 1: RenderPadding#279b9 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderConstrainedBox#7356b NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child 2: RenderFlex#c5c0d NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child 1: RenderSemanticsAnnotations#5c25d NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child 2: RenderConstrainedBox#e7ad9 NEEDS-LAYOUT NEEDS-PAINT
            child 3: RenderParagraph#8e1f1 NEEDS-LAYOUT NEEDS-PAINT
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during performLayout():
RenderBox was not laid out: RenderPointerListener#c8fce relayoutBoundary=up9 NEEDS-PAINT
NEEDS-COMPOSITING-BITS-UPDATE
'package:flutter/src/rendering/box.dart':
Failed assertion: line 2251 pos 12: 'hasSize'

Either the assertion indicates an error in the framework itself, or we should provide substantially
more information in this error message to help you determine and fix the underlying cause.
In either case, please report this assertion by filing a bug on GitHub:
  https://github.com/flutter/flutter/issues/new?template=02_bug.yml

The relevant error-causing widget was:
  InkWell InkWell:file:///home/runner/work/Ideal/Ideal/lib/ui/widgets/glass_card.dart:103:14

When the exception was thrown, this was the stack:
#2      RenderBox.size (package:flutter/src/rendering/box.dart:2251:12)
#3      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:62)
#4      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#5      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#6      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#7      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#8      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#9      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#10     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#11     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#12     RenderCustomPaint.performLayout (package:flutter/src/rendering/custom_paint.dart:574:11)
#13     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#14     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#15     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#16     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#17     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#18     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#19     RenderSliverToBoxAdapter.performLayout (package:flutter/src/rendering/sliver.dart:2098:12)
#20     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#21     RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:821:13)
#22     RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#23     RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#24     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#25     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#26     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#27     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#28     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#29     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#30     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#31     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#32     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#33     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#34     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#35     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#36     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#37     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#38     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#39     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#40     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#41     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#42     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#43     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#44     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#45     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#46     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#47     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#48     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#49     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#50     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#51     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#52     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#53     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#54     _RenderLayoutBuilder.performLayout (package:flutter/src/widgets/layout_builder.dart:449:14)
#55     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#56     MultiChildLayoutDelegate.layoutChild (package:flutter/src/rendering/custom_layout.dart:180:12)
#57     _ScaffoldLayout.performLayout (package:flutter/src/material/scaffold.dart:1113:7)
#58     MultiChildLayoutDelegate._callPerformLayout (package:flutter/src/rendering/custom_layout.dart:246:7)
#59     RenderCustomMultiChildLayoutBox.performLayout (package:flutter/src/rendering/custom_layout.dart:417:14)
#60     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#61     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#62     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#63     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#64     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#65     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#66     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#67     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#68     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#69     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#70     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#71     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#72     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#73     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#74     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#75     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#76     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#77     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#78     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#79     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#80     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#81     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#82     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#83     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#84     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#85     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#86     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#87     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#88     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#89     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#90     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#91     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#92     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#93     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#94     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#95     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#96     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#97     RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#98     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#99     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#100    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#101    _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#102    _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#103    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#104    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#105    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#106    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#107    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#108    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#109    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#110    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#111    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#112    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#113    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#114    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#115    RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#116    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#117    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#118    AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#119    RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#120    SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#121    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#122    AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#125    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#126    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#127    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#130    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#131    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#132    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#133    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:263:22)
<asynchronous suspension>
#134    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#135    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 7 frames from class _AssertionError, dart:async, and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderSemanticsAnnotations#758a5 relayoutBoundary=up8 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  creator: Semantics ← DefaultSelectionStyle ← Builder ← MouseRegion ← Semantics ←
    _FocusInheritedScope ← Focus ← _ActionsScope ← Actions ← _ParentInkResponseProvider ←
    _InkResponseStateWidget ← InkWell ← ⋯
  parentData: <none> (can use size)
  constraints: BoxConstraints(w=760.0, 0.0<=h<=Infinity)
  size: MISSING
This RenderObject had the following descendants (showing up to depth 5):
    child: RenderPointerListener#c8fce relayoutBoundary=up9 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderDecoratedBox#e8f8d relayoutBoundary=up10 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderPadding#1ea85 relayoutBoundary=up11 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderFlex#88dd2 relayoutBoundary=up12 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child 1: RenderPadding#279b9 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child 2: RenderFlex#c5c0d NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during performLayout():
RenderBox was not laid out: RenderSemanticsAnnotations#758a5 relayoutBoundary=up8 NEEDS-PAINT
NEEDS-COMPOSITING-BITS-UPDATE
'package:flutter/src/rendering/box.dart':
Failed assertion: line 2251 pos 12: 'hasSize'

Either the assertion indicates an error in the framework itself, or we should provide substantially
more information in this error message to help you determine and fix the underlying cause.
In either case, please report this assertion by filing a bug on GitHub:
  https://github.com/flutter/flutter/issues/new?template=02_bug.yml

The relevant error-causing widget was:
  InkWell InkWell:file:///home/runner/work/Ideal/Ideal/lib/ui/widgets/glass_card.dart:103:14

When the exception was thrown, this was the stack:
#2      RenderBox.size (package:flutter/src/rendering/box.dart:2251:12)
#3      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:62)
#4      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#5      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#6      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#7      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#8      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#9      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#10     RenderCustomPaint.performLayout (package:flutter/src/rendering/custom_paint.dart:574:11)
#11     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#12     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#13     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#14     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#15     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#16     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#17     RenderSliverToBoxAdapter.performLayout (package:flutter/src/rendering/sliver.dart:2098:12)
#18     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#19     RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:821:13)
#20     RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#21     RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#22     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#23     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#24     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#25     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#26     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#27     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#28     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#29     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#30     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#31     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#32     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#33     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#34     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#35     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#36     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#37     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#38     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#39     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#40     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#41     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#42     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#43     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#44     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#45     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#46     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#47     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#48     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#49     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#50     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#51     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#52     _RenderLayoutBuilder.performLayout (package:flutter/src/widgets/layout_builder.dart:449:14)
#53     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#54     MultiChildLayoutDelegate.layoutChild (package:flutter/src/rendering/custom_layout.dart:180:12)
#55     _ScaffoldLayout.performLayout (package:flutter/src/material/scaffold.dart:1113:7)
#56     MultiChildLayoutDelegate._callPerformLayout (package:flutter/src/rendering/custom_layout.dart:246:7)
#57     RenderCustomMultiChildLayoutBox.performLayout (package:flutter/src/rendering/custom_layout.dart:417:14)
#58     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#59     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#60     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#61     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#62     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#63     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#64     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#65     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#66     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#67     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#68     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#69     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#70     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#71     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#72     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#73     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#74     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#75     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#76     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#77     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#78     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#79     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#80     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#81     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#82     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#83     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#84     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#85     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#86     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#87     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#88     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#89     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#90     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#91     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#92     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#93     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#94     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#95     RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#96     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#97     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#98     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#99     _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#100    _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#101    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#102    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#103    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#104    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#105    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#106    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#107    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#108    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#109    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#110    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#111    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#112    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#113    RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#114    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#115    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#116    AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#117    RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#118    SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#119    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#120    AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#123    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#124    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#125    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#128    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#129    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#130    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#131    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:263:22)
<asynchronous suspension>
#132    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#133    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 7 frames from class _AssertionError, dart:async, and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderMouseRegion#6205f relayoutBoundary=up7 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  creator: MouseRegion ← Semantics ← _FocusInheritedScope ← Focus ← _ActionsScope ← Actions ←
    _ParentInkResponseProvider ← _InkResponseStateWidget ← InkWell ← DefaultTextStyle ←
    AnimatedDefaultTextStyle ← _InkFeatures-[GlobalKey#a8a21 ink renderer] ← ⋯
  parentData: <none> (can use size)
  constraints: BoxConstraints(w=760.0, 0.0<=h<=Infinity)
  size: MISSING
  behavior: opaque
  listeners: enter, exit
  cursor: SystemMouseCursor(basic)
This RenderObject had the following descendants (showing up to depth 5):
    child: RenderSemanticsAnnotations#758a5 relayoutBoundary=up8 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderPointerListener#c8fce relayoutBoundary=up9 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderDecoratedBox#e8f8d relayoutBoundary=up10 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderPadding#1ea85 relayoutBoundary=up11 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderFlex#88dd2 relayoutBoundary=up12 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during performLayout():
RenderBox was not laid out: RenderMouseRegion#6205f relayoutBoundary=up7 NEEDS-PAINT
NEEDS-COMPOSITING-BITS-UPDATE
'package:flutter/src/rendering/box.dart':
Failed assertion: line 2251 pos 12: 'hasSize'

Either the assertion indicates an error in the framework itself, or we should provide substantially
more information in this error message to help you determine and fix the underlying cause.
In either case, please report this assertion by filing a bug on GitHub:
  https://github.com/flutter/flutter/issues/new?template=02_bug.yml

The relevant error-causing widget was:
  InkWell InkWell:file:///home/runner/work/Ideal/Ideal/lib/ui/widgets/glass_card.dart:103:14

When the exception was thrown, this was the stack:
#2      RenderBox.size (package:flutter/src/rendering/box.dart:2251:12)
#3      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:62)
#4      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#5      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#6      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#7      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#8      RenderCustomPaint.performLayout (package:flutter/src/rendering/custom_paint.dart:574:11)
#9      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#10     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#11     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#12     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#13     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#14     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#15     RenderSliverToBoxAdapter.performLayout (package:flutter/src/rendering/sliver.dart:2098:12)
#16     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#17     RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:821:13)
#18     RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#19     RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#20     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#21     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#22     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#23     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#24     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#25     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#26     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#27     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#28     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#29     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#30     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#31     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#32     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#33     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#34     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#35     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#36     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#37     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#38     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#39     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#40     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#41     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#42     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#43     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#44     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#45     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#46     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#47     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#48     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#49     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#50     _RenderLayoutBuilder.performLayout (package:flutter/src/widgets/layout_builder.dart:449:14)
#51     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#52     MultiChildLayoutDelegate.layoutChild (package:flutter/src/rendering/custom_layout.dart:180:12)
#53     _ScaffoldLayout.performLayout (package:flutter/src/material/scaffold.dart:1113:7)
#54     MultiChildLayoutDelegate._callPerformLayout (package:flutter/src/rendering/custom_layout.dart:246:7)
#55     RenderCustomMultiChildLayoutBox.performLayout (package:flutter/src/rendering/custom_layout.dart:417:14)
#56     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#57     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#58     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#59     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#60     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#61     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#62     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#63     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#64     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#65     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#66     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#67     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#68     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#69     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#70     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#71     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#72     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#73     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#74     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#75     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#76     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#77     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#78     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#79     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#80     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#81     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#82     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#83     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#84     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#85     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#86     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#87     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#88     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#89     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#90     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#91     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#92     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#93     RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#94     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#95     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#96     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#97     _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#98     _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#99     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#100    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#101    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#102    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#103    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#104    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#105    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#106    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#107    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#108    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#109    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#110    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#111    RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#112    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#113    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#114    AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#115    RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#116    SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#117    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#118    AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#121    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#122    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#123    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#126    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#127    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#128    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#129    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:263:22)
<asynchronous suspension>
#130    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#131    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 7 frames from class _AssertionError, dart:async, and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderSemanticsAnnotations#8202f relayoutBoundary=up6 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  creator: Semantics ← _FocusInheritedScope ← Focus ← _ActionsScope ← Actions ←
    _ParentInkResponseProvider ← _InkResponseStateWidget ← InkWell ← DefaultTextStyle ←
    AnimatedDefaultTextStyle ← _InkFeatures-[GlobalKey#a8a21 ink renderer] ←
    NotificationListener<LayoutChangedNotification> ← ⋯
  parentData: <none> (can use size)
  constraints: BoxConstraints(w=760.0, 0.0<=h<=Infinity)
  size: MISSING
This RenderObject had the following descendants (showing up to depth 5):
    child: RenderMouseRegion#6205f relayoutBoundary=up7 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderSemanticsAnnotations#758a5 relayoutBoundary=up8 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderPointerListener#c8fce relayoutBoundary=up9 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderDecoratedBox#e8f8d relayoutBoundary=up10 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderPadding#1ea85 relayoutBoundary=up11 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during performLayout():
RenderBox was not laid out: RenderSemanticsAnnotations#8202f relayoutBoundary=up6 NEEDS-PAINT
NEEDS-COMPOSITING-BITS-UPDATE
'package:flutter/src/rendering/box.dart':
Failed assertion: line 2251 pos 12: 'hasSize'

Either the assertion indicates an error in the framework itself, or we should provide substantially
more information in this error message to help you determine and fix the underlying cause.
In either case, please report this assertion by filing a bug on GitHub:
  https://github.com/flutter/flutter/issues/new?template=02_bug.yml

The relevant error-causing widget was:
  Material Material:file:///home/runner/work/Ideal/Ideal/lib/ui/widgets/glass_card.dart:100:12

When the exception was thrown, this was the stack:
#2      RenderBox.size (package:flutter/src/rendering/box.dart:2251:12)
#3      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:62)
#4      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#5      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#6      RenderCustomPaint.performLayout (package:flutter/src/rendering/custom_paint.dart:574:11)
#7      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#8      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#9      _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#10     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#11     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#12     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#13     RenderSliverToBoxAdapter.performLayout (package:flutter/src/rendering/sliver.dart:2098:12)
#14     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#15     RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:821:13)
#16     RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#17     RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#18     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#19     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#20     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#21     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#22     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#23     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#24     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#25     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#26     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#27     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#28     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#29     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#30     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#31     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#32     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#33     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#34     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#35     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#36     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#37     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#38     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#39     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#40     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#41     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#42     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#43     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#44     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#45     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#46     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#47     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#48     _RenderLayoutBuilder.performLayout (package:flutter/src/widgets/layout_builder.dart:449:14)
#49     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#50     MultiChildLayoutDelegate.layoutChild (package:flutter/src/rendering/custom_layout.dart:180:12)
#51     _ScaffoldLayout.performLayout (package:flutter/src/material/scaffold.dart:1113:7)
#52     MultiChildLayoutDelegate._callPerformLayout (package:flutter/src/rendering/custom_layout.dart:246:7)
#53     RenderCustomMultiChildLayoutBox.performLayout (package:flutter/src/rendering/custom_layout.dart:417:14)
#54     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#55     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#56     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#57     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#58     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#59     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#60     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#61     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#62     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#63     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#64     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#65     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#66     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#67     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#68     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#69     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#70     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#71     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#72     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#73     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#74     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#75     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#76     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#77     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#78     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#79     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#80     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#81     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#82     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#83     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#84     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#85     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#86     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#87     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#88     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#89     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#90     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#91     RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#92     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#93     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#94     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#95     _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#96     _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#97     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#98     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#99     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#100    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#101    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#102    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#103    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#104    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#105    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#106    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#107    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#108    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#109    RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#110    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#111    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#112    AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#113    RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#114    SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#115    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#116    AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#119    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#120    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#121    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#124    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#125    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#126    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#127    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:263:22)
<asynchronous suspension>
#128    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#129    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 7 frames from class _AssertionError, dart:async, and package:stack_trace)

The following RenderObject was being processed when the exception was fired: _RenderInkFeatures#39050 relayoutBoundary=up5 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  creator: _InkFeatures-[GlobalKey#a8a21 ink renderer] ←
    NotificationListener<LayoutChangedNotification> ← CustomPaint ← _ShapeBorderPaint ← PhysicalShape
    ← _MaterialInterior ← Material ← SurfaceCard ← _ReliabilityNotice ← Padding ← SliverToBoxAdapter ←
    Viewport ← ⋯
  parentData: <none> (can use size)
  constraints: BoxConstraints(w=760.0, 0.0<=h<=Infinity)
  size: MISSING
This RenderObject had the following descendants (showing up to depth 5):
    child: RenderSemanticsAnnotations#8202f relayoutBoundary=up6 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderMouseRegion#6205f relayoutBoundary=up7 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderSemanticsAnnotations#758a5 relayoutBoundary=up8 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderPointerListener#c8fce relayoutBoundary=up9 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderDecoratedBox#e8f8d relayoutBoundary=up10 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during performLayout():
RenderBox was not laid out: _RenderInkFeatures#39050 relayoutBoundary=up5 NEEDS-PAINT
NEEDS-COMPOSITING-BITS-UPDATE
'package:flutter/src/rendering/box.dart':
Failed assertion: line 2251 pos 12: 'hasSize'

Either the assertion indicates an error in the framework itself, or we should provide substantially
more information in this error message to help you determine and fix the underlying cause.
In either case, please report this assertion by filing a bug on GitHub:
  https://github.com/flutter/flutter/issues/new?template=02_bug.yml

The relevant error-causing widget was:
  Material Material:file:///home/runner/work/Ideal/Ideal/lib/ui/widgets/glass_card.dart:100:12

When the exception was thrown, this was the stack:
#2      RenderBox.size (package:flutter/src/rendering/box.dart:2251:12)
#3      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:62)
#4      RenderCustomPaint.performLayout (package:flutter/src/rendering/custom_paint.dart:574:11)
#5      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#6      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#7      _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#8      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#9      RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#10     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#11     RenderSliverToBoxAdapter.performLayout (package:flutter/src/rendering/sliver.dart:2098:12)
#12     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#13     RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:821:13)
#14     RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#15     RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#16     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#17     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#18     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#19     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#20     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#21     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#22     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#23     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#24     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#25     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#26     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#27     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#28     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#29     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#30     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#31     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#32     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#33     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#34     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#35     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#36     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#37     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#38     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#39     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#40     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#41     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#42     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#43     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#44     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#45     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#46     _RenderLayoutBuilder.performLayout (package:flutter/src/widgets/layout_builder.dart:449:14)
#47     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#48     MultiChildLayoutDelegate.layoutChild (package:flutter/src/rendering/custom_layout.dart:180:12)
#49     _ScaffoldLayout.performLayout (package:flutter/src/material/scaffold.dart:1113:7)
#50     MultiChildLayoutDelegate._callPerformLayout (package:flutter/src/rendering/custom_layout.dart:246:7)
#51     RenderCustomMultiChildLayoutBox.performLayout (package:flutter/src/rendering/custom_layout.dart:417:14)
#52     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#53     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#54     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#55     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#56     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#57     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#58     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#59     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#60     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#61     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#62     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#63     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#64     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#65     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#66     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#67     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#68     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#69     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#70     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#71     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#72     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#73     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#74     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#75     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#76     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#77     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#78     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#79     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#80     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#81     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#82     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#83     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#84     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#85     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#86     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#87     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#88     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#89     RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#90     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#91     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#92     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#93     _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#94     _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#95     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#96     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#97     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#98     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#99     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#100    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#101    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#102    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#103    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#104    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#105    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#106    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#107    RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#108    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#109    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#110    AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#111    RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#112    SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#113    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#114    AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#117    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#118    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#119    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#122    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#123    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#124    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#125    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:263:22)
<asynchronous suspension>
#126    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#127    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 7 frames from class _AssertionError, dart:async, and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderCustomPaint#f492c relayoutBoundary=up4 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  creator: CustomPaint ← _ShapeBorderPaint ← PhysicalShape ← _MaterialInterior ← Material ←
    SurfaceCard ← _ReliabilityNotice ← Padding ← SliverToBoxAdapter ← Viewport ←
    IgnorePointer-[GlobalKey#bb7ed] ← Semantics ← ⋯
  parentData: <none> (can use size)
  constraints: BoxConstraints(w=760.0, 0.0<=h<=Infinity)
  size: MISSING
  painter: null
  foregroundPainter: _ShapeBorderPainter#bc4f4()
This RenderObject had the following descendants (showing up to depth 5):
    child: _RenderInkFeatures#39050 relayoutBoundary=up5 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderSemanticsAnnotations#8202f relayoutBoundary=up6 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderMouseRegion#6205f relayoutBoundary=up7 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderSemanticsAnnotations#758a5 relayoutBoundary=up8 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderPointerListener#c8fce relayoutBoundary=up9 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during performLayout():
RenderBox was not laid out: RenderCustomPaint#f492c relayoutBoundary=up4 NEEDS-PAINT
NEEDS-COMPOSITING-BITS-UPDATE
'package:flutter/src/rendering/box.dart':
Failed assertion: line 2251 pos 12: 'hasSize'

Either the assertion indicates an error in the framework itself, or we should provide substantially
more information in this error message to help you determine and fix the underlying cause.
In either case, please report this assertion by filing a bug on GitHub:
  https://github.com/flutter/flutter/issues/new?template=02_bug.yml

The relevant error-causing widget was:
  Material Material:file:///home/runner/work/Ideal/Ideal/lib/ui/widgets/glass_card.dart:100:12

When the exception was thrown, this was the stack:
#2      RenderBox.size (package:flutter/src/rendering/box.dart:2251:12)
#3      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:62)
#4      _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#5      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#6      RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#7      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#8      RenderSliverToBoxAdapter.performLayout (package:flutter/src/rendering/sliver.dart:2098:12)
#9      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#10     RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:821:13)
#11     RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#12     RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#13     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#14     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#15     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#16     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#17     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#18     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#19     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#20     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#21     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#22     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#23     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#24     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#25     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#26     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#27     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#28     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#29     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#30     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#31     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#32     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#33     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#34     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#35     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#36     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#37     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#38     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#39     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#40     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#41     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#42     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#43     _RenderLayoutBuilder.performLayout (package:flutter/src/widgets/layout_builder.dart:449:14)
#44     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#45     MultiChildLayoutDelegate.layoutChild (package:flutter/src/rendering/custom_layout.dart:180:12)
#46     _ScaffoldLayout.performLayout (package:flutter/src/material/scaffold.dart:1113:7)
#47     MultiChildLayoutDelegate._callPerformLayout (package:flutter/src/rendering/custom_layout.dart:246:7)
#48     RenderCustomMultiChildLayoutBox.performLayout (package:flutter/src/rendering/custom_layout.dart:417:14)
#49     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#50     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#51     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#52     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#53     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#54     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#55     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#56     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#57     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#58     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#59     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#60     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#61     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#62     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#63     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#64     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#65     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#66     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#67     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#68     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#69     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#70     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#71     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#72     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#73     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#74     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#75     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#76     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#77     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#78     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#79     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#80     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#81     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#82     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#83     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#84     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#85     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#86     RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#87     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#88     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#89     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#90     _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#91     _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#92     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#93     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#94     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#95     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#96     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#97     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#98     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#99     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#100    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#101    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#102    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#103    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#104    RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#105    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#106    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#107    AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#108    RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#109    SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#110    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#111    AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#114    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#115    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#116    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#119    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#120    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#121    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#122    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:263:22)
<asynchronous suspension>
#123    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#124    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 7 frames from class _AssertionError, dart:async, and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderPhysicalShape#1ecd6 relayoutBoundary=up3 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  creator: PhysicalShape ← _MaterialInterior ← Material ← SurfaceCard ← _ReliabilityNotice ← Padding ←
    SliverToBoxAdapter ← Viewport ← IgnorePointer-[GlobalKey#bb7ed] ← Semantics ← Listener ←
    _GestureSemantics ← ⋯
  parentData: offset=Offset(0.0, 0.0) (can use size)
  constraints: BoxConstraints(w=760.0, 0.0<=h<=Infinity)
  size: MISSING
  elevation: 0.0
  color: Color(alpha: 0.6500, red: 0.0667, green: 0.0941, blue: 0.2039, colorSpace: ColorSpace.sRGB)
  shadowColor: Color(alpha: 0.6500, red: 0.0667, green: 0.0941, blue: 0.2039, colorSpace:
    ColorSpace.sRGB)
  clipper: ShapeBorderClipper
This RenderObject had the following descendants (showing up to depth 5):
    child: RenderCustomPaint#f492c relayoutBoundary=up4 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: _RenderInkFeatures#39050 relayoutBoundary=up5 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderSemanticsAnnotations#8202f relayoutBoundary=up6 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderMouseRegion#6205f relayoutBoundary=up7 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderSemanticsAnnotations#758a5 relayoutBoundary=up8 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during performLayout():
RenderBox was not laid out: RenderPhysicalShape#1ecd6 relayoutBoundary=up3 NEEDS-PAINT
NEEDS-COMPOSITING-BITS-UPDATE
'package:flutter/src/rendering/box.dart':
Failed assertion: line 2251 pos 12: 'hasSize'

Either the assertion indicates an error in the framework itself, or we should provide substantially
more information in this error message to help you determine and fix the underlying cause.
In either case, please report this assertion by filing a bug on GitHub:
  https://github.com/flutter/flutter/issues/new?template=02_bug.yml

The relevant error-causing widget was:
  Padding Padding:file:///home/runner/work/Ideal/Ideal/lib/features/jobs/jobs_screen.dart:101:20

When the exception was thrown, this was the stack:
#2      RenderBox.size (package:flutter/src/rendering/box.dart:2251:12)
#3      RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:266:40)
#4      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#5      RenderSliverToBoxAdapter.performLayout (package:flutter/src/rendering/sliver.dart:2098:12)
#6      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#7      RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:821:13)
#8      RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#9      RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#10     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#11     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#12     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#13     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#14     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#15     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#16     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#17     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#18     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#19     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#20     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#21     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#22     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#23     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#24     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#25     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#26     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#27     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#28     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#29     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#30     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#31     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#32     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#33     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#34     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#35     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#36     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#37     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#38     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#39     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#40     _RenderLayoutBuilder.performLayout (package:flutter/src/widgets/layout_builder.dart:449:14)
#41     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#42     MultiChildLayoutDelegate.layoutChild (package:flutter/src/rendering/custom_layout.dart:180:12)
#43     _ScaffoldLayout.performLayout (package:flutter/src/material/scaffold.dart:1113:7)
#44     MultiChildLayoutDelegate._callPerformLayout (package:flutter/src/rendering/custom_layout.dart:246:7)
#45     RenderCustomMultiChildLayoutBox.performLayout (package:flutter/src/rendering/custom_layout.dart:417:14)
#46     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#47     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#48     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#49     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#50     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#51     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#52     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#53     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#54     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#55     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#56     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#57     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#58     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#59     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#60     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#61     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#62     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#63     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#64     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#65     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#66     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#67     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#68     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#69     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#70     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#71     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#72     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#73     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#74     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#75     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#76     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#77     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#78     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#79     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#80     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#81     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#82     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#83     RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#84     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#85     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#86     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#87     _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#88     _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#89     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#90     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#91     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#92     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#93     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#94     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#95     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#96     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#97     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#98     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#99     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#100    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#101    RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#102    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#103    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#104    AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#105    RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#106    SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#107    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#108    AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#111    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#112    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#113    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#116    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#117    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#118    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#119    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:263:22)
<asynchronous suspension>
#120    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#121    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 7 frames from class _AssertionError, dart:async, and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderPadding#7b0e2 relayoutBoundary=up2 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  creator: Padding ← SliverToBoxAdapter ← Viewport ← IgnorePointer-[GlobalKey#bb7ed] ← Semantics ←
    Listener ← _GestureSemantics ←
    RawGestureDetector-[LabeledGlobalKey<RawGestureDetectorState>#793fb] ← Listener ← _ScrollableScope
    ← _ScrollSemantics-[GlobalKey#8a040] ← NotificationListener<ScrollMetricsNotification> ← ⋯
  parentData: paintOffset=Offset(0.0, 0.0) (can use size)
  constraints: BoxConstraints(w=800.0, 0.0<=h<=Infinity)
  size: MISSING
  padding: EdgeInsets(20.0, 16.0, 20.0, 0.0)
  textDirection: rtl
This RenderObject had the following descendants (showing up to depth 5):
    child: RenderPhysicalShape#1ecd6 relayoutBoundary=up3 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderCustomPaint#f492c relayoutBoundary=up4 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: _RenderInkFeatures#39050 relayoutBoundary=up5 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderSemanticsAnnotations#8202f relayoutBoundary=up6 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderMouseRegion#6205f relayoutBoundary=up7 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during performLayout():
RenderBox was not laid out: RenderPadding#7b0e2 relayoutBoundary=up2 NEEDS-PAINT
NEEDS-COMPOSITING-BITS-UPDATE
'package:flutter/src/rendering/box.dart':
Failed assertion: line 2251 pos 12: 'hasSize'

Either the assertion indicates an error in the framework itself, or we should provide substantially
more information in this error message to help you determine and fix the underlying cause.
In either case, please report this assertion by filing a bug on GitHub:
  https://github.com/flutter/flutter/issues/new?template=02_bug.yml

The relevant error-causing widget was:
  SliverToBoxAdapter
  SliverToBoxAdapter:file:///home/runner/work/Ideal/Ideal/lib/features/jobs/jobs_screen.dart:100:11

When the exception was thrown, this was the stack:
#2      RenderBox.size (package:flutter/src/rendering/box.dart:2251:12)
#3      RenderSliverToBoxAdapter.performLayout (package:flutter/src/rendering/sliver.dart:2101:31)
#4      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#5      RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:821:13)
#6      RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#7      RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#8      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#9      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#10     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#11     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#12     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#13     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#14     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#15     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#16     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#17     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#18     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#19     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#20     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#21     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#22     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#23     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#24     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#25     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#26     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#27     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#28     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#29     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#30     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#31     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#32     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#33     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#34     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#35     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#36     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#37     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#38     _RenderLayoutBuilder.performLayout (package:flutter/src/widgets/layout_builder.dart:449:14)
#39     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#40     MultiChildLayoutDelegate.layoutChild (package:flutter/src/rendering/custom_layout.dart:180:12)
#41     _ScaffoldLayout.performLayout (package:flutter/src/material/scaffold.dart:1113:7)
#42     MultiChildLayoutDelegate._callPerformLayout (package:flutter/src/rendering/custom_layout.dart:246:7)
#43     RenderCustomMultiChildLayoutBox.performLayout (package:flutter/src/rendering/custom_layout.dart:417:14)
#44     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#45     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#46     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#47     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#48     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#49     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#50     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#51     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#52     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#53     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#54     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#55     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#56     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#57     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#58     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#59     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#60     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#61     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#62     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#63     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#64     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#65     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#66     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#67     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#68     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#69     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#70     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#71     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#72     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#73     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#74     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#75     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#76     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#77     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#78     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#79     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#80     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#81     RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#82     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#83     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#84     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#85     _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#86     _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#87     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#88     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#89     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#90     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#91     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#92     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#93     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#94     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#95     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#96     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#97     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#98     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#99     RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#100    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#101    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#102    AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#103    RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#104    SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#105    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#106    AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#109    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#110    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#111    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#114    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#115    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#116    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#117    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:263:22)
<asynchronous suspension>
#118    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#119    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 7 frames from class _AssertionError, dart:async, and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderSliverToBoxAdapter#38194 relayoutBoundary=up1 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  creator: SliverToBoxAdapter ← Viewport ← IgnorePointer-[GlobalKey#bb7ed] ← Semantics ← Listener ←
    _GestureSemantics ← RawGestureDetector-[LabeledGlobalKey<RawGestureDetectorState>#793fb] ←
    Listener ← _ScrollableScope ← _ScrollSemantics-[GlobalKey#8a040] ←
    NotificationListener<ScrollMetricsNotification> ← Transform ← ⋯
  parentData: paintOffset=Offset(0.0, 0.0) (can use size)
  constraints: SliverConstraints(AxisDirection.down, GrowthDirection.forward, ScrollDirection.idle,
    scrollOffset: 0.0, precedingScrollExtent: 82.0, remainingPaintExtent: 518.0, crossAxisExtent:
    800.0, crossAxisDirection: AxisDirection.left, viewportMainAxisExtent: 600.0,
    remainingCacheExtent: 768.0, cacheOrigin: 0.0)
  geometry: null
This RenderObject had the following descendants (showing up to depth 5):
    child: RenderPadding#7b0e2 relayoutBoundary=up2 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderPhysicalShape#1ecd6 relayoutBoundary=up3 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderCustomPaint#f492c relayoutBoundary=up4 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: _RenderInkFeatures#39050 relayoutBoundary=up5 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderSemanticsAnnotations#8202f relayoutBoundary=up6 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following _TypeError was thrown during performLayout():
Null check operator used on a null value

The relevant error-causing widget was:
  CustomScrollView
  CustomScrollView:file:///home/runner/work/Ideal/Ideal/lib/features/jobs/jobs_screen.dart:67:14

When the exception was thrown, this was the stack:
#0      RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:842:64)
#1      RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#2      RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#3      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#4      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#5      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#6      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#7      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#8      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#9      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#10     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#11     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#12     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#13     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#14     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#15     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#16     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#17     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#18     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#19     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#20     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#21     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#22     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#23     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#24     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#25     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#26     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#27     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#28     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#29     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#30     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#31     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#32     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#33     _RenderLayoutBuilder.performLayout (package:flutter/src/widgets/layout_builder.dart:449:14)
#34     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#35     MultiChildLayoutDelegate.layoutChild (package:flutter/src/rendering/custom_layout.dart:180:12)
#36     _ScaffoldLayout.performLayout (package:flutter/src/material/scaffold.dart:1113:7)
#37     MultiChildLayoutDelegate._callPerformLayout (package:flutter/src/rendering/custom_layout.dart:246:7)
#38     RenderCustomMultiChildLayoutBox.performLayout (package:flutter/src/rendering/custom_layout.dart:417:14)
#39     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#40     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#41     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#42     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#43     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#44     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#45     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#46     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#47     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#48     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#49     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#50     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#51     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#52     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#53     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#54     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#55     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#56     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#57     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#58     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#59     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#60     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#61     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#62     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#63     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#64     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#65     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#66     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#67     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#68     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#69     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#70     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#71     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#72     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#73     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#74     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#75     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#76     RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#77     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#78     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#79     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#80     _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#81     _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#82     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#83     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#84     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#85     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#86     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#87     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#88     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#89     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#90     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#91     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#92     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#93     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#94     RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#95     PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#96     PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#97     AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#98     RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#99     SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#100    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#101    AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#104    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#105    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#106    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#109    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#110    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#111    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#112    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:263:22)
<asynchronous suspension>
#113    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#114    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 5 frames from dart:async and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderViewport#9fdd5 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  needs compositing
  creator: Viewport ← IgnorePointer-[GlobalKey#bb7ed] ← Semantics ← Listener ← _GestureSemantics ←
    RawGestureDetector-[LabeledGlobalKey<RawGestureDetectorState>#793fb] ← Listener ← _ScrollableScope
    ← _ScrollSemantics-[GlobalKey#8a040] ← NotificationListener<ScrollMetricsNotification> ← Transform
    ← StretchEffect ← ⋯
  parentData: <none> (can use size)
  constraints: BoxConstraints(0.0<=w<=800.0, 0.0<=h<=600.0)
  size: Size(800.0, 600.0)
  axisDirection: down
  crossAxisDirection: left
  offset: ScrollPositionWithSingleContext#d4eaa(offset: 0.0, range: null..null, viewport: 600.0,
    ScrollableState, AlwaysScrollableScrollPhysics -> ClampingScrollPhysics ->
    RangeMaintainingScrollPhysics, IdleScrollActivity#7da52, ScrollDirection.idle)
  anchor: 0.0
This RenderObject had the following descendants (showing up to depth 5):
    center child: RenderSliverToBoxAdapter#caa4b relayoutBoundary=up1 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderPadding#f4e61 relayoutBoundary=up2 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderFlex#6e8c7 relayoutBoundary=up3 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child 1: RenderFlex#c235c relayoutBoundary=up4 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child 1: RenderParagraph#81d82 relayoutBoundary=up5 NEEDS-PAINT
            child 2: RenderConstrainedBox#b7fdb relayoutBoundary=up5 NEEDS-PAINT
            child 3: RenderParagraph#b4b02 relayoutBoundary=up5 NEEDS-PAINT
          child 2: RenderSemanticsAnnotations#79c60 relayoutBoundary=up4 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: _RenderInputPadding#3e4d6 relayoutBoundary=up5 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
    child 1: RenderSliverToBoxAdapter#38194 relayoutBoundary=up1 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderPadding#7b0e2 relayoutBoundary=up2 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderPhysicalShape#1ecd6 relayoutBoundary=up3 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderCustomPaint#f492c relayoutBoundary=up4 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: _RenderInkFeatures#39050 relayoutBoundary=up5 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
    child 2: RenderSliverFillRemainingWithScrollable#7e207 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderPositionedBox#b2110 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderSemanticsAnnotations#e57a0 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderConstrainedBox#87632 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderCustomPaint#0fc7d NEEDS-LAYOUT NEEDS-PAINT
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during performLayout():
BoxConstraints forces an infinite height.
These invalid constraints were provided to RenderPadding's layout() function by the following
function, which probably computed the invalid constraints in question:
  ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
The offending constraints were:
  BoxConstraints(0.0<=w<=Infinity, h=Infinity)

The relevant error-causing widget was:
  Row Row:file:///home/runner/work/Ideal/Ideal/lib/ui/widgets/glass_card.dart:118:17

When the exception was thrown, this was the stack:
#0      BoxConstraints.debugAssertIsValid.<anonymous closure>.throwError (package:flutter/src/rendering/box.dart:549:9)
#1      BoxConstraints.debugAssertIsValid.<anonymous closure> (package:flutter/src/rendering/box.dart:614:11)
#2      BoxConstraints.debugAssertIsValid (package:flutter/src/rendering/box.dart:619:6)
#3      RenderObject.layout (package:flutter/src/rendering/object.dart:2823:19)
#4      ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#5      RenderFlex._computeSizes (package:flutter/src/rendering/flex.dart:1237:28)
#6      RenderFlex.performLayout (package:flutter/src/rendering/flex.dart:1329:32)
#7      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#8      RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#9      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#10     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#11     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#12     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#13     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#14     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#15     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#16     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#17     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#18     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#19     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#20     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#21     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#22     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#23     RenderCustomPaint.performLayout (package:flutter/src/rendering/custom_paint.dart:574:11)
#24     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#25     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#26     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#27     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#28     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#29     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#30     RenderSliverToBoxAdapter.performLayout (package:flutter/src/rendering/sliver.dart:2098:12)
#31     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#32     RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:821:13)
#33     RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#34     RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#35     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#36     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#37     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#38     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#39     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#40     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#41     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#42     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#43     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#44     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#45     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#46     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#47     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#48     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#49     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#50     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#51     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#52     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#53     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#54     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#55     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#56     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#57     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#58     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#59     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#60     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#61     _RenderLayoutBuilder.performLayout (package:flutter/src/widgets/layout_builder.dart:449:14)
#62     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#63     MultiChildLayoutDelegate.layoutChild (package:flutter/src/rendering/custom_layout.dart:180:12)
#64     _ScaffoldLayout.performLayout (package:flutter/src/material/scaffold.dart:1113:7)
#65     MultiChildLayoutDelegate._callPerformLayout (package:flutter/src/rendering/custom_layout.dart:246:7)
#66     RenderCustomMultiChildLayoutBox.performLayout (package:flutter/src/rendering/custom_layout.dart:417:14)
#67     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#68     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#69     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#70     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#71     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#72     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#73     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#74     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#75     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#76     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#77     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#78     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#79     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#80     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#81     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#82     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#83     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#84     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#85     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#86     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#87     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#88     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#89     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#90     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#91     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#92     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#93     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#94     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#95     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#96     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#97     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#98     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#99     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#100    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#101    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#102    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#103    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#104    RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#105    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#106    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#107    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#108    _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#109    _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#110    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#111    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#112    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#113    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#114    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#115    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#116    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#117    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#118    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#119    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#120    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#121    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#122    RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#123    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#124    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#125    AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#126    RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#127    SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#128    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#129    AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#132    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#133    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#134    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#137    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#138    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#139    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#140    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:263:22)
<asynchronous suspension>
#141    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#142    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 5 frames from dart:async and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderFlex#2ac7d relayoutBoundary=up12 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  creator: Row ← Padding ← DecoratedBox ← Container ← Listener ← RawGestureDetector ← GestureDetector
    ← Semantics ← DefaultSelectionStyle ← Builder ← MouseRegion ← Semantics ← ⋯
  parentData: offset=Offset(0.0, 0.0) (can use size)
  constraints: BoxConstraints(w=730.0, 0.0<=h<=Infinity)
  size: MISSING
  direction: horizontal
  mainAxisAlignment: start
  mainAxisSize: max
  crossAxisAlignment: stretch
  textDirection: rtl
  verticalDirection: down
  spacing: 0.0
This RenderObject had the following descendants (showing up to depth 5):
    child 1: RenderPadding#47df6 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderConstrainedBox#03bc2 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderDecoratedBox#b92cd NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderPadding#86889 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderLimitedBox#6b6e7 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
    child 2: RenderFlex#3e40a NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child 1: RenderSemanticsAnnotations#d38e1 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderExcludeSemantics#4fbea NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderConstrainedBox#bdb38 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderPositionedBox#ce705 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child 2: RenderConstrainedBox#a70cb NEEDS-LAYOUT NEEDS-PAINT
      child 3: RenderParagraph#54fed NEEDS-LAYOUT NEEDS-PAINT
        text: TextSpan
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during performLayout():
RenderBox was not laid out: RenderFlex#2ac7d relayoutBoundary=up12 NEEDS-PAINT
NEEDS-COMPOSITING-BITS-UPDATE
'package:flutter/src/rendering/box.dart':
Failed assertion: line 2251 pos 12: 'hasSize'

Either the assertion indicates an error in the framework itself, or we should provide substantially
more information in this error message to help you determine and fix the underlying cause.
In either case, please report this assertion by filing a bug on GitHub:
  https://github.com/flutter/flutter/issues/new?template=02_bug.yml

The relevant error-causing widget was:
  Container Container:file:///home/runner/work/Ideal/Ideal/lib/ui/widgets/glass_card.dart:106:16

When the exception was thrown, this was the stack:
#2      RenderBox.size (package:flutter/src/rendering/box.dart:2251:12)
#3      RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:266:40)
#4      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#5      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#6      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#7      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#8      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#9      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#10     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#11     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#12     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#13     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#14     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#15     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#16     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#17     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#18     RenderCustomPaint.performLayout (package:flutter/src/rendering/custom_paint.dart:574:11)
#19     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#20     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#21     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#22     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#23     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#24     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#25     RenderSliverToBoxAdapter.performLayout (package:flutter/src/rendering/sliver.dart:2098:12)
#26     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#27     RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:821:13)
#28     RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#29     RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#30     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#31     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#32     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#33     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#34     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#35     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#36     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#37     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#38     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#39     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#40     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#41     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#42     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#43     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#44     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#45     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#46     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#47     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#48     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#49     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#50     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#51     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#52     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#53     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#54     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#55     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#56     _RenderLayoutBuilder.performLayout (package:flutter/src/widgets/layout_builder.dart:449:14)
#57     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#58     MultiChildLayoutDelegate.layoutChild (package:flutter/src/rendering/custom_layout.dart:180:12)
#59     _ScaffoldLayout.performLayout (package:flutter/src/material/scaffold.dart:1113:7)
#60     MultiChildLayoutDelegate._callPerformLayout (package:flutter/src/rendering/custom_layout.dart:246:7)
#61     RenderCustomMultiChildLayoutBox.performLayout (package:flutter/src/rendering/custom_layout.dart:417:14)
#62     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#63     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#64     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#65     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#66     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#67     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#68     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#69     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#70     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#71     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#72     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#73     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#74     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#75     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#76     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#77     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#78     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#79     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#80     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#81     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#82     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#83     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#84     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#85     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#86     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#87     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#88     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#89     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#90     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#91     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#92     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#93     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#94     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#95     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#96     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#97     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#98     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#99     RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#100    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#101    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#102    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#103    _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#104    _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#105    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#106    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#107    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#108    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#109    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#110    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#111    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#112    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#113    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#114    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#115    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#116    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#117    RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#118    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#119    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#120    AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#121    RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#122    SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#123    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#124    AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#127    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#128    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#129    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#132    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#133    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#134    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#135    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:263:22)
<asynchronous suspension>
#136    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#137    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 7 frames from class _AssertionError, dart:async, and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderPadding#bc453 relayoutBoundary=up11 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  creator: Padding ← DecoratedBox ← Container ← Listener ← RawGestureDetector ← GestureDetector ←
    Semantics ← DefaultSelectionStyle ← Builder ← MouseRegion ← Semantics ← _FocusInheritedScope ← ⋯
  parentData: <none> (can use size)
  constraints: BoxConstraints(w=760.0, 0.0<=h<=Infinity)
  size: MISSING
  padding: EdgeInsets.all(15.0)
  textDirection: rtl
This RenderObject had the following descendants (showing up to depth 5):
    child: RenderFlex#2ac7d relayoutBoundary=up12 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child 1: RenderPadding#47df6 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderConstrainedBox#03bc2 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderDecoratedBox#b92cd NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderPadding#86889 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child 2: RenderFlex#3e40a NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child 1: RenderSemanticsAnnotations#d38e1 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderExcludeSemantics#4fbea NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderConstrainedBox#bdb38 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child 2: RenderConstrainedBox#a70cb NEEDS-LAYOUT NEEDS-PAINT
        child 3: RenderParagraph#54fed NEEDS-LAYOUT NEEDS-PAINT
          text: TextSpan
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during performLayout():
RenderBox was not laid out: RenderPadding#bc453 relayoutBoundary=up11 NEEDS-PAINT
NEEDS-COMPOSITING-BITS-UPDATE
'package:flutter/src/rendering/box.dart':
Failed assertion: line 2251 pos 12: 'hasSize'

Either the assertion indicates an error in the framework itself, or we should provide substantially
more information in this error message to help you determine and fix the underlying cause.
In either case, please report this assertion by filing a bug on GitHub:
  https://github.com/flutter/flutter/issues/new?template=02_bug.yml

The relevant error-causing widget was:
  Container Container:file:///home/runner/work/Ideal/Ideal/lib/ui/widgets/glass_card.dart:106:16

When the exception was thrown, this was the stack:
#2      RenderBox.size (package:flutter/src/rendering/box.dart:2251:12)
#3      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:62)
#4      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#5      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#6      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#7      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#8      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#9      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#10     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#11     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#12     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#13     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#14     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#15     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#16     RenderCustomPaint.performLayout (package:flutter/src/rendering/custom_paint.dart:574:11)
#17     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#18     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#19     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#20     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#21     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#22     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#23     RenderSliverToBoxAdapter.performLayout (package:flutter/src/rendering/sliver.dart:2098:12)
#24     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#25     RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:821:13)
#26     RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#27     RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#28     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#29     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#30     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#31     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#32     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#33     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#34     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#35     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#36     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#37     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#38     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#39     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#40     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#41     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#42     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#43     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#44     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#45     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#46     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#47     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#48     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#49     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#50     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#51     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#52     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#53     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#54     _RenderLayoutBuilder.performLayout (package:flutter/src/widgets/layout_builder.dart:449:14)
#55     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#56     MultiChildLayoutDelegate.layoutChild (package:flutter/src/rendering/custom_layout.dart:180:12)
#57     _ScaffoldLayout.performLayout (package:flutter/src/material/scaffold.dart:1113:7)
#58     MultiChildLayoutDelegate._callPerformLayout (package:flutter/src/rendering/custom_layout.dart:246:7)
#59     RenderCustomMultiChildLayoutBox.performLayout (package:flutter/src/rendering/custom_layout.dart:417:14)
#60     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#61     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#62     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#63     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#64     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#65     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#66     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#67     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#68     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#69     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#70     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#71     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#72     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#73     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#74     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#75     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#76     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#77     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#78     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#79     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#80     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#81     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#82     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#83     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#84     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#85     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#86     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#87     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#88     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#89     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#90     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#91     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#92     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#93     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#94     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#95     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#96     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#97     RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#98     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#99     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#100    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#101    _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#102    _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#103    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#104    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#105    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#106    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#107    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#108    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#109    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#110    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#111    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#112    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#113    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#114    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#115    RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#116    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#117    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#118    AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#119    RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#120    SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#121    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#122    AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#125    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#126    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#127    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#130    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#131    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#132    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#133    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:263:22)
<asynchronous suspension>
#134    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#135    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 7 frames from class _AssertionError, dart:async, and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderDecoratedBox#1bcd5 relayoutBoundary=up10 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  creator: DecoratedBox ← Container ← Listener ← RawGestureDetector ← GestureDetector ← Semantics ←
    DefaultSelectionStyle ← Builder ← MouseRegion ← Semantics ← _FocusInheritedScope ← Focus ← ⋯
  parentData: <none> (can use size)
  constraints: BoxConstraints(w=760.0, 0.0<=h<=Infinity)
  size: MISSING
  decoration: BoxDecoration:
    border: Border.all(BorderSide(color: Color(alpha: 0.0600, red: 1.0000, green: 1.0000, blue: 1.0000,
      colorSpace: ColorSpace.sRGB)))
    borderRadius: BorderRadius.circular(22.0)
  configuration: ImageConfiguration(bundle: PlatformAssetBundle#785c1(), devicePixelRatio: 3.0,
    locale: fa_IR, textDirection: TextDirection.rtl, platform: android)
This RenderObject had the following descendants (showing up to depth 5):
    child: RenderPadding#bc453 relayoutBoundary=up11 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderFlex#2ac7d relayoutBoundary=up12 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child 1: RenderPadding#47df6 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderConstrainedBox#03bc2 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderDecoratedBox#b92cd NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child 2: RenderFlex#3e40a NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child 1: RenderSemanticsAnnotations#d38e1 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderExcludeSemantics#4fbea NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child 2: RenderConstrainedBox#a70cb NEEDS-LAYOUT NEEDS-PAINT
          child 3: RenderParagraph#54fed NEEDS-LAYOUT NEEDS-PAINT
            text: TextSpan
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during performLayout():
RenderBox was not laid out: RenderDecoratedBox#1bcd5 relayoutBoundary=up10 NEEDS-PAINT
NEEDS-COMPOSITING-BITS-UPDATE
'package:flutter/src/rendering/box.dart':
Failed assertion: line 2251 pos 12: 'hasSize'

Either the assertion indicates an error in the framework itself, or we should provide substantially
more information in this error message to help you determine and fix the underlying cause.
In either case, please report this assertion by filing a bug on GitHub:
  https://github.com/flutter/flutter/issues/new?template=02_bug.yml

The relevant error-causing widget was:
  InkWell InkWell:file:///home/runner/work/Ideal/Ideal/lib/ui/widgets/glass_card.dart:103:14

When the exception was thrown, this was the stack:
#2      RenderBox.size (package:flutter/src/rendering/box.dart:2251:12)
#3      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:62)
#4      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#5      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#6      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#7      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#8      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#9      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#10     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#11     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#12     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#13     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#14     RenderCustomPaint.performLayout (package:flutter/src/rendering/custom_paint.dart:574:11)
#15     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#16     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#17     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#18     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#19     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#20     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#21     RenderSliverToBoxAdapter.performLayout (package:flutter/src/rendering/sliver.dart:2098:12)
#22     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#23     RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:821:13)
#24     RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#25     RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#26     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#27     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#28     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#29     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#30     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#31     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#32     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#33     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#34     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#35     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#36     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#37     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#38     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#39     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#40     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#41     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#42     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#43     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#44     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#45     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#46     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#47     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#48     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#49     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#50     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#51     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#52     _RenderLayoutBuilder.performLayout (package:flutter/src/widgets/layout_builder.dart:449:14)
#53     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#54     MultiChildLayoutDelegate.layoutChild (package:flutter/src/rendering/custom_layout.dart:180:12)
#55     _ScaffoldLayout.performLayout (package:flutter/src/material/scaffold.dart:1113:7)
#56     MultiChildLayoutDelegate._callPerformLayout (package:flutter/src/rendering/custom_layout.dart:246:7)
#57     RenderCustomMultiChildLayoutBox.performLayout (package:flutter/src/rendering/custom_layout.dart:417:14)
#58     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#59     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#60     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#61     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#62     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#63     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#64     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#65     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#66     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#67     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#68     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#69     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#70     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#71     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#72     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#73     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#74     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#75     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#76     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#77     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#78     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#79     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#80     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#81     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#82     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#83     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#84     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#85     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#86     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#87     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#88     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#89     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#90     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#91     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#92     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#93     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#94     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#95     RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#96     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#97     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#98     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#99     _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#100    _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#101    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#102    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#103    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#104    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#105    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#106    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#107    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#108    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#109    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#110    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#111    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#112    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#113    RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#114    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#115    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#116    AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#117    RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#118    SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#119    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#120    AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#123    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#124    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#125    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#128    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#129    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#130    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#131    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:263:22)
<asynchronous suspension>
#132    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#133    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 7 frames from class _AssertionError, dart:async, and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderPointerListener#ae027 relayoutBoundary=up9 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  creator: Listener ← RawGestureDetector ← GestureDetector ← Semantics ← DefaultSelectionStyle ←
    Builder ← MouseRegion ← Semantics ← _FocusInheritedScope ← Focus ← _ActionsScope ← Actions ← ⋯
  parentData: <none> (can use size)
  constraints: BoxConstraints(w=760.0, 0.0<=h<=Infinity)
  size: MISSING
  behavior: opaque
  listeners: down, panZoomStart
This RenderObject had the following descendants (showing up to depth 5):
    child: RenderDecoratedBox#1bcd5 relayoutBoundary=up10 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderPadding#bc453 relayoutBoundary=up11 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderFlex#2ac7d relayoutBoundary=up12 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child 1: RenderPadding#47df6 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderConstrainedBox#03bc2 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child 2: RenderFlex#3e40a NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child 1: RenderSemanticsAnnotations#d38e1 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child 2: RenderConstrainedBox#a70cb NEEDS-LAYOUT NEEDS-PAINT
            child 3: RenderParagraph#54fed NEEDS-LAYOUT NEEDS-PAINT
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during performLayout():
RenderBox was not laid out: RenderPointerListener#ae027 relayoutBoundary=up9 NEEDS-PAINT
NEEDS-COMPOSITING-BITS-UPDATE
'package:flutter/src/rendering/box.dart':
Failed assertion: line 2251 pos 12: 'hasSize'

Either the assertion indicates an error in the framework itself, or we should provide substantially
more information in this error message to help you determine and fix the underlying cause.
In either case, please report this assertion by filing a bug on GitHub:
  https://github.com/flutter/flutter/issues/new?template=02_bug.yml

The relevant error-causing widget was:
  InkWell InkWell:file:///home/runner/work/Ideal/Ideal/lib/ui/widgets/glass_card.dart:103:14

When the exception was thrown, this was the stack:
#2      RenderBox.size (package:flutter/src/rendering/box.dart:2251:12)
#3      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:62)
#4      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#5      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#6      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#7      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#8      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#9      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#10     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#11     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#12     RenderCustomPaint.performLayout (package:flutter/src/rendering/custom_paint.dart:574:11)
#13     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#14     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#15     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#16     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#17     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#18     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#19     RenderSliverToBoxAdapter.performLayout (package:flutter/src/rendering/sliver.dart:2098:12)
#20     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#21     RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:821:13)
#22     RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#23     RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#24     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#25     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#26     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#27     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#28     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#29     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#30     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#31     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#32     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#33     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#34     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#35     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#36     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#37     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#38     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#39     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#40     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#41     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#42     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#43     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#44     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#45     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#46     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#47     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#48     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#49     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#50     _RenderLayoutBuilder.performLayout (package:flutter/src/widgets/layout_builder.dart:449:14)
#51     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#52     MultiChildLayoutDelegate.layoutChild (package:flutter/src/rendering/custom_layout.dart:180:12)
#53     _ScaffoldLayout.performLayout (package:flutter/src/material/scaffold.dart:1113:7)
#54     MultiChildLayoutDelegate._callPerformLayout (package:flutter/src/rendering/custom_layout.dart:246:7)
#55     RenderCustomMultiChildLayoutBox.performLayout (package:flutter/src/rendering/custom_layout.dart:417:14)
#56     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#57     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#58     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#59     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#60     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#61     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#62     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#63     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#64     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#65     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#66     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#67     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#68     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#69     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#70     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#71     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#72     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#73     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#74     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#75     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#76     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#77     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#78     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#79     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#80     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#81     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#82     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#83     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#84     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#85     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#86     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#87     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#88     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#89     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#90     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#91     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#92     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#93     RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#94     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#95     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#96     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#97     _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#98     _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#99     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#100    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#101    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#102    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#103    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#104    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#105    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#106    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#107    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#108    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#109    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#110    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#111    RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#112    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#113    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#114    AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#115    RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#116    SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#117    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#118    AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#121    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#122    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#123    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#126    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#127    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#128    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#129    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:263:22)
<asynchronous suspension>
#130    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#131    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 7 frames from class _AssertionError, dart:async, and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderSemanticsAnnotations#3428e relayoutBoundary=up8 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  creator: Semantics ← DefaultSelectionStyle ← Builder ← MouseRegion ← Semantics ←
    _FocusInheritedScope ← Focus ← _ActionsScope ← Actions ← _ParentInkResponseProvider ←
    _InkResponseStateWidget ← InkWell ← ⋯
  parentData: <none> (can use size)
  constraints: BoxConstraints(w=760.0, 0.0<=h<=Infinity)
  size: MISSING
This RenderObject had the following descendants (showing up to depth 5):
    child: RenderPointerListener#ae027 relayoutBoundary=up9 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderDecoratedBox#1bcd5 relayoutBoundary=up10 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderPadding#bc453 relayoutBoundary=up11 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderFlex#2ac7d relayoutBoundary=up12 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child 1: RenderPadding#47df6 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child 2: RenderFlex#3e40a NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during performLayout():
RenderBox was not laid out: RenderSemanticsAnnotations#3428e relayoutBoundary=up8 NEEDS-PAINT
NEEDS-COMPOSITING-BITS-UPDATE
'package:flutter/src/rendering/box.dart':
Failed assertion: line 2251 pos 12: 'hasSize'

Either the assertion indicates an error in the framework itself, or we should provide substantially
more information in this error message to help you determine and fix the underlying cause.
In either case, please report this assertion by filing a bug on GitHub:
  https://github.com/flutter/flutter/issues/new?template=02_bug.yml

The relevant error-causing widget was:
  InkWell InkWell:file:///home/runner/work/Ideal/Ideal/lib/ui/widgets/glass_card.dart:103:14

When the exception was thrown, this was the stack:
#2      RenderBox.size (package:flutter/src/rendering/box.dart:2251:12)
#3      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:62)
#4      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#5      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#6      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#7      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#8      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#9      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#10     RenderCustomPaint.performLayout (package:flutter/src/rendering/custom_paint.dart:574:11)
#11     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#12     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#13     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#14     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#15     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#16     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#17     RenderSliverToBoxAdapter.performLayout (package:flutter/src/rendering/sliver.dart:2098:12)
#18     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#19     RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:821:13)
#20     RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#21     RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#22     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#23     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#24     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#25     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#26     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#27     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#28     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#29     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#30     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#31     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#32     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#33     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#34     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#35     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#36     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#37     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#38     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#39     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#40     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#41     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#42     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#43     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#44     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#45     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#46     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#47     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#48     _RenderLayoutBuilder.performLayout (package:flutter/src/widgets/layout_builder.dart:449:14)
#49     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#50     MultiChildLayoutDelegate.layoutChild (package:flutter/src/rendering/custom_layout.dart:180:12)
#51     _ScaffoldLayout.performLayout (package:flutter/src/material/scaffold.dart:1113:7)
#52     MultiChildLayoutDelegate._callPerformLayout (package:flutter/src/rendering/custom_layout.dart:246:7)
#53     RenderCustomMultiChildLayoutBox.performLayout (package:flutter/src/rendering/custom_layout.dart:417:14)
#54     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#55     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#56     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#57     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#58     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#59     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#60     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#61     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#62     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#63     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#64     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#65     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#66     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#67     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#68     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#69     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#70     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#71     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#72     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#73     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#74     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#75     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#76     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#77     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#78     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#79     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#80     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#81     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#82     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#83     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#84     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#85     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#86     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#87     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#88     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#89     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#90     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#91     RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#92     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#93     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#94     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#95     _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#96     _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#97     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#98     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#99     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#100    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#101    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#102    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#103    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#104    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#105    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#106    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#107    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#108    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#109    RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#110    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#111    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#112    AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#113    RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#114    SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#115    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#116    AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#119    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#120    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#121    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#124    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#125    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#126    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#127    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:263:22)
<asynchronous suspension>
#128    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#129    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 7 frames from class _AssertionError, dart:async, and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderMouseRegion#b87d0 relayoutBoundary=up7 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  creator: MouseRegion ← Semantics ← _FocusInheritedScope ← Focus ← _ActionsScope ← Actions ←
    _ParentInkResponseProvider ← _InkResponseStateWidget ← InkWell ← DefaultTextStyle ←
    AnimatedDefaultTextStyle ← _InkFeatures-[GlobalKey#c059f ink renderer] ← ⋯
  parentData: <none> (can use size)
  constraints: BoxConstraints(w=760.0, 0.0<=h<=Infinity)
  size: MISSING
  behavior: opaque
  listeners: enter, exit
  cursor: SystemMouseCursor(basic)
This RenderObject had the following descendants (showing up to depth 5):
    child: RenderSemanticsAnnotations#3428e relayoutBoundary=up8 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderPointerListener#ae027 relayoutBoundary=up9 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderDecoratedBox#1bcd5 relayoutBoundary=up10 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderPadding#bc453 relayoutBoundary=up11 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderFlex#2ac7d relayoutBoundary=up12 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during performLayout():
RenderBox was not laid out: RenderMouseRegion#b87d0 relayoutBoundary=up7 NEEDS-PAINT
NEEDS-COMPOSITING-BITS-UPDATE
'package:flutter/src/rendering/box.dart':
Failed assertion: line 2251 pos 12: 'hasSize'

Either the assertion indicates an error in the framework itself, or we should provide substantially
more information in this error message to help you determine and fix the underlying cause.
In either case, please report this assertion by filing a bug on GitHub:
  https://github.com/flutter/flutter/issues/new?template=02_bug.yml

The relevant error-causing widget was:
  InkWell InkWell:file:///home/runner/work/Ideal/Ideal/lib/ui/widgets/glass_card.dart:103:14

When the exception was thrown, this was the stack:
#2      RenderBox.size (package:flutter/src/rendering/box.dart:2251:12)
#3      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:62)
#4      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#5      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#6      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#7      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#8      RenderCustomPaint.performLayout (package:flutter/src/rendering/custom_paint.dart:574:11)
#9      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#10     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#11     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#12     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#13     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#14     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#15     RenderSliverToBoxAdapter.performLayout (package:flutter/src/rendering/sliver.dart:2098:12)
#16     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#17     RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:821:13)
#18     RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#19     RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#20     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#21     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#22     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#23     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#24     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#25     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#26     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#27     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#28     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#29     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#30     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#31     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#32     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#33     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#34     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#35     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#36     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#37     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#38     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#39     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#40     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#41     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#42     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#43     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#44     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#45     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#46     _RenderLayoutBuilder.performLayout (package:flutter/src/widgets/layout_builder.dart:449:14)
#47     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#48     MultiChildLayoutDelegate.layoutChild (package:flutter/src/rendering/custom_layout.dart:180:12)
#49     _ScaffoldLayout.performLayout (package:flutter/src/material/scaffold.dart:1113:7)
#50     MultiChildLayoutDelegate._callPerformLayout (package:flutter/src/rendering/custom_layout.dart:246:7)
#51     RenderCustomMultiChildLayoutBox.performLayout (package:flutter/src/rendering/custom_layout.dart:417:14)
#52     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#53     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#54     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#55     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#56     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#57     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#58     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#59     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#60     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#61     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#62     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#63     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#64     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#65     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#66     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#67     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#68     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#69     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#70     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#71     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#72     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#73     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#74     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#75     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#76     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#77     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#78     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#79     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#80     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#81     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#82     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#83     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#84     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#85     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#86     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#87     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#88     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#89     RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#90     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#91     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#92     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#93     _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#94     _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#95     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#96     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#97     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#98     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#99     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#100    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#101    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#102    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#103    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#104    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#105    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#106    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#107    RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#108    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#109    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#110    AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#111    RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#112    SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#113    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#114    AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#117    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#118    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#119    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#122    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#123    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#124    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#125    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:263:22)
<asynchronous suspension>
#126    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#127    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 7 frames from class _AssertionError, dart:async, and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderSemanticsAnnotations#53d5f relayoutBoundary=up6 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  creator: Semantics ← _FocusInheritedScope ← Focus ← _ActionsScope ← Actions ←
    _ParentInkResponseProvider ← _InkResponseStateWidget ← InkWell ← DefaultTextStyle ←
    AnimatedDefaultTextStyle ← _InkFeatures-[GlobalKey#c059f ink renderer] ←
    NotificationListener<LayoutChangedNotification> ← ⋯
  parentData: <none> (can use size)
  constraints: BoxConstraints(w=760.0, 0.0<=h<=Infinity)
  size: MISSING
This RenderObject had the following descendants (showing up to depth 5):
    child: RenderMouseRegion#b87d0 relayoutBoundary=up7 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderSemanticsAnnotations#3428e relayoutBoundary=up8 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderPointerListener#ae027 relayoutBoundary=up9 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderDecoratedBox#1bcd5 relayoutBoundary=up10 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderPadding#bc453 relayoutBoundary=up11 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during performLayout():
RenderBox was not laid out: RenderSemanticsAnnotations#53d5f relayoutBoundary=up6 NEEDS-PAINT
NEEDS-COMPOSITING-BITS-UPDATE
'package:flutter/src/rendering/box.dart':
Failed assertion: line 2251 pos 12: 'hasSize'

Either the assertion indicates an error in the framework itself, or we should provide substantially
more information in this error message to help you determine and fix the underlying cause.
In either case, please report this assertion by filing a bug on GitHub:
  https://github.com/flutter/flutter/issues/new?template=02_bug.yml

The relevant error-causing widget was:
  Material Material:file:///home/runner/work/Ideal/Ideal/lib/ui/widgets/glass_card.dart:100:12

When the exception was thrown, this was the stack:
#2      RenderBox.size (package:flutter/src/rendering/box.dart:2251:12)
#3      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:62)
#4      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#5      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#6      RenderCustomPaint.performLayout (package:flutter/src/rendering/custom_paint.dart:574:11)
#7      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#8      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#9      _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#10     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#11     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#12     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#13     RenderSliverToBoxAdapter.performLayout (package:flutter/src/rendering/sliver.dart:2098:12)
#14     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#15     RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:821:13)
#16     RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#17     RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#18     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#19     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#20     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#21     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#22     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#23     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#24     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#25     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#26     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#27     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#28     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#29     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#30     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#31     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#32     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#33     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#34     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#35     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#36     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#37     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#38     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#39     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#40     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#41     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#42     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#43     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#44     _RenderLayoutBuilder.performLayout (package:flutter/src/widgets/layout_builder.dart:449:14)
#45     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#46     MultiChildLayoutDelegate.layoutChild (package:flutter/src/rendering/custom_layout.dart:180:12)
#47     _ScaffoldLayout.performLayout (package:flutter/src/material/scaffold.dart:1113:7)
#48     MultiChildLayoutDelegate._callPerformLayout (package:flutter/src/rendering/custom_layout.dart:246:7)
#49     RenderCustomMultiChildLayoutBox.performLayout (package:flutter/src/rendering/custom_layout.dart:417:14)
#50     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#51     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#52     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#53     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#54     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#55     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#56     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#57     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#58     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#59     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#60     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#61     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#62     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#63     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#64     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#65     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#66     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#67     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#68     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#69     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#70     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#71     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#72     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#73     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#74     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#75     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#76     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#77     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#78     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#79     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#80     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#81     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#82     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#83     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#84     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#85     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#86     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#87     RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#88     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#89     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#90     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#91     _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#92     _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#93     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#94     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#95     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#96     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#97     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#98     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#99     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#100    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#101    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#102    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#103    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#104    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#105    RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#106    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#107    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#108    AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#109    RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#110    SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#111    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#112    AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#115    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#116    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#117    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#120    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#121    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#122    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#123    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:263:22)
<asynchronous suspension>
#124    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#125    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 7 frames from class _AssertionError, dart:async, and package:stack_trace)

The following RenderObject was being processed when the exception was fired: _RenderInkFeatures#7f0a1 relayoutBoundary=up5 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  creator: _InkFeatures-[GlobalKey#c059f ink renderer] ←
    NotificationListener<LayoutChangedNotification> ← CustomPaint ← _ShapeBorderPaint ← PhysicalShape
    ← _MaterialInterior ← Material ← SurfaceCard ← _ScopeNotice ← Padding ← SliverToBoxAdapter ←
    Viewport ← ⋯
  parentData: <none> (can use size)
  constraints: BoxConstraints(w=760.0, 0.0<=h<=Infinity)
  size: MISSING
This RenderObject had the following descendants (showing up to depth 5):
    child: RenderSemanticsAnnotations#53d5f relayoutBoundary=up6 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderMouseRegion#b87d0 relayoutBoundary=up7 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderSemanticsAnnotations#3428e relayoutBoundary=up8 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderPointerListener#ae027 relayoutBoundary=up9 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderDecoratedBox#1bcd5 relayoutBoundary=up10 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during performLayout():
RenderBox was not laid out: _RenderInkFeatures#7f0a1 relayoutBoundary=up5 NEEDS-PAINT
NEEDS-COMPOSITING-BITS-UPDATE
'package:flutter/src/rendering/box.dart':
Failed assertion: line 2251 pos 12: 'hasSize'

Either the assertion indicates an error in the framework itself, or we should provide substantially
more information in this error message to help you determine and fix the underlying cause.
In either case, please report this assertion by filing a bug on GitHub:
  https://github.com/flutter/flutter/issues/new?template=02_bug.yml

The relevant error-causing widget was:
  Material Material:file:///home/runner/work/Ideal/Ideal/lib/ui/widgets/glass_card.dart:100:12

When the exception was thrown, this was the stack:
#2      RenderBox.size (package:flutter/src/rendering/box.dart:2251:12)
#3      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:62)
#4      RenderCustomPaint.performLayout (package:flutter/src/rendering/custom_paint.dart:574:11)
#5      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#6      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#7      _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#8      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#9      RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#10     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#11     RenderSliverToBoxAdapter.performLayout (package:flutter/src/rendering/sliver.dart:2098:12)
#12     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#13     RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:821:13)
#14     RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#15     RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#16     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#17     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#18     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#19     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#20     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#21     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#22     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#23     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#24     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#25     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#26     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#27     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#28     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#29     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#30     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#31     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#32     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#33     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#34     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#35     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#36     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#37     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#38     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#39     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#40     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#41     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#42     _RenderLayoutBuilder.performLayout (package:flutter/src/widgets/layout_builder.dart:449:14)
#43     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#44     MultiChildLayoutDelegate.layoutChild (package:flutter/src/rendering/custom_layout.dart:180:12)
#45     _ScaffoldLayout.performLayout (package:flutter/src/material/scaffold.dart:1113:7)
#46     MultiChildLayoutDelegate._callPerformLayout (package:flutter/src/rendering/custom_layout.dart:246:7)
#47     RenderCustomMultiChildLayoutBox.performLayout (package:flutter/src/rendering/custom_layout.dart:417:14)
#48     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#49     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#50     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#51     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#52     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#53     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#54     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#55     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#56     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#57     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#58     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#59     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#60     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#61     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#62     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#63     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#64     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#65     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#66     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#67     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#68     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#69     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#70     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#71     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#72     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#73     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#74     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#75     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#76     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#77     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#78     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#79     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#80     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#81     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#82     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#83     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#84     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#85     RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#86     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#87     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#88     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#89     _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#90     _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#91     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#92     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#93     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#94     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#95     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#96     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#97     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#98     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#99     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#100    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#101    RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#102    RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#103    RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#104    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#105    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#106    AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#107    RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#108    SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#109    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#110    AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#113    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#114    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#115    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#118    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#119    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#120    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#121    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:263:22)
<asynchronous suspension>
#122    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#123    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 7 frames from class _AssertionError, dart:async, and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderCustomPaint#058cd relayoutBoundary=up4 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  creator: CustomPaint ← _ShapeBorderPaint ← PhysicalShape ← _MaterialInterior ← Material ←
    SurfaceCard ← _ScopeNotice ← Padding ← SliverToBoxAdapter ← Viewport ←
    IgnorePointer-[GlobalKey#5776a] ← Semantics ← ⋯
  parentData: <none> (can use size)
  constraints: BoxConstraints(w=760.0, 0.0<=h<=Infinity)
  size: MISSING
  painter: null
  foregroundPainter: _ShapeBorderPainter#78055()
This RenderObject had the following descendants (showing up to depth 5):
    child: _RenderInkFeatures#7f0a1 relayoutBoundary=up5 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderSemanticsAnnotations#53d5f relayoutBoundary=up6 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderMouseRegion#b87d0 relayoutBoundary=up7 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderSemanticsAnnotations#3428e relayoutBoundary=up8 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderPointerListener#ae027 relayoutBoundary=up9 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during performLayout():
RenderBox was not laid out: RenderCustomPaint#058cd relayoutBoundary=up4 NEEDS-PAINT
NEEDS-COMPOSITING-BITS-UPDATE
'package:flutter/src/rendering/box.dart':
Failed assertion: line 2251 pos 12: 'hasSize'

Either the assertion indicates an error in the framework itself, or we should provide substantially
more information in this error message to help you determine and fix the underlying cause.
In either case, please report this assertion by filing a bug on GitHub:
  https://github.com/flutter/flutter/issues/new?template=02_bug.yml

The relevant error-causing widget was:
  Material Material:file:///home/runner/work/Ideal/Ideal/lib/ui/widgets/glass_card.dart:100:12

When the exception was thrown, this was the stack:
#2      RenderBox.size (package:flutter/src/rendering/box.dart:2251:12)
#3      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:62)
#4      _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#5      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#6      RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#7      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#8      RenderSliverToBoxAdapter.performLayout (package:flutter/src/rendering/sliver.dart:2098:12)
#9      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#10     RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:821:13)
#11     RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#12     RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#13     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#14     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#15     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#16     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#17     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#18     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#19     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#20     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#21     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#22     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#23     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#24     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#25     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#26     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#27     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#28     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#29     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#30     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#31     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#32     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#33     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#34     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#35     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#36     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#37     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#38     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#39     _RenderLayoutBuilder.performLayout (package:flutter/src/widgets/layout_builder.dart:449:14)
#40     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#41     MultiChildLayoutDelegate.layoutChild (package:flutter/src/rendering/custom_layout.dart:180:12)
#42     _ScaffoldLayout.performLayout (package:flutter/src/material/scaffold.dart:1113:7)
#43     MultiChildLayoutDelegate._callPerformLayout (package:flutter/src/rendering/custom_layout.dart:246:7)
#44     RenderCustomMultiChildLayoutBox.performLayout (package:flutter/src/rendering/custom_layout.dart:417:14)
#45     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#46     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#47     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#48     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#49     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#50     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#51     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#52     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#53     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#54     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#55     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#56     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#57     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#58     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#59     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#60     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#61     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#62     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#63     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#64     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#65     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#66     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#67     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#68     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#69     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#70     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#71     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#72     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#73     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#74     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#75     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#76     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#77     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#78     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#79     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#80     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#81     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#82     RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#83     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#84     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#85     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#86     _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#87     _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#88     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#89     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#90     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#91     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#92     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#93     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#94     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#95     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#96     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#97     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#98     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#99     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#100    RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#101    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#102    PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#103    AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#104    RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#105    SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#106    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#107    AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#110    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#111    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#112    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#115    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#116    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#117    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#118    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:263:22)
<asynchronous suspension>
#119    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#120    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 7 frames from class _AssertionError, dart:async, and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderPhysicalShape#7ec1f relayoutBoundary=up3 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  creator: PhysicalShape ← _MaterialInterior ← Material ← SurfaceCard ← _ScopeNotice ← Padding ←
    SliverToBoxAdapter ← Viewport ← IgnorePointer-[GlobalKey#5776a] ← Semantics ← Listener ←
    _GestureSemantics ← ⋯
  parentData: offset=Offset(0.0, 0.0) (can use size)
  constraints: BoxConstraints(w=760.0, 0.0<=h<=Infinity)
  size: MISSING
  elevation: 0.0
  color: Color(alpha: 0.6500, red: 0.0667, green: 0.0941, blue: 0.2039, colorSpace: ColorSpace.sRGB)
  shadowColor: Color(alpha: 0.6500, red: 0.0667, green: 0.0941, blue: 0.2039, colorSpace:
    ColorSpace.sRGB)
  clipper: ShapeBorderClipper
This RenderObject had the following descendants (showing up to depth 5):
    child: RenderCustomPaint#058cd relayoutBoundary=up4 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: _RenderInkFeatures#7f0a1 relayoutBoundary=up5 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderSemanticsAnnotations#53d5f relayoutBoundary=up6 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderMouseRegion#b87d0 relayoutBoundary=up7 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderSemanticsAnnotations#3428e relayoutBoundary=up8 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during performLayout():
RenderBox was not laid out: RenderPhysicalShape#7ec1f relayoutBoundary=up3 NEEDS-PAINT
NEEDS-COMPOSITING-BITS-UPDATE
'package:flutter/src/rendering/box.dart':
Failed assertion: line 2251 pos 12: 'hasSize'

Either the assertion indicates an error in the framework itself, or we should provide substantially
more information in this error message to help you determine and fix the underlying cause.
In either case, please report this assertion by filing a bug on GitHub:
  https://github.com/flutter/flutter/issues/new?template=02_bug.yml

The relevant error-causing widget was:
  Padding
  Padding:file:///home/runner/work/Ideal/Ideal/lib/features/messages/messages_screen.dart:51:18

When the exception was thrown, this was the stack:
#2      RenderBox.size (package:flutter/src/rendering/box.dart:2251:12)
#3      RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:266:40)
#4      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#5      RenderSliverToBoxAdapter.performLayout (package:flutter/src/rendering/sliver.dart:2098:12)
#6      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#7      RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:821:13)
#8      RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#9      RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#10     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#11     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#12     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#13     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#14     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#15     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#16     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#17     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#18     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#19     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#20     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#21     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#22     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#23     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#24     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#25     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#26     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#27     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#28     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#29     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#30     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#31     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#32     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#33     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#34     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#35     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#36     _RenderLayoutBuilder.performLayout (package:flutter/src/widgets/layout_builder.dart:449:14)
#37     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#38     MultiChildLayoutDelegate.layoutChild (package:flutter/src/rendering/custom_layout.dart:180:12)
#39     _ScaffoldLayout.performLayout (package:flutter/src/material/scaffold.dart:1113:7)
#40     MultiChildLayoutDelegate._callPerformLayout (package:flutter/src/rendering/custom_layout.dart:246:7)
#41     RenderCustomMultiChildLayoutBox.performLayout (package:flutter/src/rendering/custom_layout.dart:417:14)
#42     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#43     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#44     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#45     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#46     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#47     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#48     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#49     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#50     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#51     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#52     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#53     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#54     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#55     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#56     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#57     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#58     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#59     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#60     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#61     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#62     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#63     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#64     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#65     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#66     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#67     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#68     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#69     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#70     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#71     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#72     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#73     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#74     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#75     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#76     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#77     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#78     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#79     RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#80     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#81     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#82     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#83     _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#84     _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#85     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#86     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#87     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#88     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#89     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#90     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#91     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#92     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#93     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#94     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#95     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#96     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#97     RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#98     PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#99     PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#100    AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#101    RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#102    SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#103    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#104    AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#107    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#108    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#109    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#112    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#113    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#114    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#115    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:263:22)
<asynchronous suspension>
#116    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#117    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 7 frames from class _AssertionError, dart:async, and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderPadding#83353 relayoutBoundary=up2 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  creator: Padding ← SliverToBoxAdapter ← Viewport ← IgnorePointer-[GlobalKey#5776a] ← Semantics ←
    Listener ← _GestureSemantics ←
    RawGestureDetector-[LabeledGlobalKey<RawGestureDetectorState>#b6775] ← Listener ← _ScrollableScope
    ← _ScrollSemantics-[GlobalKey#12d29] ← NotificationListener<ScrollMetricsNotification> ← ⋯
  parentData: paintOffset=Offset(0.0, 0.0) (can use size)
  constraints: BoxConstraints(w=800.0, 0.0<=h<=Infinity)
  size: MISSING
  padding: EdgeInsets(20.0, 8.0, 20.0, 0.0)
  textDirection: rtl
This RenderObject had the following descendants (showing up to depth 5):
    child: RenderPhysicalShape#7ec1f relayoutBoundary=up3 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderCustomPaint#058cd relayoutBoundary=up4 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: _RenderInkFeatures#7f0a1 relayoutBoundary=up5 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderSemanticsAnnotations#53d5f relayoutBoundary=up6 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderMouseRegion#b87d0 relayoutBoundary=up7 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during performLayout():
RenderBox was not laid out: RenderPadding#83353 relayoutBoundary=up2 NEEDS-PAINT
NEEDS-COMPOSITING-BITS-UPDATE
'package:flutter/src/rendering/box.dart':
Failed assertion: line 2251 pos 12: 'hasSize'

Either the assertion indicates an error in the framework itself, or we should provide substantially
more information in this error message to help you determine and fix the underlying cause.
In either case, please report this assertion by filing a bug on GitHub:
  https://github.com/flutter/flutter/issues/new?template=02_bug.yml

The relevant error-causing widget was:
  SliverToBoxAdapter
  SliverToBoxAdapter:file:///home/runner/work/Ideal/Ideal/lib/features/messages/messages_screen.dart:50:15

When the exception was thrown, this was the stack:
#2      RenderBox.size (package:flutter/src/rendering/box.dart:2251:12)
#3      RenderSliverToBoxAdapter.performLayout (package:flutter/src/rendering/sliver.dart:2101:31)
#4      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#5      RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:821:13)
#6      RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#7      RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#8      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#9      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#10     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#11     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#12     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#13     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#14     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#15     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#16     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#17     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#18     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#19     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#20     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#21     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#22     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#23     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#24     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#25     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#26     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#27     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#28     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#29     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#30     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#31     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#32     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#33     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#34     _RenderLayoutBuilder.performLayout (package:flutter/src/widgets/layout_builder.dart:449:14)
#35     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#36     MultiChildLayoutDelegate.layoutChild (package:flutter/src/rendering/custom_layout.dart:180:12)
#37     _ScaffoldLayout.performLayout (package:flutter/src/material/scaffold.dart:1113:7)
#38     MultiChildLayoutDelegate._callPerformLayout (package:flutter/src/rendering/custom_layout.dart:246:7)
#39     RenderCustomMultiChildLayoutBox.performLayout (package:flutter/src/rendering/custom_layout.dart:417:14)
#40     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#41     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#42     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#43     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#44     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#45     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#46     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#47     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#48     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#49     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#50     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#51     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#52     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#53     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#54     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#55     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#56     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#57     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#58     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#59     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#60     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#61     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#62     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#63     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#64     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#65     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#66     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#67     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#68     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#69     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#70     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#71     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#72     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#73     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#74     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#75     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#76     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#77     RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#78     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#79     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#80     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#81     _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#82     _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#83     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#84     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#85     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#86     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#87     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#88     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#89     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#90     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#91     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#92     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#93     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#94     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#95     RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#96     PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#97     PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#98     AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#99     RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#100    SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#101    SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#102    AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#105    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#106    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#107    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#110    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#111    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#112    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#113    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:263:22)
<asynchronous suspension>
#114    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#115    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 7 frames from class _AssertionError, dart:async, and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderSliverToBoxAdapter#6b2d3 relayoutBoundary=up1 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  creator: SliverToBoxAdapter ← Viewport ← IgnorePointer-[GlobalKey#5776a] ← Semantics ← Listener ←
    _GestureSemantics ← RawGestureDetector-[LabeledGlobalKey<RawGestureDetectorState>#b6775] ←
    Listener ← _ScrollableScope ← _ScrollSemantics-[GlobalKey#12d29] ←
    NotificationListener<ScrollMetricsNotification> ← Transform ← ⋯
  parentData: paintOffset=Offset(0.0, 0.0) (can use size)
  constraints: SliverConstraints(AxisDirection.down, GrowthDirection.forward, ScrollDirection.idle,
    scrollOffset: 0.0, precedingScrollExtent: 60.0, remainingPaintExtent: 540.0, crossAxisExtent:
    800.0, crossAxisDirection: AxisDirection.left, viewportMainAxisExtent: 600.0,
    remainingCacheExtent: 790.0, cacheOrigin: 0.0)
  geometry: null
This RenderObject had the following descendants (showing up to depth 5):
    child: RenderPadding#83353 relayoutBoundary=up2 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderPhysicalShape#7ec1f relayoutBoundary=up3 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderCustomPaint#058cd relayoutBoundary=up4 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: _RenderInkFeatures#7f0a1 relayoutBoundary=up5 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderSemanticsAnnotations#53d5f relayoutBoundary=up6 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following _TypeError was thrown during performLayout():
Null check operator used on a null value

The relevant error-causing widget was:
  CustomScrollView
  CustomScrollView:file:///home/runner/work/Ideal/Ideal/lib/features/messages/messages_screen.dart:26:12

When the exception was thrown, this was the stack:
#0      RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:842:64)
#1      RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#2      RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#3      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#4      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#5      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#6      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#7      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#8      RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#9      RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#10     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#11     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#12     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#13     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#14     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#15     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#16     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#17     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#18     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#19     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#20     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#21     ChildLayoutHelper.layoutChild (package:flutter/src/rendering/layout_helper.dart:62:11)
#22     RenderStack._computeSize (package:flutter/src/rendering/stack.dart:647:43)
#23     RenderStack.performLayout (package:flutter/src/rendering/stack.dart:682:12)
#24     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#25     RenderPadding.performLayout (package:flutter/src/rendering/shifted_box.dart:262:12)
#26     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#27     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#28     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#29     _RenderLayoutBuilder.performLayout (package:flutter/src/widgets/layout_builder.dart:449:14)
#30     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#31     MultiChildLayoutDelegate.layoutChild (package:flutter/src/rendering/custom_layout.dart:180:12)
#32     _ScaffoldLayout.performLayout (package:flutter/src/material/scaffold.dart:1113:7)
#33     MultiChildLayoutDelegate._callPerformLayout (package:flutter/src/rendering/custom_layout.dart:246:7)
#34     RenderCustomMultiChildLayoutBox.performLayout (package:flutter/src/rendering/custom_layout.dart:417:14)
#35     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#36     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#37     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#38     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#39     _RenderCustomClip.performLayout (package:flutter/src/rendering/proxy_box.dart:1549:11)
#40     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#41     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#42     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#43     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#44     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#45     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#46     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#47     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#48     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#49     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#50     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#51     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#52     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#53     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#54     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#55     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#56     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#57     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#58     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#59     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#60     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#61     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#62     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#63     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#64     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#65     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#66     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#67     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#68     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#69     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#70     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#71     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#72     RenderOffstage.performLayout (package:flutter/src/rendering/proxy_box.dart:3923:13)
#73     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#74     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#75     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#76     _RenderTheaterMixin.layoutChild (package:flutter/src/widgets/overlay.dart:1124:13)
#77     _RenderTheater.performLayout (package:flutter/src/widgets/overlay.dart:1482:9)
#78     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#79     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#80     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#81     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#82     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#83     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#84     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#85     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#86     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#87     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#88     RenderObject.layout (package:flutter/src/rendering/object.dart:2923:7)
#89     RenderProxyBoxMixin.performLayout (package:flutter/src/rendering/proxy_box.dart:118:18)
#90     RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#91     PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#92     PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#93     AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#94     RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#95     SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#96     SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#97     AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#100    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#101    AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#102    WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#105    TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#106    WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#107    main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#108    main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:263:22)
<asynchronous suspension>
#109    testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#110    TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 5 frames from dart:async and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderViewport#ff524 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  needs compositing
  creator: Viewport ← IgnorePointer-[GlobalKey#5776a] ← Semantics ← Listener ← _GestureSemantics ←
    RawGestureDetector-[LabeledGlobalKey<RawGestureDetectorState>#b6775] ← Listener ← _ScrollableScope
    ← _ScrollSemantics-[GlobalKey#12d29] ← NotificationListener<ScrollMetricsNotification> ← Transform
    ← StretchEffect ← ⋯
  parentData: <none> (can use size)
  constraints: BoxConstraints(0.0<=w<=800.0, 0.0<=h<=600.0)
  size: Size(800.0, 600.0)
  axisDirection: down
  crossAxisDirection: left
  offset: ScrollPositionWithSingleContext#a7197(offset: 0.0, range: null..null, viewport: 600.0,
    ScrollableState, AlwaysScrollableScrollPhysics -> ClampingScrollPhysics ->
    RangeMaintainingScrollPhysics, IdleScrollActivity#5573d, ScrollDirection.idle)
  anchor: 0.0
This RenderObject had the following descendants (showing up to depth 5):
    center child: RenderSliverToBoxAdapter#1ca1f relayoutBoundary=up1 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderPadding#cd373 relayoutBoundary=up2 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderFlex#7be2c relayoutBoundary=up3 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child 1: RenderParagraph#f329c relayoutBoundary=up4 NEEDS-PAINT
            text: TextSpan
    child 1: RenderSliverToBoxAdapter#6b2d3 relayoutBoundary=up1 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderPadding#83353 relayoutBoundary=up2 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderPhysicalShape#7ec1f relayoutBoundary=up3 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderCustomPaint#058cd relayoutBoundary=up4 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: _RenderInkFeatures#7f0a1 relayoutBoundary=up5 NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
    child 2: RenderSliverToBoxAdapter#ae8e6 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderPadding#6447b NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderClipRRect#ac9a7 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderBackdropFilter#7bef2 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderDecoratedBox#52e09 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
    child 3: RenderSliverFillRemainingWithScrollable#6529d NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderPositionedBox#249b5 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderSemanticsAnnotations#dcddc NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child: RenderConstrainedBox#e9e83 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderCustomPaint#9bc9c NEEDS-LAYOUT NEEDS-PAINT
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following _TypeError was thrown during performLayout():
Null check operator used on a null value

The relevant error-causing widget was:
  CustomScrollView
  CustomScrollView:file:///home/runner/work/Ideal/Ideal/lib/features/messages/messages_screen.dart:26:12

When the exception was thrown, this was the stack:
#0      RenderViewportBase.layoutChildSequence (package:flutter/src/rendering/viewport.dart:842:64)
#1      RenderViewport._attemptLayout (package:flutter/src/rendering/viewport.dart:1831:12)
#2      RenderViewport.performLayout (package:flutter/src/rendering/viewport.dart:1724:20)
#3      RenderObject._layoutWithoutResize (package:flutter/src/rendering/object.dart:2771:7)
#4      PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1174:18)
#5      PipelineOwner.flushLayout (package:flutter/src/rendering/object.dart:1187:15)
#6      AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2434:27)
#7      RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
#8      SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
#9      SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
#10     AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
#13     TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#14     AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
#15     WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
#18     TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
#19     WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
#20     main.pumpApp (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:177:20)
<asynchronous suspension>
#21     main.<anonymous closure> (file:///home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart:263:22)
<asynchronous suspension>
#22     testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#23     TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
<asynchronous suspension>
<asynchronous suspension>
(elided 5 frames from dart:async and package:stack_trace)

The following RenderObject was being processed when the exception was fired: RenderViewport#ff524 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE:
  needs compositing
  creator: Viewport ← IgnorePointer-[GlobalKey#5776a] ← Semantics ← Listener ← _GestureSemantics ←
    RawGestureDetector-[LabeledGlobalKey<RawGestureDetectorState>#b6775] ← Listener ← _ScrollableScope
    ← _ScrollSemantics-[GlobalKey#12d29] ← NotificationListener<ScrollMetricsNotification> ← Transform
    ← StretchEffect ← ⋯
  parentData: <none> (can use size)
  constraints: BoxConstraints(0.0<=w<=800.0, 0.0<=h<=600.0)
  size: Size(800.0, 600.0)
  axisDirection: down
  crossAxisDirection: left
  offset: ScrollPositionWithSingleContext#a7197(offset: 0.0, range: null..null, viewport: 600.0,
    ScrollableState, AlwaysScrollableScrollPhysics -> ClampingScrollPhysics ->
    RangeMaintainingScrollPhysics, IdleScrollActivity#5573d, ScrollDirection.idle)
  anchor: 0.0
This RenderObject had the following descendants (showing up to depth 5):
    center child: RenderSliverToBoxAdapter#1ca1f relayoutBoundary=up1 NEEDS-PAINT
      child: RenderPadding#cd373 relayoutBoundary=up2 NEEDS-PAINT
        child: RenderFlex#7be2c relayoutBoundary=up3 NEEDS-PAINT
          child 1: RenderParagraph#f329c relayoutBoundary=up4 NEEDS-PAINT
            text: TextSpan
    child 1: RenderSliverToBoxAdapter#6b2d3 relayoutBoundary=up1 NEEDS-PAINT
      child: RenderPadding#83353 relayoutBoundary=up2 NEEDS-PAINT
        child: RenderPhysicalShape#7ec1f relayoutBoundary=up3 NEEDS-PAINT
          child: RenderCustomPaint#058cd relayoutBoundary=up4 NEEDS-PAINT
            child: _RenderInkFeatures#7f0a1 relayoutBoundary=up5 NEEDS-PAINT
    child 2: RenderSliverToBoxAdapter#ae8e6 NEEDS-LAYOUT NEEDS-PAINT
      child: RenderPadding#6447b NEEDS-LAYOUT NEEDS-PAINT
        child: RenderClipRRect#ac9a7 NEEDS-LAYOUT NEEDS-PAINT
          child: RenderBackdropFilter#7bef2 NEEDS-LAYOUT NEEDS-PAINT
            child: RenderDecoratedBox#52e09 NEEDS-LAYOUT NEEDS-PAINT
    child 3: RenderSliverFillRemaining#0c0c0 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
      child: RenderPadding#ceb4a NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
        child: RenderFlex#8c645 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child 1: RenderConstrainedBox#2bc55 NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
            child: RenderDecoratedBox#6792a NEEDS-LAYOUT NEEDS-PAINT NEEDS-COMPOSITING-BITS-UPDATE
          child 2: RenderConstrainedBox#9ed07 NEEDS-LAYOUT NEEDS-PAINT
          child 3: RenderParagraph#6943b NEEDS-LAYOUT NEEDS-PAINT
            text: TextSpan
          child 4: RenderConstrainedBox#ed1f0 NEEDS-LAYOUT NEEDS-PAINT
          child 5: RenderParagraph#0fc1c NEEDS-LAYOUT NEEDS-PAINT
            text: TextSpan
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following message was thrown:
Multiple exceptions (27) were detected during the running of the current test, and at least one was
unexpected.
════════════════════════════════════════════════════════════════════════════════════════════════════
00:04 +0 -4: a stored note appears in the notes tab [E]
  Test failed. See exception logs above.
  The test description was: a stored note appears in the notes tab
  
00:05 +0 -4: (tearDownAll)
00:05 +0 -4: Some tests failed.

Failing tests:
  /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: a stored note appears in the notes tab
  /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: boots into the assistant tab in RTL with Persian labels
  /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: navigates through all five tabs
  /home/runner/work/Ideal/Ideal/test/widget/app_smoke_test.dart: typed assistant input opens the confirmation sheet
```

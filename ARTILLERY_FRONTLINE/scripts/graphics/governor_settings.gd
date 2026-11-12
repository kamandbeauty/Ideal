class_name GovernorSettings
extends Resource
## Every number the automatic quality governor works from, in one place:
## resources/graphics/governor.tres. None of them has been tuned on a phone;
## they are here so that they can be, without touching code.

## false: "auto" only picks the starting tier and then leaves quality alone.
@export var enabled: bool = true
## Frame rate the governor aims for. It never aims above what the display can show.
@export_range(20.0, 120.0, 1.0) var target_fps: float = 60.0
## A frame is slow when it takes more than this many times its budget (1.22 of a 60 fps budget is 49 fps).
@export_range(1.02, 2.0, 0.01) var slow_ratio: float = 1.22
## A frame is fast when it takes no more than this many times its budget.
@export_range(1.0, 1.5, 0.01) var fast_ratio: float = 1.05
## Seconds of slow frames before the render resolution drops a step.
@export_range(0.5, 20.0, 0.1) var slow_window: float = 2.0
## Seconds of unbroken fast frames before it comes back up a step.
@export_range(1.0, 60.0, 0.5) var fast_window: float = 8.0
## Frames are not judged for this long after a step down, and after a step up.
@export_range(0.0, 10.0, 0.1) var cooldown_after_lowering: float = 1.5
@export_range(0.0, 10.0, 0.1) var cooldown_after_raising: float = 3.0
## One step of render resolution, and the lowest the resolution goes.
@export_range(0.02, 0.2, 0.01) var scale_step: float = 0.06
@export_range(0.4, 1.0, 0.01) var scale_floor: float = 0.55
## Slow frames this soon after a step up mean the step was one too many: the
## resolution it came from becomes the ceiling until the tier changes.
@export_range(0.0, 60.0, 0.5) var regret_window: float = 10.0
## What a change must buy, as a share of the frame time. Resolution taken all
## the way down, or a tier given up, that shortens frames by less is undone.
@export_range(0.0, 0.5, 0.01) var min_gain: float = 0.1
## Seconds of slow frames, with the resolution unable to help, before one tier is given up.
@export_range(1.0, 60.0, 0.5) var floor_patience: float = 8.0
## Seconds after giving up a tier before judging whether that helped.
@export_range(1.0, 60.0, 0.5) var tier_judge_window: float = 6.0
## Frames are not judged for this long after a change of tier.
@export_range(0.0, 20.0, 0.5) var warmup: float = 4.0
## The lowest tier "auto" may fall to: "low", "medium" or "high".
@export var lowest_tier: String = "low"

class_name AimSettings
extends Resource
## Every number that shapes how the mounted gun aims. Angles are in degrees;
## yaw is positive to the right and pitch is positive upward, so "-15" is
## fifteen degrees below the horizon.

@export_group("Limits")
@export_range(-180.0, 0.0, 0.5) var yaw_min_degrees: float = -70.0
@export_range(0.0, 180.0, 0.5) var yaw_max_degrees: float = 70.0
@export_range(-89.0, 0.0, 0.5) var pitch_min_degrees: float = -15.0
@export_range(0.0, 89.0, 0.5) var pitch_max_degrees: float = 45.0
@export var start_yaw_degrees: float = 0.0
@export var start_pitch_degrees: float = -5.0

@export_group("Response")
## Degrees of turn per pixel dragged, measured on the 1440-wide reference canvas.
@export_range(0.01, 0.5, 0.005) var degrees_per_pixel: float = 0.085
## Vertical drag is scaled by this so a thumb arc does not overshoot in pitch.
@export_range(0.2, 1.5, 0.05) var vertical_ratio: float = 0.8
## How quickly the gun catches up with the commanded aim (1/s). 0 follows the finger exactly.
@export_range(0.0, 60.0, 0.5) var smoothing_speed: float = 24.0
## Keyboard and gamepad turn rate in degrees per second.
@export_range(10.0, 240.0, 1.0) var key_turn_speed: float = 75.0

@export_group("Recoil")
@export_range(0.0, 2.0, 0.01) var recoil_pitch_degrees: float = 0.12
@export_range(0.0, 2.0, 0.01) var recoil_yaw_degrees: float = 0.07
## Ceiling of the accumulated climb; sustained fire settles here instead of walking off target.
@export_range(0.0, 10.0, 0.1) var recoil_max_degrees: float = 2.2
@export_range(0.5, 40.0, 0.5) var recoil_recovery_speed: float = 9.0
@export_range(0.0, 2.0, 0.01) var camera_shake_degrees: float = 0.16

@export_group("Camera")
@export_range(25.0, 90.0, 0.5) var fov_degrees: float = 46.0
## Eye position relative to the trunnion: x right, y up, z behind the breech.
@export var eye_offset: Vector3 = Vector3(0.0, 0.43, 1.35)

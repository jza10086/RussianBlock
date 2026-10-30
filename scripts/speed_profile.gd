class_name StackSpeedProfile
extends Resource
## Exponential time ramp, independent from cleared lines / score level.
@export_range(0.1, 3.0, 0.01) var start_interval := 0.85
@export_range(0.025, 0.5, 0.005) var minimum_interval := 0.065
@export_range(10.0, 600.0, 1.0) var decay_seconds := 110.0
func interval(seconds: float) -> float:
	return maxf(minimum_interval, start_interval * exp(-maxf(0, seconds) / maxf(1, decay_seconds)))

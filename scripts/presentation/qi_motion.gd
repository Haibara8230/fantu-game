extends RefCounted
## Geometry only; timings and provenance live in data/battle_presentation.json.
## Control points approximate the thin, overlapping traces in the official gameplay footage.

static func point(origin: Vector2, target: Vector2, kind: String, t: float, index: int) -> Vector2:
	var fan := float(index % 5 - 2)
	var c1 := origin + Vector2(fan * 20, -45)
	var c2 := target + Vector2(fan * 34, 65)
	if kind == "reserve":
		c1 = origin + Vector2(40 + fan * 23, -115 + fan * 24)
		c2 = target + Vector2(126, 90 - fan * 40)
	elif kind == "return":
		return point(target, origin, "reserve", 1.0 - t, index)
	elif kind == "draw":
		c1 = origin + Vector2(fan * 30, 80)
		c2 = target + Vector2(fan * 16, -85)
	var u := 1.0 - t
	return u * u * u * origin + 3 * u * u * t * c1 + 3 * u * t * t * c2 + t * t * t * target

static func batch_seconds(profile: Dictionary, count: int) -> float:
	if count <= 0:
		return 0.0
	return clampf(float(profile.get("duration", 0.6)), 0.05, 2.0) + minf(0.16, maxi(0, count - 1) * float(profile.get("stagger", 0.0)))

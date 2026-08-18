class_name FixedMath
extends RefCounted

const FIXED_SCALE: int = 1000

static func mul_non_negative(a: int, b_scaled: int) -> int:
	assert(a >= 0)
	assert(b_scaled >= 0)
	return (a * b_scaled) / FIXED_SCALE

static func div_floor_non_negative(numerator: int, denominator: int) -> int:
	assert(numerator >= 0)
	assert(denominator > 0)
	return numerator / denominator

static func div_toward_zero_signed(numerator: int, denominator: int) -> int:
	assert(denominator != 0)
	var magnitude: int = abs(numerator) / abs(denominator)
	return magnitude if (numerator >= 0) == (denominator >= 0) else -magnitude

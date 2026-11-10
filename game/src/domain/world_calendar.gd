class_name WorldCalendar
extends RefCounted
## Astronomical, proleptic Gregorian dates. Day 0 is Saturday, 0000-01-01.
## Negative ordinals are permitted for the birth dates of initial adult bodies.

static func leap(year: int) -> bool:
	return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)

static func month_days(year: int, month: int) -> int:
	if month == 2:
		return 29 if leap(year) else 28
	return 30 if month in [4, 6, 9, 11] else 31

static func year_start(year: int) -> int:
	return 365 * year + floori((year + 3) / 4.0) - floori((year + 99) / 100.0) + floori((year + 399) / 400.0)

static func valid(year: int, month: int, day: int) -> bool:
	return year >= -10000 and year <= 9999 and month >= 1 and month <= 12 and day >= 1 and day <= month_days(year, month)

static func ordinal(year: int, month: int = 1, day: int = 1) -> int:
	assert(valid(year, month, day), "Invalid calendar date")
	var result := year_start(year) + day - 1
	for previous: int in range(1, month):
		result += month_days(year, previous)
	return result

static func date(day: int) -> Vector3i:
	var year := floori(day / 365.2425)
	while year_start(year) > day:
		year -= 1
	while year_start(year + 1) <= day:
		year += 1
	var remaining := day - year_start(year)
	var month := 1
	while remaining >= month_days(year, month):
		remaining -= month_days(year, month)
		month += 1
	return Vector3i(year, month, remaining + 1)

static func add_years(day: int, years: int) -> int:
	var source := date(day)
	var target_year := source.x + years
	return ordinal(target_year, source.y, mini(source.z, month_days(target_year, source.y)))

static func age_years(birth: int, now: int) -> int:
	var years := date(now).x - date(birth).x
	return years - 1 if add_years(birth, years) > now else years

static func weekday(day: int) -> int:
	return posmod(day + 5, 7) # Monday = 0.

static func label(day: int) -> String:
	var value := date(day)
	return "%04d-%02d-%02d" % [value.x, value.y, value.z]

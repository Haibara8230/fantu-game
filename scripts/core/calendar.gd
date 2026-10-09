extends RefCounted
## Fixed calendar: 30-day months, 12-month years. Day 0 = 历元 1 年 1 月初一.
const DAYS_PER_MONTH := 30
const MONTHS_PER_YEAR := 12
const DAYS_PER_YEAR := DAYS_PER_MONTH * MONTHS_PER_YEAR
const ERA := "历元"
const DIGITS := ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]

static func year(day: int) -> int:
	return 1 + day / DAYS_PER_YEAR

static func month(day: int) -> int:
	return 1 + (day % DAYS_PER_YEAR) / DAYS_PER_MONTH

static func day_of_month(day: int) -> int:
	return 1 + day % DAYS_PER_MONTH

static func day_name(value: int) -> String:
	if value <= 10:
		return "初" + DIGITS[value]
	if value < 20:
		return "十" + DIGITS[value - 10]
	if value == 20:
		return "二十"
	if value < 30:
		return "廿" + DIGITS[value - 20]
	return "三十"

static func date_text(day: int) -> String:
	return "%s %d 年 %d 月%s" % [ERA, year(day), month(day), day_name(day_of_month(day))]

static func short_text(day: int) -> String:
	return "%d年%d月%s" % [year(day), month(day), day_name(day_of_month(day))]

static func duration_text(days: int) -> String:
	if days > 0 and days % DAYS_PER_YEAR == 0:
		return "%d 年" % (days / DAYS_PER_YEAR)
	if days > 0 and days % DAYS_PER_MONTH == 0:
		return "%d 个月" % (days / DAYS_PER_MONTH)
	return "%d 日" % days

static func age_years(birth_day: int, day: int) -> int:
	return (day - birth_day) / DAYS_PER_YEAR

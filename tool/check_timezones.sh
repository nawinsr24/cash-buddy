#!/bin/sh
# Runs the date tests in timezones with different offsets and daylight saving.
for tz in Asia/Kolkata America/New_York Europe/London Pacific/Auckland Pacific/Kiritimati Asia/Kathmandu America/St_Johns; do
  echo "== $tz"
  TZ=$tz flutter test test/domain/dates_tz_test.dart test/domain/interest_test.dart 2>&1 | tail -1
done

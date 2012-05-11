#!/usr/bin/env perl6

BEGIN { @*INC.unshift: '../lib'; }

use v6;
use Date::Gregorian;

my $birthday = Gregorian.new('1978-03-01');
#   $birthday = Gregorian.new(1978,3,1);

my $new_day := &Gregorian::new;

say $birthday.WHAT;

say years(10).WHAT;
say (10d).WHAT;

say $birthday;
say $birthday.week_day_name;
say $birthday + 1m;

say $birthday - 10d;

for 1..10 -> $offset { say ($birthday + years($offset)).week_day_name }

my $leap_year = Gregorian.new('2012-02-29');
say $leap_year, ' ', $leap_year + 4y;

my @leap_days := Gregorian.new('2012-02-29').yearly;

#.say for @leap_days[1..10];

say '###';

my @every_31th := Gregorian.new('2013-01-31').monthly;

.say for @every_31th[1..10];

say January ~~ $leap_year;
say February ~~ $leap_year;
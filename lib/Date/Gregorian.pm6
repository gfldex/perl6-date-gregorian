use v6;

# TODO: - impement timezones
#       - if arithmetics are done that don't make sense across different TZs
#         throw exception

grammar ISO8601 {
  rule TOP { ^^ <year> '-' <month> '-' <day> $$ }
  rule year { <[+-]>?\d+ }
  rule month { <[01]>\d }
  rule day { <[0123]>\d }
}

class InvalidISO8601 is Exception {
  method message() { 'Invalid ISO8601 String' }
}

my @week_day_names = <Sunday Monday Tuesday Wednesday Thursday Friday Saturday>;
enum MonthNames (January => 1, February => 2, March => 3, April => 4, May => 5, June => 6, July => 7, August => 8, September => 9, October => 10, November => 11, December => 12);
enum MonthLength <0 31 28 31 30 31 30 31 31 30 31 30 31>;

#  smartmatch against enum NYI  
#  sub infix:<~~>(Day $d, MonthNames $n){
#  	return $d.month == $n.Int;
#  }

#TODO have > < >= <= etc pp

sub is_leap_year(Int $year){
  return True if $year %% 400;
  return True if $year %% 4 & $year !%% 100;
  return False;
}

sub month_length(Int $year, Int $month){
  return 29 if $month == 2 & is_leap_year($year);
  return MonthLength($month);
}
class Gregorian is export {
#  proto new(|$) is export {*}

#  multi new(
#	    Int $year, 
#	    Int $month where 0 < $_ < 12,
#           Int $day where 0 < $_ <= month_length($year, $month)
#	   ) is export {
#   return Day.new(:year($year), :month($month), :day($day));
#  }

  class Day {
    has Int $.year is rw;
    has Int $.month is rw;
    has Int $.day is rw;

    method ISO8601 { return $.year ~ '-' ~ $.month.fmt('%2d') ~ $.day('%2d') }

    method day_of_week(-->Int){
      my Int $y = $.year;
      my Int $m = $.month;
      my Int $d = $.day;
      my Int @t = 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4;
      $y-- if $m < 3;
      return ($y + $y div 4 - $y div 100 + $y div 400 + @t[$m-1] + $d).Int mod 7;
    }

    method week_day_name(-->Str){
      return @week_day_names[$.day_of_week];
    }

    # this max be incorrect if a country changes TZ
    # TODO: make this work for countries that changed TZ
    method length_of_month(){
      return 29 if $.month == 2 && is_leap_year($.year);
      return MonthLength($.month).key.Int;
    }

    method length_of_year(){
      return 365 if !is_leap_year($.year);
      return 366;
    }

    method wonky(){
      # test if we have a day that may not exist this year or in this TZ
    }

    method yearly(){
      my Day $cur = self.clone;
      my $offset = 0;
      return gather loop {
	take $cur + years($offset++);
      }
    }

    method monthly(:$skip){
      my Day $cur = self.clone;
      my $offset = 0;
      
      if $skip {
	return gather loop {
	  my Day $ret = $cur + months($offset++);
	  next if $ret.day > $ret.length_of_month;
	  take $ret;
	}
      } else {
	return gather loop {
	  my Day $ret = $cur + months($offset++);
	  $ret.day = $ret.length_of_month if $ret.day > $ret.length_of_month;
	  take $ret;
	}
      }
    }
  } # class Day

  method new(Str $s) is export {
    my $m = ISO8601.parse($s);
    InvalidISO8601.new.throw if !$m;
    return Day.new(:year($m<year>.Int), :month($m<month>.Int), :day($m<day>.Int));
  }

  class Years {
    has Int $.year;
  }

  class Months {
    has Int $.month;
  }

  class Days {
    has Int $.day;
  }

  sub years(Int $i) is export { Years.new(:year($i)) }
  sub months(Int $i) is export { Months.new(:month($i)) }
  sub days(Int $i) is export { Days.new(:day($i)) }
}

sub postfix:<y>(Int $i) is export { return Gregorian::Years.new(:year($i)) }
sub postfix:<m>(Int $i) is export { return Gregorian::Months.new(:month($i)) }
sub postfix:<d>(Int $i) is export { return Gregorian::Days.new(:day($i)) }


multi infix:<+>(Gregorian::Day $d, Gregorian::Years $y) is export {
  my Int $new_year = $d.year + $y.year;
  my Int $new_day = $d.day;
  $new_day = 28 if $d.month == 2 && $d.day == 29 && !is_leap_year($new_year);
  return Gregorian::Day.new(:year($new_year), :month($d.month), :day($new_day));
}

multi infix:<+>(Gregorian::Day $d, Gregorian::Months $m) is export {
  my Int $year = $d.year + ($m.month div 12 - 1);
  my Int $month = $d.month + $m.month mod 12;
  my Int $day = $d.day;

  return Gregorian::Day.new(:year($year), :month($month), :day($day));
}

multi infix:<+>(Gregorian::Day $d, Gregorian::Days $somedays ) is export {
  my Int $delta = $somedays.day;
  # terribly slow can be made work for countries that changed TZ

  my $future = Gregorian::Day.new(:year($d.year), :month($d.month), :day($d.day));

  # we are moving forward in time until we have no days left
  # TODO we may skip a day that does not exists in this particular TZ, mark the date as wonky
  while $delta > 0 {
# say $future, ' ', $delta, ' ', $future.length_of_month;
    if ($future.day + $delta) <= $future.length_of_month {
      $future.day += $delta;
      $delta = 0;
    } else {
      $delta -= $future.length_of_month;
# say $future.length_of_month, ' ', $future.day, ' ', ($future.length_of_month - $future.day);
      if $future.month == 12 {
	$future.month=1;
	$future.year++;
      } else {
	$future.month++;
      }
    }
  }

  # $future.wonky = True if $d < any(TZ.wonky_days) < $future
  return $future;
}

multi infix:<->(Gregorian::Day $d, Gregorian::Days $somedays) is export {
  my Int $delta = $somedays.day;
  my Gregorian::Day $past .= new(:year($d.year), :month($d.month), :day($d.day));

  while $delta > 0 {
    if $past.day == 1 {
      if $past.month == 1 {
	$past.year--;
	$past.month = 12;
	$past.day = $past.length_of_month;
	$delta--;
      } else {
	$delta -= $past.day;
	$past.month--;
	$past.day = $past.length_of_month;
      }
    } else {
      if $delta > $past.day {
	$delta -= $past.day;
	$past.day = 1;
      } else {
	$past.day -= $delta;
	$delta = 0;
      }
    }
  }

  return $past;
}

multi infix:<==>(Gregorian::Day $d1, Gregorian::Day $d2) is export {
  # returns a Junction for now, not sure if Bool might be better
  return $d1.year == $d2.year & $d1.month == $d2.month & $d1.day == $d2.day;
}

multi infix:<cmp>(Gregorian::Day $d1, Gregorian::Day $d2) is export {
  return Order::Same if $d1 == $d2;
  return Order::Increase if $d1.year < $d1.year;
  return Order::Decrease if $d1.year > $d1.year;
  # after here $d1.year == $d1.year;
  return Order::Increase if $d1.month < $d1.month;
  return Order::Decrease if $d1.month > $d1.month;
  # after here $d1.month == $d1.month
  return Order::Increase if $d1.day < $d1.day;
  return Order::Decrease;
}

#my $m = ISO8601.parse('1978-03-01');
#say $m.Bool;

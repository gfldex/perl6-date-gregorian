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


role Periodic { # represents a periodic point in a Calendar
  method postcircumfix:<[ ]> (**@slice) {...} # --> Date|Any
}

class Yearly does Periodic {
  method postcircumfix:<[ ]> (**@slice_of_years) {...};
}

class Monthly does Periodic {
  # should provide alternative for leapdays
  method postcircumfix:<[ ]> (**@slice_of_months) {...};
}

# how do i express last day in month?

class Weekly does Periodic {
  method postcircumfix:<[ ]> (**@slice_of_weeks) {...};
}

my @week_day_names = <Sunday Monday Tuesday Wednesday Thursday Friday Saturday>;
enum MonthNames (January => 1, February => 2, March => 3, April => 4, May => 5, June => 6, July => 7, August => 8, September => 9, October => 10, November => 11, December => 12);
enum MonthLength <0 31 28 31 30 31 30 31 31 30 31 30 31>;

class Day {
  has Int $.year is rw;
  has Int $.month is rw;
  has Int $.day is rw;

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
}

#  smartmatch against enum NYI  
#  sub infix:<~~>(Day $d, MonthNames $n){
#  	return $d.month == $n.Int;
#  }

  class SomeYears {
    has Int $.year;
  }

  class SomeMonths {
    has Int $.month;
  }

  class SomeDays {
    has Int $.day;
  }

  sub postfix:<y>(Int $i){ return SomeYears.new(:year($i)) }
  sub postfix:<m>(Int $i){ return SomeMonths.new(:month($i)) }
  sub postfix:<d>(Int $i){ return SomeDays.new(:day($i)) }

  multi infix:<+>(Day $d, SomeYears $y){
    # beware of the leapyears
    my Int $new_year = $d.year + $y.year;
    my Int $new_day = $d.day;
    $new_day = 28 if $d.month == 2 && $d.day == 29 && !is_leap_year($new_year);
    return Day.new(:year($new_year), :month($d.month), :day($new_day));
  }

  multi infix:<+>(Day $d, SomeMonths $m){
    my Int $year = $d.year + ($m.month div 12 - 1);
    my Int $month = $d.month + $m.month mod 12;
    my Int $day = $d.day;

    return Day.new(:year($year), :month($month), :day($day));
  }

  multi infix:<+>( Day $d, SomeDays $somedays ){
    my Int $delta = $somedays.day;
    # terribly slow can be made work for countries that changed TZ

    my $future = Day.new(:year($d.year), :month($d.month), :day($d.day));

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

  multi infix:<==>(Day $d1, Day $d2) is export {
    # returns a Junction for now, not sure if Bool might be better
    return $d1.year == $d2.year & $d1.month == $d2.month & $d1.day == $d2.day;
  }

  multi infix:<cmp>(Day $d1, Day $d2) is export {
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

package Gregorian {

  our proto new(|$) {*}

  multi new(
	    Int $year, 
	    Int $month where 0 < * < 12,
            Int $day where 0 < * <= month_length($year, $month)
  ){
 	return Day.new(:year($year), :month($month), :day($day));
  }

  multi new(Str $s){
  	my $m = ISO8601.parse($s);
  	InvalidISO8601.new.throw if !$m;
  	return new($m<year>.Int, $m<month>.Int, $m<day>.Int);
  }

} # package



my $m = ISO8601.parse('1978-03-01');
say $m.Bool;

my $birthday = Gregorian::new(1978,3,1);
my $iso_birthday = Gregorian::new('1978-03-01');

say "Birthday next year: ", $birthday + 1y;

say $birthday == $iso_birthday;

my $sunday_after_birthday;

my $today = Gregorian::new(2012,4,7);
say $today.day_of_week;
say $today.week_day_name;

my $leapy_year = Gregorian::new(2012,2,29);
say $leapy_year;
say $leapy_year + 1y;
say $leapy_year + 4y;
say "##";
say $leapy_year + 640d;

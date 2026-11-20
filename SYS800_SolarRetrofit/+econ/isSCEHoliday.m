
function isHoliday = isSCEHoliday(timestamps)
% ISSCEHOLIDAY
% Identifies holidays specified in SCE Schedule TOU-D.
%
% Sundays: following Monday is observed.
% Saturdays: no substitute weekday is observed.
%
% Input: datetime array
% Output: logical array matching input dimensions

    dates = dateshift(timestamps, 'start', 'day');
    years = unique(year(dates));

    isHoliday = false(size(dates));

    for y = reshape(years, 1, [])

        % Fixed-date holidays
        fixedDates = [ ...
            datetime(y,1,1); ...
            datetime(y,7,4); ...
            datetime(y,11,11); ...
            datetime(y,12,25)];

        % Third Monday in February: Presidents' Day
        feb1 = datetime(y,2,1);
        febOffset = mod(2 - weekday(feb1), 7);
        presidentsDay = feb1 + days(febOffset + 14);

        % Last Monday in May: Memorial Day
        may31 = datetime(y,5,31);
        mayOffset = mod(weekday(may31) - 2, 7);
        memorialDay = may31 - days(mayOffset);

        % First Monday in September: Labor Day
        sep1 = datetime(y,9,1);
        sepOffset = mod(2 - weekday(sep1), 7);
        laborDay = sep1 + days(sepOffset);

        % Fourth Thursday in November: Thanksgiving
        nov1 = datetime(y,11,1);
        novOffset = mod(5 - weekday(nov1), 7);
        thanksgiving = nov1 + days(novOffset + 21);

        holidayDates = [ ...
            fixedDates;
            presidentsDay;
            memorialDay;
            laborDay;
            thanksgiving];

        % Sunday holidays are also observed Monday
        sundayHolidays = holidayDates(weekday(holidayDates) == 1);
        observedMondays = sundayHolidays + days(1);

        holidayDates = [holidayDates; observedMondays];

        isHoliday = isHoliday | ismember(dates, holidayDates);
    end
end

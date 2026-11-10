DateTime startOfDay(DateTime value) => DateTime(value.year, value.month, value.day);
DateTime endOfDayExclusive(DateTime value) => startOfDay(value).add(const Duration(days: 1));

const _weekdays = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ Nhật',
];
const _shortWeekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

String _two(int n) => n.toString().padLeft(2, '0');

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime today() => dateOnly(DateTime.now());

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String dateKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

DateTime parseDateKey(String key) => dateOnly(DateTime.parse(key));

String formatDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

String formatDayMonth(DateTime d) => '${_two(d.day)}/${_two(d.month)}';

String formatLong(DateTime d) => '${_weekdays[d.weekday - 1]}, ${formatDate(d)}';

String formatLongNoYear(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${formatDayMonth(d)}';

String shortWeekday(DateTime d) => _shortWeekdays[d.weekday - 1];

String formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

DateTime startOfWeek(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

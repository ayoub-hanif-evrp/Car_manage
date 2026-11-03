import 'package:intl/intl.dart';

final _dh = NumberFormat('#,##0.##');
final _date = DateFormat('dd/MM/yyyy');
final _month = DateFormat('MMM yyyy');
final _time = DateFormat('HH:mm');

String formatDh(double value) => '${_dh.format(value)} DH';

String formatLiters(double value) => '${_dh.format(value)} L';

String formatKm(double value) => '${_dh.format(value)} km';

String formatDate(DateTime value) => _date.format(value);

String formatMonth(DateTime value) => _month.format(value);

String formatTime(DateTime value) => _time.format(value);

String formatLPer100(double? value) {
  if (value == null || value.isNaN) return 'Not enough data';
  return '${value.toStringAsFixed(1)} L/100 km';
}

String formatCostPerKm(double? value) {
  if (value == null || value.isNaN) return 'Not enough data';
  return '${value.toStringAsFixed(2)} DH/km';
}

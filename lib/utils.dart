import 'package:intl/intl.dart';

String formatPoints(num points) {
  if (points >= 1000000) {
    return '${(points / 1000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}M';
  } else if (points >= 1000) {
    return '${(points / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}k';
  } else {
    return points.toInt().toString();
  }
}

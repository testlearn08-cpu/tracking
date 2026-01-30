String localDateKolkataYmd([DateTime? now]) {
  final utc = (now ?? DateTime.now()).toUtc();
  final ist = utc.add(const Duration(hours: 5, minutes: 30));
  final y = ist.year.toString().padLeft(4, '0');
  final m = ist.month.toString().padLeft(2, '0');
  final d = ist.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String yesterdayKolkataYmd() {
  final utc = DateTime.now().toUtc();
  final ist = utc.add(const Duration(hours: 5, minutes: 30));
  final yest = ist.subtract(const Duration(days: 1));
  return localDateKolkataYmd(yest);
}

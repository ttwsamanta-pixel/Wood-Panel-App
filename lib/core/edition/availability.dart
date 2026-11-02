enum AccessState { available, maintenance, optionalUpdate, requiredUpdate }

class Availability {
  const Availability(
      {this.maintenance = false,
      this.maintenanceMessage =
          "We're updating our services. Please try again shortly.",
      this.updateMessage = 'A newer version of Wood & Panel is available.',
      this.androidMinimum = 0,
      this.androidLatest = 0,
      this.iosMinimum = 0,
      this.iosLatest = 0});
  final bool maintenance;
  final String maintenanceMessage, updateMessage;
  final int androidMinimum, androidLatest, iosMinimum, iosLatest;

  factory Availability.fromJson(dynamic value) {
    final map = value is Map ? value : const {};
    int number(String key) {
      final n = int.tryParse('${map[key]}') ?? 0;
      return n > 0 && n <= 999999999 ? n : 0;
    }

    String message(String key, String fallback) =>
        map[key] is String && (map[key] as String).trim().isNotEmpty
            ? map[key] as String
            : fallback;
    return Availability(
        maintenance: map['maintenance'] == true,
        maintenanceMessage: message(
            'maintenance_message', const Availability().maintenanceMessage),
        updateMessage:
            message('update_message', const Availability().updateMessage),
        androidMinimum: number('android_minimum'),
        androidLatest: number('android_latest'),
        iosMinimum: number('ios_minimum'),
        iosLatest: number('ios_latest'));
  }

  AccessState evaluate(
      {required int? build, required bool ios, required bool hasStore}) {
    if (maintenance) return AccessState.maintenance;
    // Unknown builds or missing destinations must not trap the reader.
    if (build == null || !hasStore) return AccessState.available;
    if (build < (ios ? iosMinimum : androidMinimum)) {
      return AccessState.requiredUpdate;
    }
    if (build < (ios ? iosLatest : androidLatest)) {
      return AccessState.optionalUpdate;
    }
    return AccessState.available;
  }
}

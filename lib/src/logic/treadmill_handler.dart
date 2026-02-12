class TreadmillHandler {
  double _currentSpeedKmh = 0.0;
  double _cumulativeDistanceKm = 0.0;
  double _avgSpeedKmh = 0.0; // Tracked but basic avg for now

  // Getters - defaulting to 0.0 is handled by initialization, but good to be explicit in logic if needed
  double get currentSpeedKmh => _currentSpeedKmh;
  double get cumulativeDistanceKm => _cumulativeDistanceKm;
  double get avgSpeedKmh => _avgSpeedKmh;

  // Computed properties for UI
  double get currentSpeedMph => _currentSpeedKmh * 0.621371;
  double get cumulativeDistanceMeters => _cumulativeDistanceKm * 1000;
  double get cumulativeDistanceMiles => _cumulativeDistanceKm * 0.621371;

  void updateFromWatchMessage(Map<String, dynamic> message) {
    if (message.containsKey('speed') && message['speed'] != null) {
      _currentSpeedKmh = (message['speed'] as num).toDouble();
    }

    if (message.containsKey('distance') && message['distance'] != null) {
      _cumulativeDistanceKm = (message['distance'] as num).toDouble();
    }

    // Calculate Average Speed logic if needed, or rely on watch to send it
    // For now, simple latching of current speed as "average" if that's what we have,
    // or we can implement a running average if we want to be fancy.
    // The implementation plan says "return 0.0 if missing", which we do.

    // Simple avg tracking (placeholder for now, can be improved)
    if (_currentSpeedKmh > 0) {
      _avgSpeedKmh = _currentSpeedKmh;
    }
  }

  void reset() {
    _currentSpeedKmh = 0.0;
    _cumulativeDistanceKm = 0.0;
    _avgSpeedKmh = 0.0;
  }

  // Manual override for post-workout correction
  void setDistance(double km) {
    _cumulativeDistanceKm = km;
  }
}

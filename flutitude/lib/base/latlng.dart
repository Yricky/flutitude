class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  @override
  String toString() {
    return "($latitude,$longitude)";
  }
}

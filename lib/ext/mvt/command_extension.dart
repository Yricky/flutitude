enum GeoCmd {
  moveTo,
  lineTo,
  closePath,
  unKnown,
}

extension CommandInteger on int {
  GeoCmd get commandId {
    switch (this & 0x07) {
      case 0x01:
        return GeoCmd.moveTo;
      case 0x02:
        return GeoCmd.lineTo;
      case 0x07:
        return GeoCmd.closePath;
      default:
        return GeoCmd.unKnown;
    }
  }

  int get count => this >> 3;
}

extension ParameterInteger on int {
  int get parameterValue => (this >> 1) ^ -(this & 1);
}

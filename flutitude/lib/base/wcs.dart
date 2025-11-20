import 'dart:math';
import 'latlng.dart';
import 'location.dart';

abstract class WCS {
  LatLng toLatLng(Location location);
  Location toLocation(LatLng latLng);
}

class WebMercator implements WCS {
  static const double _earthRadius = 6378137.0;
  static const double _mercatorMax = 20037508.342789244;
  
  const WebMercator();

  // 双曲正弦函数
  static double _sinh(double x) {
    return (exp(x) - exp(-x)) / 2;
  }

  @override
  LatLng toLatLng(Location location) {
    // 计算经度（直接线性映射）
    final lng = location.x * 360.0 - 180.0;
    // 计算墨卡托投影Y坐标（注意坐标系翻转）
    final yMerc = _mercatorMax * (1.0 - 2.0 * location.y);
    // 通过反双曲正切计算纬度（核心转换公式）
    final latRad = atan(_sinh(yMerc / _earthRadius));
    final lat = latRad * 180.0 / pi;

    return LatLng(lat, lng);
  }

  @override
  Location toLocation(LatLng latLng) {
    // 经度线性映射到[0,1]范围
    final x = (latLng.longitude + 180.0) / 360.0;
    // 将纬度转换为墨卡托投影坐标
    final latRad = latLng.latitude * pi / 180.0;
    final yMerc = _earthRadius * log(tan(pi / 4.0 + latRad / 2.0));
    // 将墨卡托坐标归一化并翻转Y轴
    final y = (_mercatorMax - yMerc) / (2.0 * _mercatorMax);

    return Location(x, y);
  }
}
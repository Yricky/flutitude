import 'q_tree_key.dart';

class Location {
  final double x;
  final double y;

  const Location(this.x, this.y);

  static const zero = Location(0, 0);
  static const unit = Location(1, 1);

  Location operator +(Location other) => Location(x + other.x, y + other.y);
  Location operator -(Location other) => Location(x - other.x, y - other.y);

  Location wrap({Location lt = zero, Location rb = unit}) {
    return Location(
      x.clamp(lt.x, rb.x),
      y.clamp(lt.y, rb.y),
    );
  }

  static Location fromQTreeKey(int key) {
    final depth = key.depth;
    final scale = 1 / (1 << depth);
    return Location(key.x * scale, key.y * scale);
  }

  int? toQTreeKey(int depth) {
    if (depth > 28) return null;
    final scale = 1 << depth;
    final x = (this.x * scale - 0.00001).toInt();
    final y = (this.y * scale - 0.00001).toInt();
    return QTreeKey.newKey(depth, x, y);
  }
}

extension QTreeKey on int {
  /// 节点深度 (0 ≤ depth ≤ 28)
  int get depth => (this >> 56) & 0x1F;

  /// X坐标 (0 ≤ x < 2^depth)
  int get x => (this >> 28) & 0x0FFFFFFF;

  /// Y坐标 (0 ≤ y < 2^depth)
  int get y => this & 0x0FFFFFFF;

  /// 父节点键
  int get parent {
    if (depth == 0) return -1;
    return newKey(depth - 1, x >> 1, y >> 1);
  }

  /// 左侧相邻节点
  int get left => newKey(depth, x - 1, y);

  /// 右侧相邻节点
  int get right => newKey(depth, x + 1, y);

  /// 上方相邻节点
  int get top => newKey(depth, x, y - 1);

  /// 下方相邻节点
  int get bottom => newKey(depth, x, y + 1);

  /// 左上子节点
  int get childLT {
    if (depth >= 28) return -1;
    return newKey(depth + 1, x << 1, y << 1);
  }

  /// 右上子节点
  int get childRT {
    if (depth >= 28) return -1;
    return newKey(depth + 1, (x << 1) + 1, y << 1);
  }

  /// 左下子节点
  int get childLB {
    if (depth >= 28) return -1;
    return newKey(depth + 1, x << 1, (y << 1) + 1);
  }

  /// 右下子节点
  int get childRB {
    if (depth >= 28) return -1;
    return newKey(depth + 1, (x << 1) + 1, (y << 1) + 1);
  }

  /// 根节点
  bool isRoot() => this == 0;

  bool isInvalid() => this == -1;

  /// 遍历指定区域内的所有瓦片（从右下到左上）
  static Iterable<int> walk(int lt, int rb) sync* {
    if (lt.isInvalid() || rb.isInvalid()) return;
    final depth = lt.depth;
    if (depth != rb.depth) {
      throw ArgumentError('Depth not equal');
    }

    int rowHead = rb;
    int? curr = rowHead;

    while (curr != null && !curr.isInvalid()) {
      final c = curr;
      yield c;

      if (c.x == lt.x) {
        if (c.y == lt.y) {
          curr = null;
        } else {
          rowHead = rowHead.top;
          curr = rowHead.isInvalid() ? null : rowHead;
        }
      } else {
        curr = c.left.isInvalid() ? null : c.left;
      }
    }
  }

  /// 创建新键值
  static newKey(int depth, int x, int y) {
    if (depth > 28) return -1;
    final mask = 0x0FFFFFFF >> (28 - depth);
    return (depth & 0x1F) << 56 | (x & mask) << 28 | (y & mask);
  }

  String keyString() {
    return "(z:$depth,x:$x,y:$y)";
  }
}

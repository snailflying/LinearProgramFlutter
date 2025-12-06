/// 工具函数
/// 
/// 作者: LiuZhiQiang

/// 将数字四舍五入到指定精度
/// 
/// [num] 要四舍五入的数字
/// [precision] 精度值
/// 返回四舍五入后的数字
double roundToPrecision(double num, double precision) {
  final rounding = (1.0 / precision).round();
  return ((num + double.minPositive) * rounding).round() / rounding;
}


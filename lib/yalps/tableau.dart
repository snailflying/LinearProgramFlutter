/// 单纯形表构建和操作
/// 
/// 作者: LiuZhiQiang
/// 将模型转换为单纯形表形式

import 'dart:typed_data';
import 'types.dart';

/// 单纯形表
/// 
/// matrix 是一个 2D 矩阵，表示为 1D 数组
/// 第一行 0 是目标行
/// 第一列 0 是 RHS 列
/// 位置从第一列开始编号，到最后一行结束
/// 因此，第一行中变量的位置是 width
class Tableau {
  /// 矩阵数据（一维数组表示二维矩阵）
  final Float64List matrix;
  
  /// 矩阵宽度（列数）
  final int width;
  
  /// 矩阵高度（行数）
  final int height;
  
  /// 变量在表中的位置索引
  final Int32List positionOfVariable;
  
  /// 位置上的变量索引
  final Int32List variableAtPosition;

  Tableau({
    required this.matrix,
    required this.width,
    required this.height,
    required this.positionOfVariable,
    required this.variableAtPosition,
  });
}

/// 获取表中指定位置的值
double getIndex(Tableau tableau, int row, int col) {
  return tableau.matrix[row * tableau.width + col];
}

/// 更新表中指定位置的值
void update(Tableau tableau, int row, int col, double value) {
  tableau.matrix[row * tableau.width + col] = value;
}

/// 约束边界类
class ConstraintBounds {
  int row;
  double lower;
  double upper;
  ConstraintBounds({
    required this.row,
    required this.lower,
    required this.upper,
  });
}

/// 变量的类型定义
class VariableEntry<VarKey, ConKey> {
  final VarKey key;
  final Map<ConKey, double> coefficients;
  VariableEntry(this.key, this.coefficients);
}

/// 带有额外上下文的单纯形表模型
class TableauModel<VariableKey, ConstraintKey> {
  final Tableau tableau;
  final double sign;
  final List<VariableEntry<VariableKey, ConstraintKey>> variables;
  final List<int> integers;

  TableauModel({
    required this.tableau,
    required this.sign,
    required this.variables,
    required this.integers,
  });
}

/// 将 Iterable 或 Map 转换为 Iterable
List<(K, V)> convertToIterable<K, V>(dynamic seq) {
  if (seq is Map) {
    return seq.entries.map((e) => (e.key as K, e.value as V)).toList();
  } else if (seq is Iterable) {
    return seq.map((e) {
      if (e is List && e.length == 2) {
        return (e[0] as K, e[1] as V);
      } else if (e is (K, V)) {
        return e;
      }
      throw ArgumentError('Invalid iterable element type');
    }).toList();
  }
  throw ArgumentError('Unsupported type for convertToIterable');
}

/// 将 bool 或 Iterable 转换为 Set 或 true
dynamic convertToSet<T>(dynamic set) {
  if (set == true) {
    return true;
  } else if (set == false) {
    return <T>{};
  } else if (set is Set) {
    return set;
  } else if (set is Iterable) {
    return set.toSet();
  }
  return <T>{};
}

/// 将模型转换为单纯形表模型
TableauModel<VariableKey, ConstraintKey> tableauModel<VariableKey, ConstraintKey>(
  Model<VariableKey, ConstraintKey> model,
) {
  final direction = model.direction;
  final objective = model.objective;
  final integers = model.integers;
  final binaries = model.binaries;
  final sign = direction == OptimizationDirection.minimize ? -1.0 : 1.0;

  // 转换 constraints 和 variables 为 Iterable
  final constraintsIter = convertToIterable<ConstraintKey, Constraint>(model.constraints);
  final variablesIter = convertToIterable<VariableKey, dynamic>(model.variables);
  
  // 转换 variables 为列表，并处理系数
  final variables = <VariableEntry<VariableKey, ConstraintKey>>[];
  for (final entry in variablesIter) {
    final varKey = entry.$1;
    final coeffs = entry.$2;
    Map<ConstraintKey, double> coeffMap;
    if (coeffs is Map) {
      coeffMap = coeffs.cast<ConstraintKey, double>();
    } else if (coeffs is Iterable) {
      coeffMap = <ConstraintKey, double>{};
      for (final item in coeffs) {
        if (item is List && item.length == 2) {
          coeffMap[item[0] as ConstraintKey] = item[1] as double;
        }
      }
    } else {
      throw ArgumentError('Invalid coefficients type');
    }
    variables.add(VariableEntry(varKey, coeffMap));
  }

  // 处理二进制和整数变量
  final binaryConstraintCol = <int>[];
  final ints = <int>[];
  if (integers != null || binaries != null) {
    final binaryVariables = convertToSet<VariableKey>(binaries);
    final integerVariables = binaryVariables == true ? true : convertToSet<VariableKey>(integers);
    
    for (int i = 0; i < variables.length; i++) {
      final key = variables[i].key;
      if (binaryVariables == true || 
          (binaryVariables is Set && binaryVariables.contains(key))) {
        binaryConstraintCol.add(i + 1);
        ints.add(i + 1);
      } else if (integerVariables == true || 
                 (integerVariables is Set && integerVariables.contains(key))) {
        ints.add(i + 1);
      }
    }
  }

  // 处理约束边界
  final constraints = <ConstraintKey, ConstraintBounds>{};
  for (final entry in constraintsIter) {
    final key = entry.$1;
    final constraint = entry.$2;
    final existingBounds = constraints[key];
    final lower = constraint.equal ?? constraint.min ?? double.negativeInfinity;
    final upper = constraint.equal ?? constraint.max ?? double.infinity;
    
    if (existingBounds != null) {
      existingBounds.lower = existingBounds.lower > lower ? existingBounds.lower : lower;
      existingBounds.upper = existingBounds.upper < upper ? existingBounds.upper : upper;
    } else {
      constraints[key] = ConstraintBounds(
        row: -1,
        lower: lower,
        upper: upper,
      );
    }
  }

  // 计算约束行数
  int numConstraints = 1;
  for (final bounds in constraints.values) {
    bounds.row = numConstraints;
    numConstraints += (bounds.lower.isFinite ? 1 : 0) + (bounds.upper.isFinite ? 1 : 0);
  }

  final width = variables.length + 1;
  final height = numConstraints + binaryConstraintCol.length;
  final numVars = width + height;
  final matrix = Float64List(width * height);
  final positionOfVariable = Int32List(numVars);
  final variableAtPosition = Int32List(numVars);
  final tableau = Tableau(
    matrix: matrix,
    width: width,
    height: height,
    positionOfVariable: positionOfVariable,
    variableAtPosition: variableAtPosition,
  );

  // 初始化变量位置
  for (int i = 0; i < numVars; i++) {
    positionOfVariable[i] = i;
    variableAtPosition[i] = i;
  }

  // 填充变量系数
  for (int c = 1; c < width; c++) {
    final coeffMap = variables[c - 1].coefficients;
    for (final entry in coeffMap.entries) {
      final constraintKey = entry.key;
      final coef = entry.value;
      
      if (constraintKey == objective) {
        update(tableau, 0, c, sign * coef);
      }
      
      final bounds = constraints[constraintKey];
      if (bounds != null) {
        if (bounds.upper.isFinite) {
          update(tableau, bounds.row, c, coef);
          if (bounds.lower.isFinite) {
            update(tableau, bounds.row + 1, c, -coef);
          }
        } else if (bounds.lower.isFinite) {
          update(tableau, bounds.row, c, -coef);
        }
      }
    }
  }

  // 填充约束右端项
  for (final bounds in constraints.values) {
    if (bounds.upper.isFinite) {
      update(tableau, bounds.row, 0, bounds.upper);
      if (bounds.lower.isFinite) {
        update(tableau, bounds.row + 1, 0, -bounds.lower);
      }
    } else if (bounds.lower.isFinite) {
      update(tableau, bounds.row, 0, -bounds.lower);
    }
  }

  // 添加二进制约束
  for (int b = 0; b < binaryConstraintCol.length; b++) {
    final row = numConstraints + b;
    update(tableau, row, 0, 1.0);
    update(tableau, row, binaryConstraintCol[b], 1.0);
  }

  return TableauModel(
    tableau: tableau,
    sign: sign,
    variables: variables,
    integers: ints,
  );
}

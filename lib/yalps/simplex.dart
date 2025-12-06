/// 单纯形法求解
/// 
/// 作者: LiuZhiQiang
/// 实现两阶段单纯形法

import 'types.dart';
import 'tableau.dart';
import 'util.dart';

/// 执行枢轴操作
void pivot(Tableau tableau, int row, int col) {
  final quotient = getIndex(tableau, row, col);
  final leaving = tableau.variableAtPosition[tableau.width + row];
  final entering = tableau.variableAtPosition[col];
  tableau.variableAtPosition[tableau.width + row] = entering;
  tableau.variableAtPosition[col] = leaving;
  tableau.positionOfVariable[leaving] = col;
  tableau.positionOfVariable[entering] = tableau.width + row;

  final nonZeroColumns = <int>[];
  // (1 / quotient) * R_pivot -> R_pivot
  for (int c = 0; c < tableau.width; c++) {
    final value = getIndex(tableau, row, c);
    if (value.abs() > 1e-16) {
      update(tableau, row, c, value / quotient);
      nonZeroColumns.add(c);
    } else {
      update(tableau, row, c, 0.0);
    }
  }
  update(tableau, row, col, 1.0 / quotient);

  // -M[r, col] * R_pivot + R_r -> R_r
  for (int r = 0; r < tableau.height; r++) {
    if (r == row) continue;
    final coef = getIndex(tableau, r, col);
    if (coef.abs() > 1e-16) {
      for (final c in nonZeroColumns) {
        update(tableau, r, c, getIndex(tableau, r, c) - coef * getIndex(tableau, row, c));
      }
      update(tableau, r, col, -coef / quotient);
    }
  }
}

/// 枢轴历史记录类型
typedef PivotHistory = List<(int, int)>;

/// 检查单纯形法是否遇到循环
bool hasCycle(PivotHistory history, Tableau tableau, int row, int col) {
  history.add((tableau.variableAtPosition[tableau.width + row], tableau.variableAtPosition[col]));
  // 循环的最小长度是 6
  for (int length = 6; length <= history.length ~/ 2; length++) {
    bool cycle = true;
    for (int i = 0; i < length; i++) {
      final item = history.length - 1 - i;
      final (row1, col1) = history[item];
      final (row2, col2) = history[item - length];
      if (row1 != row2 || col1 != col2) {
        cycle = false;
        break;
      }
    }
    if (cycle) return true;
  }
  return false;
}

/// 在给定基本可行解的情况下找到最优解（阶段2）
(SolutionStatus, double) phase2(Tableau tableau, Options options) {
  final pivotHistory = <(int, int)>[];
  final precision = options.precision ?? DefaultOptions.precision;
  final maxPivots = options.maxPivots ?? DefaultOptions.maxPivots;
  final checkCycles = options.checkCycles ?? DefaultOptions.checkCycles;
  
  for (int iter = 0; iter < maxPivots; iter++) {
    // 找到进入列/变量
    int col = 0;
    double value = precision;
    for (int c = 1; c < tableau.width; c++) {
      final reducedCost = getIndex(tableau, 0, c);
      if (reducedCost > value) {
        value = reducedCost;
        col = c;
      }
    }
    if (col == 0) {
      return (SolutionStatus.optimal, roundToPrecision(getIndex(tableau, 0, 0), precision));
    }

    // 找到离开行/变量
    int row = 0;
    double minRatio = double.infinity;
    for (int r = 1; r < tableau.height; r++) {
      final value = getIndex(tableau, r, col);
      if (value <= precision) continue; // 枢轴项必须为正
      final rhs = getIndex(tableau, r, 0);
      final ratio = rhs / value;
      if (ratio < minRatio) {
        row = r;
        minRatio = ratio;
        if (ratio <= precision) break; // 比率为 0，最低可能
      }
    }
    if (row == 0) return (SolutionStatus.unbounded, col.toDouble());

    if (checkCycles && hasCycle(pivotHistory, tableau, row, col)) {
      return (SolutionStatus.cycled, double.nan);
    }

    pivot(tableau, row, col);
  }
  return (SolutionStatus.cycled, double.nan);
}

/// 将单纯形表转换为基本可行解（阶段1）
(SolutionStatus, double) phase1(Tableau tableau, Options options) {
  final pivotHistory = <(int, int)>[];
  final precision = options.precision ?? DefaultOptions.precision;
  final maxPivots = options.maxPivots ?? DefaultOptions.maxPivots;
  final checkCycles = options.checkCycles ?? DefaultOptions.checkCycles;
  
  for (int iter = 0; iter < maxPivots; iter++) {
    // 找到离开行/变量
    int row = 0;
    double rhs = -precision;
    for (int r = 1; r < tableau.height; r++) {
      final value = getIndex(tableau, r, 0);
      if (value < rhs) {
        rhs = value;
        row = r;
      }
    }
    if (row == 0) return phase2(tableau, options);

    // 找到进入列/变量
    int col = 0;
    double maxRatio = double.negativeInfinity;
    for (int c = 1; c < tableau.width; c++) {
      final coefficient = getIndex(tableau, row, c);
      if (coefficient < -precision) {
        final ratio = -getIndex(tableau, 0, c) / coefficient;
        if (ratio > maxRatio) {
          maxRatio = ratio;
          col = c;
        }
      }
    }
    if (col == 0) return (SolutionStatus.infeasible, double.nan);

    if (checkCycles && hasCycle(pivotHistory, tableau, row, col)) {
      return (SolutionStatus.cycled, double.nan);
    }

    pivot(tableau, row, col);
  }
  return (SolutionStatus.cycled, double.nan);
}

/// 单纯形法主函数（导出为 simplex）
(SolutionStatus, double) simplex(Tableau tableau, Options options) {
  return phase1(tableau, options);
}


/// 分支定界法求解整数规划
/// 
/// 作者: LiuZhiQiang
/// 实现分支定界算法用于求解整数线性规划问题

import 'dart:typed_data';
import 'package:collection/priority_queue.dart';
import 'types.dart';
import 'tableau.dart';
import 'simplex.dart';

/// 缓冲区类型
class Buffer {
  final Float64List matrix;
  final Int32List positionOfVariable;
  final Int32List variableAtPosition;

  Buffer({
    required this.matrix,
    required this.positionOfVariable,
    required this.variableAtPosition,
  });
}

/// 创建缓冲区
Buffer createBuffer(int matrixLength, int posVarLength) {
  return Buffer(
    matrix: Float64List(matrixLength),
    positionOfVariable: Int32List(posVarLength),
    variableAtPosition: Int32List(posVarLength),
  );
}

/// 割约束类型 (sign, variable, value)
typedef Cut = (int, int, double);

/// 分支类型
typedef Branch = (double eval, List<Cut> cuts);

/// 从缓冲区创建带有额外割约束的新单纯形表
Tableau applyCuts(
  Tableau tableau,
  Buffer buffer,
  List<Cut> cuts,
) {
  final width = tableau.width;
  final height = tableau.height;
  
  // 复制矩阵
  buffer.matrix.setRange(0, tableau.matrix.length, tableau.matrix);
  
  // 应用割约束
  for (int i = 0; i < cuts.length; i++) {
    final cut = cuts[i];
    final sign = cut.$1;
    final variable = cut.$2;
    final value = cut.$3;
    final r = (height + i) * width;
    final pos = tableau.positionOfVariable[variable];
    
    if (pos < width) {
      buffer.matrix[r] = sign * value;
      buffer.matrix.fillRange(r + 1, r + width, 0.0);
      buffer.matrix[r + pos] = sign.toDouble();
    } else {
      final row = (pos - width) * width;
      buffer.matrix[r] = sign * (value - buffer.matrix[row]);
      for (int c = 1; c < width; c++) {
        buffer.matrix[r + c] = -sign * buffer.matrix[row + c];
      }
    }
  }

  // 复制变量位置信息
  buffer.positionOfVariable.setRange(0, tableau.positionOfVariable.length, tableau.positionOfVariable);
  buffer.variableAtPosition.setRange(0, tableau.variableAtPosition.length, tableau.variableAtPosition);
  
  final length = width + height + cuts.length;
  for (int i = width + height; i < length; i++) {
    buffer.positionOfVariable[i] = i;
    buffer.variableAtPosition[i] = i;
  }

  return Tableau(
    matrix: buffer.matrix.sublist(0, tableau.matrix.length + width * cuts.length),
    width: width,
    height: height + cuts.length,
    positionOfVariable: buffer.positionOfVariable.sublist(0, length),
    variableAtPosition: buffer.variableAtPosition.sublist(0, length),
  );
}

/// 找到具有最大分数值的整数变量
(int variable, double value, double frac) mostFractionalVar(
  Tableau tableau,
  List<int> intVars,
) {
  double highestFrac = 0.0;
  int variable = 0;
  double value = 0.0;
  
  for (int i = 0; i < intVars.length; i++) {
    final intVar = intVars[i];
    final row = tableau.positionOfVariable[intVar] - tableau.width;
    if (row < 0) continue;

    final val = getIndex(tableau, row, 0);
    final frac = (val - val.round()).abs();
    if (frac > highestFrac) {
      highestFrac = frac;
      variable = intVar;
      value = val;
    }
  }
  return (variable, value, highestFrac);
}

/// 运行分支定界算法求解整数问题
/// 需要非整数解作为输入
(TableauModel<VariableKey, ConstraintKey>, SolutionStatus, double) branchAndCut<VariableKey, ConstraintKey>(
  TableauModel<VariableKey, ConstraintKey> tabmod,
  double initResult,
  Options options,
) {
  final tableau = tabmod.tableau;
  final sign = tabmod.sign;
  final integers = tabmod.integers;
  final precision = options.precision ?? DefaultOptions.precision;
  final maxIterations = options.maxIterations ?? DefaultOptions.maxIterations;
  final tolerance = options.tolerance ?? DefaultOptions.tolerance;
  final timeout = options.timeout ?? DefaultOptions.timeout;
  
  final (initVariable, initValue, initFrac) = mostFractionalVar(tableau, integers);
  // 初始解已经是整数
  if (initFrac <= precision) {
    return (tabmod, SolutionStatus.optimal, initResult);
  }

  // 使用堆来管理分支
  final branches = PriorityQueue<Branch>((x, y) => (x.$1 - y.$1).compareTo(0));
  branches.add((initResult, [(-1, initVariable, initValue.ceil().toDouble())]));
  branches.add((initResult, [(1, initVariable, initValue.floor().toDouble())]));

  // 预留数组/缓冲区以在算法过程中重用
  // 一组缓冲区存储当前最佳解的状态
  // 另一个用于求解当前候选解
  // 一旦找到新的最佳解，两个缓冲区会"交换"
  final maxExtraRows = integers.length * 2;
  final matrixLength = tableau.matrix.length + maxExtraRows * tableau.width;
  final posVarLength = tableau.positionOfVariable.length + maxExtraRows;
  Buffer candidateBuffer = createBuffer(matrixLength, posVarLength);
  Buffer solutionBuffer = createBuffer(matrixLength, posVarLength);

  final optimalThreshold = initResult * (1.0 - sign * tolerance);
  final timeoutMs = timeout.isFinite ? timeout.toInt() : 0x7FFFFFFF;
  final stopTime = DateTime.now().millisecondsSinceEpoch + timeoutMs;
  bool timedout = timeout.isFinite && DateTime.now().millisecondsSinceEpoch >= stopTime; // 如果 options.timeout <= 0
  bool solutionFound = false;
  double bestEval = double.infinity;
  Tableau bestTableau = tableau;
  int iter = 0;

  while (iter < maxIterations && branches.isNotEmpty && bestEval >= optimalThreshold && !timedout) {
    final (relaxedEval, cuts) = branches.removeFirst();
    if (relaxedEval > bestEval) break; // 剩余分支比当前最佳解更差

    final currentTableau = applyCuts(tableau, candidateBuffer, cuts);
    final (status, result) = simplex(currentTableau, options);
    // 初始单纯形表不是无界的，添加更多割/约束不能使其变为无界
    // assert(status !== "unbounded")
    if (status == SolutionStatus.optimal && result < bestEval) {
      final (variable, value, frac) = mostFractionalVar(currentTableau, integers);
      if (frac <= precision) {
        // 解是整数
        solutionFound = true;
        bestEval = result;
        bestTableau = currentTableau;
        final temp = solutionBuffer;
        solutionBuffer = candidateBuffer;
        candidateBuffer = temp;
      } else {
        final cutsUpper = <Cut>[];
        final cutsLower = <Cut>[];
        for (int i = 0; i < cuts.length; i++) {
          final cut = cuts[i];
          final dir = cut.$1;
          final v = cut.$2;
          if (v == variable) {
            if (dir < 0) {
              cutsLower.add(cut);
            } else {
              cutsUpper.add(cut);
            }
          } else {
            cutsUpper.add(cut);
            cutsLower.add(cut);
          }
        }
        cutsLower.add((1, variable, value.floor().toDouble()));
        cutsUpper.add((-1, variable, value.ceil().toDouble()));
        branches.add((result, cutsUpper));
        branches.add((result, cutsLower));
      }
    }
    // 否则，此分支的结果比当前最佳解更差
    // 这可能是因为此分支不可行或循环
    // 无论哪种方式，跳过此分支并查看是否有其他分支有有效的、更好的解
    timedout = timeout.isFinite && DateTime.now().millisecondsSinceEpoch >= stopTime;
    iter++;
  }

  // 求解器是否"超时"？
  final unfinished = (timedout || iter >= maxIterations) && branches.isNotEmpty && bestEval >= optimalThreshold;

  final status = unfinished
      ? SolutionStatus.timedout
      : !solutionFound
          ? SolutionStatus.infeasible
          : SolutionStatus.optimal;

  return (
    TableauModel(
      tableau: bestTableau,
      sign: sign,
      variables: tabmod.variables,
      integers: tabmod.integers,
    ),
    status,
    solutionFound ? bestEval : double.nan,
  );
}


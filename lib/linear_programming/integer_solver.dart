import 'linear_program.dart';
import 'simplex_solver.dart';

// 验证和修正解，确保满足所有约束
List<double> _validateAndFixSolution(
  List<double> solution,
  LinearProgram problem,
) {
  final fixedSolution = List<double>.from(solution);
  bool hasConstraintViolation = false;
  
  for (var j = 0; j < problem.constraintMatrix.length; j++) {
    final constraintType = problem.constraintTypes[j];
    if (constraintType == ConstraintType.equal ||
        constraintType == ConstraintType.greaterThanOrEqual ||
        constraintType == ConstraintType.lessThanOrEqual) {
      final row = problem.constraintMatrix[j];
      final rhs = problem.constraintRhs[j];
      
      // 计算约束的左边值
      double leftValue = 0.0;
      for (var k = 0; k < row.length && k < fixedSolution.length; k++) {
        leftValue += row[k] * fixedSolution[k];
      }
      
      // 检查约束是否满足
      bool isSatisfied = false;
      if (constraintType == ConstraintType.equal) {
        isSatisfied = (leftValue - rhs).abs() <= 1e-6;
      } else if (constraintType == ConstraintType.greaterThanOrEqual) {
        isSatisfied = leftValue >= rhs - 1e-6;
      } else if (constraintType == ConstraintType.lessThanOrEqual) {
        isSatisfied = leftValue <= rhs + 1e-6;
      }
      
      if (!isSatisfied) {
        // 约束不满足，尝试修正
        // 找到约束中第一个非零系数，修正对应的变量
        for (var k = 0; k < row.length && k < fixedSolution.length; k++) {
          if (row[k].abs() > 1e-10) {
            // 计算其他变量的和
            double otherVarsSum = 0.0;
            for (var m = 0; m < row.length && m < fixedSolution.length; m++) {
              if (m != k) {
                otherVarsSum += row[m] * fixedSolution[m];
              }
            }
            
            // 重新计算变量k的值
            double newValue;
            if (constraintType == ConstraintType.equal) {
              newValue = (rhs - otherVarsSum) / row[k];
            } else if (constraintType == ConstraintType.greaterThanOrEqual) {
              newValue = (rhs - otherVarsSum) / row[k];
              // 确保满足 >= 约束
              if (row[k] < 0 && newValue > fixedSolution[k]) {
                newValue = fixedSolution[k];
              } else if (row[k] > 0 && newValue < fixedSolution[k]) {
                newValue = fixedSolution[k];
              }
            } else {
              newValue = (rhs - otherVarsSum) / row[k];
              // 确保满足 <= 约束
              if (row[k] < 0 && newValue < fixedSolution[k]) {
                newValue = fixedSolution[k];
              } else if (row[k] > 0 && newValue > fixedSolution[k]) {
                newValue = fixedSolution[k];
              }
            }
            
            // 检查上界和下界约束
            if (problem.upperBounds != null && k < problem.upperBounds!.length) {
              final upperBound = problem.upperBounds![k];
              if (upperBound.isFinite && newValue > upperBound + 1e-6) {
                newValue = upperBound;
              }
            }
            if (problem.lowerBounds != null && k < problem.lowerBounds!.length) {
              final lowerBound = problem.lowerBounds![k];
              if (newValue < lowerBound - 1e-6) {
                newValue = lowerBound;
              }
            }
            
            fixedSolution[k] = newValue;
            hasConstraintViolation = true;
            break; // 只修正一个变量
          }
        }
      }
    }
  }
  
  return fixedSolution;
}

/// 整数规划求解器
/// 
/// 使用分支定界法求解整数线性规划问题
class IntegerSolver {
  static const double _epsilon = 1e-6;
  static const int _maxNodes = 10000;

  /// 求解整数线性规划问题
  static LinearProgramResult solve(LinearProgram problem) {
    if (!problem.isIntegerProgram) {
      // 如果不是整数规划，直接使用单纯形法
      return SimplexSolver.solve(problem);
    }

    // 使用分支定界法
    return _branchAndBound(problem);
  }

  /// 分支定界法
  static LinearProgramResult _branchAndBound(LinearProgram problem) {
    // 优先队列（按目标函数值排序）
    final nodes = <_BranchNode>[];
    
    // 初始节点（无额外约束）
    final rootNode = _BranchNode(
      problem: problem,
      lowerBounds: problem.lowerBounds?.toList(),
      upperBounds: problem.upperBounds?.toList(),
    );
    
    nodes.add(rootNode);
    
    double? bestValue;
    List<double>? bestSolution;
    var nodesExplored = 0;

    while (nodes.isNotEmpty && nodesExplored < _maxNodes) {
      // 选择下一个节点（选择最优松弛解）
      nodes.sort((a, b) {
        if (a.relaxedValue == null) return 1;
        if (b.relaxedValue == null) return -1;
        return problem.optimizationType == OptimizationType.maximize
            ? b.relaxedValue!.compareTo(a.relaxedValue!)
            : a.relaxedValue!.compareTo(b.relaxedValue!);
      });
      
      final node = nodes.removeAt(0);
      nodesExplored++;

      // 求解松弛问题
      final relaxedProblem = _createRelaxedProblem(node);
      final relaxedResult = SimplexSolver.solve(relaxedProblem);

      final debug = const bool.fromEnvironment('DEBUG_ILP', defaultValue: false);
      if (debug && nodesExplored <= 10) {
        print('节点 $nodesExplored:');
        print('  下界: ${node.lowerBounds}');
        print('  上界: ${node.upperBounds}');
        print('  结果: ${relaxedResult.status}');
        print('  解: ${relaxedResult.solution}');
      }

      if (!relaxedResult.isOptimal) {
        // 无可行解或无界，剪枝
        continue;
      }

      node.relaxedValue = relaxedResult.optimalValue;
      node.relaxedSolution = relaxedResult.solution;

      // 检查是否应该剪枝
      if (bestValue != null) {
        final shouldPrune = problem.optimizationType == OptimizationType.maximize
            ? node.relaxedValue! <= bestValue
            : node.relaxedValue! >= bestValue;
        
        if (shouldPrune) {
          continue; // 剪枝
        }
      }

      // 检查是否所有整数变量都是整数
      final fractionalVar = _findFractionalVariable(
        node.relaxedSolution!,
        problem.integerVariables,
      );

      if (fractionalVar == null) {
        // 找到整数解，验证和修正解
        var validatedSolution = _validateAndFixSolution(
          node.relaxedSolution!,
          problem,
        );
        
        // 重新计算最优值
        double validatedValue = 0.0;
        for (var i = 0; i < problem.numVariables && i < validatedSolution.length; i++) {
          validatedValue += problem.objectiveCoefficients[i] * validatedSolution[i];
        }
        
        if (bestValue == null ||
            (problem.optimizationType == OptimizationType.maximize
                ? validatedValue > bestValue
                : validatedValue < bestValue)) {
          bestValue = validatedValue;
          bestSolution = validatedSolution;
        }
        continue;
      }

      // 分支：创建两个子节点
      final fractionalValue = node.relaxedSolution![fractionalVar];
      final floorValue = fractionalValue.floorToDouble();
      final ceilValue = fractionalValue.ceilToDouble();

      // 左分支：x <= floor
      final leftBounds = node.upperBounds?.toList() ?? List.filled(problem.numVariables, double.infinity);
      if (leftBounds[fractionalVar] > floorValue) {
        leftBounds[fractionalVar] = floorValue;
        final leftNode = _BranchNode(
          problem: problem,
          lowerBounds: node.lowerBounds?.toList(),
          upperBounds: leftBounds,
        );
        nodes.add(leftNode);
      }

      // 右分支：x >= ceil
      final rightBounds = node.lowerBounds?.toList() ?? List.filled(problem.numVariables, 0.0);
      if (rightBounds[fractionalVar] < ceilValue) {
        rightBounds[fractionalVar] = ceilValue;
        final rightNode = _BranchNode(
          problem: problem,
          lowerBounds: rightBounds,
          upperBounds: node.upperBounds?.toList(),
        );
        nodes.add(rightNode);
      }
    }

    if (bestSolution != null) {
      // 最终验证和修正解
      final finalSolution = _validateAndFixSolution(bestSolution, problem);
      double finalValue = 0.0;
      for (var i = 0; i < problem.numVariables && i < finalSolution.length; i++) {
        finalValue += problem.objectiveCoefficients[i] * finalSolution[i];
      }
      
      return LinearProgramResult.optimal(
        optimalValue: finalValue,
        solution: finalSolution,
        message: '找到整数最优解（探索了 $nodesExplored 个节点）',
      );
    }

    if (nodesExplored >= _maxNodes) {
      return LinearProgramResult.unsolved(
        message: '达到最大节点数限制（$nodesExplored 个节点）',
      );
    }

    return LinearProgramResult.infeasible(
      message: '未找到整数可行解',
    );
  }

  /// 创建松弛问题（移除整数约束）
  static LinearProgram _createRelaxedProblem(_BranchNode node) {
    return LinearProgram(
      optimizationType: node.problem.optimizationType,
      objectiveCoefficients: node.problem.objectiveCoefficients,
      constraintMatrix: node.problem.constraintMatrix,
      constraintRhs: node.problem.constraintRhs,
      constraintTypes: node.problem.constraintTypes,
      lowerBounds: node.lowerBounds,
      upperBounds: node.upperBounds,
      integerVariables: {}, // 移除整数约束
    );
  }

  /// 找到第一个非整数变量
  static int? _findFractionalVariable(
    List<double> solution,
    Set<int> integerVariables,
  ) {
    for (final idx in integerVariables) {
      if (idx < solution.length) {
        final value = solution[idx];
        final fractional = (value - value.round()).abs();
        if (fractional > _epsilon) {
          return idx;
        }
      }
    }
    return null;
  }
}

/// 分支节点
class _BranchNode {
  final LinearProgram problem;
  final List<double>? lowerBounds;
  final List<double>? upperBounds;
  double? relaxedValue;
  List<double>? relaxedSolution;

  _BranchNode({
    required this.problem,
    this.lowerBounds,
    this.upperBounds,
  });
}


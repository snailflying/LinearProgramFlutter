import 'linear_program.dart';
import 'simplex_solver.dart';

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
        // 找到整数解
        if (bestValue == null ||
            (problem.optimizationType == OptimizationType.maximize
                ? node.relaxedValue! > bestValue
                : node.relaxedValue! < bestValue)) {
          bestValue = node.relaxedValue;
          bestSolution = List.from(node.relaxedSolution!);
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
      return LinearProgramResult.optimal(
        optimalValue: bestValue!,
        solution: bestSolution,
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


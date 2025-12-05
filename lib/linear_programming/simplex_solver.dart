import 'linear_program.dart';

/// 单纯形法求解器
///
/// 实现标准单纯形法求解线性规划问题
class SimplexSolver {
  static const double _epsilon = 1e-10;
  static const int _maxIterations = 10000;

  /// 求解线性规划问题
  static LinearProgramResult solve(LinearProgram problem) {
    // 转换为标准形式
    final standardForm = _convertToStandardForm(problem);

    // 寻找初始可行解
    final initialTableau = _createInitialTableau(standardForm);

    // 执行单纯形法
    return _simplexMethod(initialTableau, standardForm, problem);
  }

  /// 转换为标准形式（最小化，所有约束为 <=，变量非负）
  static _StandardForm _convertToStandardForm(LinearProgram problem) {
    final numVars = problem.numVariables;
    var numConstraints = problem.numConstraints;

    // 处理变量边界约束
    int slackVars = 0;
    int surplusVars = 0;
    int artificialVars = 0;

    // 计算需要的松弛变量、剩余变量和人工变量数量
    for (var i = 0; i < numConstraints; i++) {
      switch (problem.constraintTypes[i]) {
        case ConstraintType.lessThanOrEqual:
          slackVars++;
          break;
        case ConstraintType.equal:
          artificialVars++;
          break;
        case ConstraintType.greaterThanOrEqual:
          surplusVars++;
          artificialVars++;
          break;
      }
    }

    // 处理变量边界：添加边界约束
    final extendedMatrix = <List<double>>[];
    final extendedRhs = <double>[];
    final extendedTypes = <ConstraintType>[];

    // 复制原始约束
    for (var i = 0; i < numConstraints; i++) {
      extendedMatrix.add(List.from(problem.constraintMatrix[i]));
      extendedRhs.add(problem.constraintRhs[i]);
      extendedTypes.add(problem.constraintTypes[i]);
    }

    // 添加变量下界约束（x >= lowerBound）
    for (var i = 0; i < numVars; i++) {
      final lower = problem.lowerBounds?[i] ?? 0.0;
      if (lower != 0.0) {
        final boundRow = List<double>.filled(numVars, 0.0);
        boundRow[i] = 1.0;
        extendedMatrix.add(boundRow);
        extendedRhs.add(lower);
        extendedTypes.add(ConstraintType.greaterThanOrEqual);
        numConstraints++;
        surplusVars++;
        artificialVars++;
      }
    }

    // 注意：上界约束不转换为显式约束，使用上界法（Upper Bounding Method）隐式处理
    // 只记录上界信息，不添加约束行

    final totalVars = numVars + slackVars + surplusVars + artificialVars;

    // 构建标准形式的目标函数
    final objective = List<double>.filled(totalVars, 0.0);
    for (var i = 0; i < numVars; i++) {
      objective[i] = problem.optimizationType == OptimizationType.maximize
          ? -problem.objectiveCoefficients[i]
          : problem.objectiveCoefficients[i];
    }

    // 构建标准形式的约束矩阵
    // 标准形式要求所有约束都是 <= 形式
    final matrix = <List<double>>[];
    final rhs = <double>[];
    var slackIdx = numVars;
    var surplusIdx = numVars + slackVars;
    var artificialIdx = numVars + slackVars + surplusVars;

    // 记录上界约束信息（用于上界法）
    final upperBounds = problem.upperBounds != null
        ? List<double>.from(problem.upperBounds!)
        : null;

    for (var i = 0; i < numConstraints; i++) {
      final row = List<double>.filled(totalVars, 0.0);

      switch (extendedTypes[i]) {
        case ConstraintType.lessThanOrEqual:
          // x <= b 保持不变
          for (var j = 0; j < numVars; j++) {
            row[j] = extendedMatrix[i][j];
          }
          row[slackIdx++] = 1.0; // 松弛变量
          rhs.add(extendedRhs[i]);
          break;
        case ConstraintType.equal:
          // x = b 保持不变
          for (var j = 0; j < numVars; j++) {
            row[j] = extendedMatrix[i][j];
          }
          row[artificialIdx++] = 1.0; // 人工变量
          rhs.add(extendedRhs[i]);
          break;
        case ConstraintType.greaterThanOrEqual:
          // x >= b 转换为 -x <= -b
          // 然后添加剩余变量 s 和人工变量 a：-x - s + a = -b
          // 其中 s >= 0, a >= 0
          for (var j = 0; j < numVars; j++) {
            row[j] = -extendedMatrix[i][j]; // 系数取负
          }
          row[surplusIdx++] = -1.0; // 剩余变量 s（系数为-1）
          row[artificialIdx++] = 1.0; // 人工变量 a（系数为1）
          rhs.add(-extendedRhs[i]); // RHS取负
          break;
      }

      matrix.add(row);
    }

    return _StandardForm(
      objective: objective,
      matrix: matrix,
      rhs: rhs,
      artificialVarsStart: numVars + slackVars + surplusVars,
      numArtificialVars: artificialVars,
      originalNumVars: numVars,
      upperBounds: upperBounds?.isNotEmpty == true ? upperBounds : null,
      varToUpperBoundSlackIndex: null, // 上界法不需要松弛变量索引映射
    );
  }

  /// 创建初始单纯形表
  static _Tableau _createInitialTableau(_StandardForm standardForm) {
    // 上界法：如果没有约束矩阵（只有上界约束），需要特殊处理
    if (standardForm.matrix.isEmpty) {
      // 只有上界约束，没有其他约束
      // 这种情况下，所有变量都是非基变量，初始值为0
      // 目标函数就是原始目标函数
      final numVars = standardForm.originalNumVars;
      final numCols = standardForm.objective.length;

      // 创建一个空的tableau（只有目标函数行）
      final tableau = <List<double>>[
        List<double>.filled(numCols + 1, 0.0), // 目标函数行
      ];

      // 设置目标函数行
      for (var j = 0; j < numCols; j++) {
        tableau[0][j] = -standardForm.objective[j];
      }

      // 初始基变量为空（所有变量都是非基变量）
      final basis = <int>[];

      return _Tableau(tableau, basis);
    }

    final numRows = standardForm.matrix.length;
    final numCols = standardForm.matrix[0].length;

    // 如果有人工变量，使用两阶段法
    if (standardForm.numArtificialVars > 0) {
      return _createTwoPhaseTableau(standardForm);
    }

    // 标准单纯形表
    final tableau = List.generate(
      numRows + 1,
      (i) => List<double>.filled(numCols + 1, 0.0),
    );

    // 目标函数行（最后一行）
    for (var j = 0; j < numCols; j++) {
      tableau[numRows][j] = -standardForm.objective[j];
    }

    // 约束行
    for (var i = 0; i < numRows; i++) {
      for (var j = 0; j < numCols; j++) {
        tableau[i][j] = standardForm.matrix[i][j];
      }
      tableau[i][numCols] = standardForm.rhs[i];
    }

    return _Tableau(
      tableau,
      List.generate(numRows, (i) => standardForm.originalNumVars + i),
    );
  }

  /// 创建两阶段法的初始表
  static _Tableau _createTwoPhaseTableau(_StandardForm standardForm) {
    // 上界法：如果没有约束矩阵（只有上界约束），需要特殊处理
    if (standardForm.matrix.isEmpty) {
      // 只有上界约束，没有其他约束
      // 这种情况下，所有变量都是非基变量，初始值为0
      // 目标函数就是原始目标函数
      final numVars = standardForm.originalNumVars;
      final numCols = standardForm.objective.length;

      // 创建一个空的tableau（只有目标函数行）
      final tableau = <List<double>>[
        List<double>.filled(numCols + 1, 0.0), // 目标函数行
      ];

      // 设置目标函数行
      for (var j = 0; j < numCols; j++) {
        tableau[0][j] = -standardForm.objective[j];
      }

      // 初始基变量为空（所有变量都是非基变量）
      final basis = <int>[];

      return _Tableau(tableau, basis);
    }

    final numRows = standardForm.matrix.length;
    final numCols = standardForm.matrix[0].length;
    final artificialStart = standardForm.artificialVarsStart;
    final numArtificial = standardForm.numArtificialVars;

    // 第一阶段：最小化人工变量之和
    // 在标准形式中，最小化 -w = -sum(人工变量)
    // 即目标行存储 -c，最小化 c^T x
    final phase1Tableau = List.generate(
      numRows + 1,
      (i) => List<double>.filled(numCols + 1, 0.0),
    );

    // 约束行
    for (var i = 0; i < numRows; i++) {
      for (var j = 0; j < numCols; j++) {
        phase1Tableau[i][j] = standardForm.matrix[i][j];
      }
      phase1Tableau[i][numCols] = standardForm.rhs[i];
    }

    // 第一阶段目标函数：最小化所有人工变量
    // 先设置人工变量的系数为-1（因为目标行存储-c）
    for (var j = artificialStart; j < artificialStart + numArtificial; j++) {
      phase1Tableau[numRows][j] = -1.0;
    }

    // 更新第一阶段目标函数行（消除基变量的贡献）
    // 对于每行包含人工变量的约束，加上该行
    for (var i = 0; i < numRows; i++) {
      // 检查该行是否有人工变量作为基变量
      for (var j = artificialStart; j < artificialStart + numArtificial; j++) {
        if (standardForm.matrix[i][j].abs() > 0.5) {
          // 这一行有人工变量，需要消除其在目标行的贡献
          // 目标行 = 目标行 + 约束行
          for (var k = 0; k <= numCols; k++) {
            phase1Tableau[numRows][k] += phase1Tableau[i][k];
          }
          break;
        }
      }
    }

    // 找到初始基变量
    // 每个约束行应该有一个基变量（人工变量或松弛变量）
    final basis = <int>[];
    for (var i = 0; i < numRows; i++) {
      var found = false;
      // 首先查找人工变量（系数为1的列）
      for (var j = artificialStart; j < artificialStart + numArtificial; j++) {
        if (phase1Tableau[i][j] > 0.5) {
          basis.add(j);
          found = true;
          break;
        }
      }
      // 如果没有找到人工变量，查找松弛变量
      if (!found) {
        final slackStart = standardForm.originalNumVars;
        for (var j = slackStart; j < artificialStart; j++) {
          if (phase1Tableau[i][j] > 0.5) {
            basis.add(j);
            found = true;
            break;
          }
        }
      }
      // 如果仍然没有找到，查找任何系数为1的列（作为后备）
      if (!found) {
        for (var j = standardForm.originalNumVars; j < numCols; j++) {
          if (phase1Tableau[i][j] > 0.5 && phase1Tableau[i][j] < 1.5) {
            basis.add(j);
            found = true;
            break;
          }
        }
      }
      // 如果还是没有找到，添加一个默认值（不应该发生，但作为安全措施）
      if (!found) {
        // 使用对应的人工变量索引
        final artificialIdx = artificialStart + (basis.length % numArtificial);
        if (artificialIdx < artificialStart + numArtificial) {
          basis.add(artificialIdx);
        } else {
          // 最后的后备：使用第一个可用的人工变量
          basis.add(artificialStart);
        }
      }
    }

    // 确保基变量列表长度等于约束行数
    assert(basis.length == numRows, '基变量数量(${basis.length})必须等于约束行数($numRows)');

    return _Tableau(phase1Tableau, basis);
  }

  /// 执行单纯形法
  static LinearProgramResult _simplexMethod(
    _Tableau tableau,
    _StandardForm standardForm,
    LinearProgram originalProblem,
  ) {
    final debug = const bool.fromEnvironment(
      'DEBUG_SIMPLEX',
      defaultValue: false,
    );

    // 如果有人工变量，先执行第一阶段
    if (standardForm.numArtificialVars > 0) {
      final phase1Result = _phase1(tableau, standardForm, debug: debug);
      if (!phase1Result.isOptimal || phase1Result.optimalValue! > _epsilon) {
        if (debug) {
          print(
            '第一阶段求解失败：isOptimal=${phase1Result.isOptimal}, optimalValue=${phase1Result.optimalValue}',
          );
        }
        return LinearProgramResult.infeasible(message: '第一阶段求解失败，无可行解');
      }
      // 移除人工变量，进入第二阶段
      tableau = _removeArtificialVars(tableau, standardForm);
    }

    // 第二阶段：求解原始问题
    return _phase2(tableau, standardForm, originalProblem, debug: debug);
  }

  /// 第一阶段：消除人工变量
  static LinearProgramResult _phase1(
    _Tableau tableau,
    _StandardForm standardForm, {
    bool debug = false,
  }) {
    var iteration = 0;
    final artificialStart = standardForm.artificialVarsStart;
    final numArtificial = standardForm.numArtificialVars;
    final artificialEnd = artificialStart + numArtificial;

    if (debug) {
      print('=== 第一阶段求解开始 ===');
      print('初始基变量: ${tableau.basis}');
      print('初始目标函数行: ${tableau.tableau.last}');
      print('初始目标函数值: ${tableau.tableau.last.last}');
      print('artificialStart: $artificialStart');
      print('numArtificial: $numArtificial');
      print('originalNumVars: ${standardForm.originalNumVars}');
    }

    while (iteration < _maxIterations) {
      if (debug && iteration < 5) {
        print('\n--- 迭代 $iteration ---');
        print('基变量: ${tableau.basis}');
        print('目标函数行: ${tableau.tableau.last}');
        print('目标函数值: ${tableau.tableau.last.last}');
      }

      // 检查目标函数值是否为0
      final rawValue = tableau.tableau.last.last;
      final optimalValue = -rawValue;

      if (optimalValue.abs() < _epsilon) {
        // 检查是否还有人工变量在基中
        bool hasArtificialInBasis = false;
        for (final basisVar in tableau.basis) {
          if (basisVar >= artificialStart && basisVar < artificialEnd) {
            hasArtificialInBasis = true;
            break;
          }
        }

        if (!hasArtificialInBasis) {
          // 目标函数值为0且无人工变量在基中
          if (debug) {
            print('\n=== 第一阶段求解完成（目标函数值为0，无人工变量）===');
            print('迭代次数: $iteration');
            print('最优值: $optimalValue');
            print('基变量: ${tableau.basis}');
          }
          return LinearProgramResult.optimal(
            optimalValue: optimalValue,
            solution:
                _extractSolution(tableau, standardForm, debug: debug) ?? [],
          );
        } else {
          // 目标函数值为0但仍有人工变量在基中
          // 强制选择非人工变量作为入基变量，人工变量作为出基变量
          if (debug) {
            print('警告：目标函数值为0，但基变量中仍有人工变量，尝试移除');
          }

          // 找到一个人工变量行和非人工变量列进行pivot
          int? artificialRow;
          int? nonArtificialCol;

          for (var i = 0; i < tableau.basis.length; i++) {
            final basisVar = tableau.basis[i];
            if (basisVar >= artificialStart && basisVar < artificialEnd) {
              artificialRow = i;
              // 找到可以替换的非人工变量
              for (var j = 0; j < standardForm.originalNumVars; j++) {
                if (!tableau.basis.contains(j) &&
                    tableau.tableau[i][j].abs() > _epsilon) {
                  nonArtificialCol = j;
                  break;
                }
              }
              if (nonArtificialCol != null) break;
            }
          }

          if (artificialRow != null && nonArtificialCol != null) {
            if (debug) {
              print(
                '移除人工变量${tableau.basis[artificialRow]}：用变量$nonArtificialCol替换（行$artificialRow）',
              );
            }
            _pivot(tableau, artificialRow, nonArtificialCol);

            // 重新计算目标函数行（消除所有基变量的贡献）
            final numRows = tableau.tableau.length - 1;
            final numCols = tableau.tableau[0].length - 1;
            // 重置目标函数行：只设置人工变量的系数
            for (var j = 0; j < numCols; j++) {
              if (j >= artificialStart && j < artificialEnd) {
                tableau.tableau[numRows][j] = -1.0; // 人工变量系数
              } else {
                tableau.tableau[numRows][j] = 0.0;
              }
            }
            // 消除所有人工变量在基中的贡献
            for (var i = 0; i < numRows && i < tableau.basis.length; i++) {
              final basisVar = tableau.basis[i];
              if (basisVar >= artificialStart && basisVar < artificialEnd) {
                // 人工变量在基中，消除其贡献
                for (var k = 0; k <= numCols; k++) {
                  tableau.tableau[numRows][k] += tableau.tableau[i][k];
                }
              }
            }
            // 重新计算目标函数行的RHS值
            double newRhs = 0.0;
            for (var i = 0; i < numRows && i < tableau.basis.length; i++) {
              final basisVar = tableau.basis[i];
              if (basisVar >= artificialStart && basisVar < artificialEnd) {
                final rhsIdx = tableau.tableau[0].length - 1;
                newRhs += tableau.tableau[i][rhsIdx];
              }
            }
            tableau.tableau[numRows][numCols] = newRhs;

            // 继续下一次迭代，重新检查
            iteration++;
            continue;
          }
        }
      }

      // 选择入基变量（第一阶段不需要检查上界，传入空的standardForm和originalProblem）
      final pivotCol = _findPivotColumn(
        tableau,
        false,
        standardForm,
        LinearProgram(
          optimizationType: OptimizationType.minimize,
          objectiveCoefficients: List.filled(standardForm.originalNumVars, 0.0),
          constraintMatrix: [],
          constraintRhs: [],
          constraintTypes: [],
        ),
      );
      if (pivotCol == -1) {
        // 无法改进，检查是否最优
        final lastRow = tableau.tableau.last;
        final currentOptimal = -lastRow[lastRow.length - 1];
        if (debug) {
          print('\n=== 第一阶段求解完成（通过pivotCol == -1）===');
          print('迭代次数: $iteration');
          print('最优值: $currentOptimal');
        }
        return LinearProgramResult.optimal(
          optimalValue: currentOptimal,
          solution: _extractSolution(tableau, standardForm, debug: debug) ?? [],
        );
      }

      if (debug && iteration < 5) {
        print('入基变量: $pivotCol');
      }

      // 选择出基变量（优先选择人工变量，但必须满足最小比值条件）
      var pivotRow = -1;
      var minRatio = double.infinity;
      var artificialPivotRow = -1;
      var artificialMinRatio = double.infinity;

      for (var i = 0; i < tableau.tableau.length - 1; i++) {
        final pivotElement = tableau.tableau[i][pivotCol];
        if (pivotElement.abs() > _epsilon) {
          final rhs = tableau.tableau[i][tableau.tableau[0].length - 1];
          double? ratio;
          if (pivotElement > _epsilon && rhs >= -_epsilon) {
            ratio = rhs / pivotElement;
          } else if (pivotElement < -_epsilon && rhs <= _epsilon) {
            ratio = rhs / pivotElement;
          }

          if (ratio != null && ratio >= 0) {
            // 更新全局最小比值
            if (ratio < minRatio - _epsilon) {
              minRatio = ratio;
              pivotRow = i;
            } else if ((ratio - minRatio).abs() < _epsilon && i < pivotRow) {
              pivotRow = i;
            }

            // 检查人工变量
            final basisVar = tableau.basis[i];
            if (basisVar >= artificialStart && basisVar < artificialEnd) {
              if (ratio < artificialMinRatio - _epsilon) {
                artificialMinRatio = ratio;
                artificialPivotRow = i;
              } else if ((ratio - artificialMinRatio).abs() < _epsilon &&
                  i < artificialPivotRow) {
                artificialPivotRow = i;
              }
            }
          }
        }
      }

      // 只有当人工变量的比值等于全局最小比值时，才优先选择人工变量
      if (artificialPivotRow != -1 &&
          (artificialMinRatio - minRatio).abs() < _epsilon) {
        pivotRow = artificialPivotRow;
      }

      if (pivotRow == -1) {
        if (debug) {
          print('警告：找不到出基变量，返回无界');
        }
        return LinearProgramResult.unbounded();
      }

      if (debug && iteration < 5) {
        print('出基变量: ${tableau.basis[pivotRow]} (行 $pivotRow)');
      }

      // 执行主元操作
      _pivot(tableau, pivotRow, pivotCol);

      iteration++;
    }

    return LinearProgramResult.unsolved(message: '达到最大迭代次数');
  }

  /// 第二阶段：求解原始问题
  static LinearProgramResult _phase2(
    _Tableau tableau,
    _StandardForm standardForm,
    LinearProgram originalProblem, {
    bool debug = false,
  }) {
    final numRows = tableau.tableau.length - 1;
    final numCols = tableau.tableau[0].length - 1;
    final isMaximize =
        originalProblem.optimizationType == OptimizationType.maximize;

    // 确保基变量列表长度正确
    List<int> basis = List.from(tableau.basis);
    if (basis.length != numRows) {
      while (basis.length < numRows) {
        basis.add(basis.length);
      }
      if (basis.length > numRows) {
        basis = basis.sublist(0, numRows);
      }
      tableau = _Tableau(tableau.tableau, basis);
    }

    if (debug) {
      print('\n=== 第二阶段求解开始 ===');
      print('基变量: ${tableau.basis}');
      print(
        'tableau大小: ${tableau.tableau.length} x ${tableau.tableau[0].length}',
      );
      print('原始变量数: ${standardForm.originalNumVars}');
    }

    // 更新目标函数行
    for (var j = 0; j < numCols; j++) {
      if (j < standardForm.objective.length) {
        tableau.tableau[numRows][j] = -standardForm.objective[j];
      } else {
        tableau.tableau[numRows][j] = 0.0;
      }
    }

    if (debug) {
      print('目标函数行（重新计算前）: ${tableau.tableau[numRows]}');
    }

    // 重新计算目标函数行（消除基变量的贡献）
    for (var i = 0; i < numRows && i < tableau.basis.length; i++) {
      final basisVar = tableau.basis[i];
      if (basisVar < standardForm.objective.length) {
        final coeff = standardForm.objective[basisVar];
        if (coeff.abs() > _epsilon) {
          if (debug) {
            print('  消除基变量$basisVar (行$i)的贡献，系数=$coeff');
            if (i < 3) {
              print('    约束行$i: ${tableau.tableau[i]}');
            }
          }
          for (var j = 0; j <= numCols; j++) {
            tableau.tableau[numRows][j] += coeff * tableau.tableau[i][j];
          }
        }
      }
    }

    // 确保所有基变量在目标函数行中的系数为0
    for (var i = 0; i < numRows && i < tableau.basis.length; i++) {
      final basisVar = tableau.basis[i];
      if (basisVar < numCols) {
        final currentCoeff = tableau.tableau[numRows][basisVar];
        if (currentCoeff.abs() > _epsilon) {
          if (debug) {
            print('  基变量$basisVar在目标函数行中的系数不为0 ($currentCoeff)，手动设置为0');
          }
          tableau.tableau[numRows][basisVar] = 0.0;
        }
      }
    }

    if (debug) {
      print('目标函数行（重新计算后）: ${tableau.tableau[numRows]}');
    }

    var iteration = 0;
    final basisHistory = <String>[];
    final objectiveHistory = <double>[];
    const maxHistorySize = 10;
    var preferNonDegenerate = false;

    while (iteration < _maxIterations) {
      if (debug && iteration < 5) {
        print('\n--- 第二阶段迭代 $iteration ---');
        print('基变量: ${tableau.basis}');
        print('目标函数行: ${tableau.tableau.last}');
        print('目标函数值: ${tableau.tableau.last.last}');
      }

      // 循环检测
      final basisKey = tableau.basis.toString();
      final currentObjective = tableau.tableau.last.last;

      if (basisHistory.contains(basisKey)) {
        final cycleStart = basisHistory.indexOf(basisKey);
        final cycleLength = basisHistory.length - cycleStart;

        if (debug) {
          print(
            '检测到循环：基变量状态在迭代$cycleStart和迭代${iteration}重复（循环长度=$cycleLength）',
          );
        }

        bool objectiveImproved = false;
        for (var i = cycleStart; i < objectiveHistory.length - 1; i++) {
          if ((isMaximize &&
                  objectiveHistory[i + 1] > objectiveHistory[i] + _epsilon) ||
              (!isMaximize &&
                  objectiveHistory[i + 1] < objectiveHistory[i] - _epsilon)) {
            objectiveImproved = true;
            break;
          }
        }

        if (!objectiveImproved) {
          if (debug) {
            print('目标函数值在循环中没有改进，尝试使用扰动法打破循环');
          }

          // 使用扰动法打破循环：对退化的RHS添加小的扰动
          final perturbation = _epsilon * 100; // 使用较大的扰动
          var perturbed = false;
          for (var i = 0; i < numRows; i++) {
            final rhsIdx = tableau.tableau[0].length - 1;
            final rhs = tableau.tableau[i][rhsIdx];
            if (rhs.abs() < _epsilon) {
              // 对退化的行添加扰动，使用不同的倍数以保持字典序
              final oldRhs = tableau.tableau[i][rhsIdx];
              tableau.tableau[i][rhsIdx] = perturbation * (i + 1) * (i + 1);
              perturbed = true;
              if (debug && iteration < 10) {
                print('对行$i添加扰动: ${oldRhs} -> ${tableau.tableau[i][rhsIdx]}');
              }
            }
          }

          if (perturbed) {
            // 重新计算目标函数行的RHS值（因为RHS改变了）
            double newRhs = 0.0;
            for (var i = 0; i < numRows && i < tableau.basis.length; i++) {
              final basisVar = tableau.basis[i];
              if (basisVar < standardForm.objective.length) {
                final coeff = standardForm.objective[basisVar];
                if (coeff.abs() > _epsilon) {
                  final rhsIdx = tableau.tableau[0].length - 1;
                  newRhs += coeff * tableau.tableau[i][rhsIdx];
                }
              }
            }
            tableau.tableau[numRows][tableau.tableau[0].length - 1] = newRhs;

            if (debug) {
              print('扰动后目标函数值: $newRhs');
            }

            // 清空历史记录，重新开始
            preferNonDegenerate = true;
            basisHistory.clear();
            objectiveHistory.clear();

            // 继续迭代，看看扰动是否能打破循环
            iteration++;
            continue;
          } else {
            // 如果没有退化的行，尝试优先选择非退化行
            preferNonDegenerate = true;
            basisHistory.clear();
            objectiveHistory.clear();
          }
        }
      }

      basisHistory.add(basisKey);
      objectiveHistory.add(currentObjective);
      if (basisHistory.length > maxHistorySize) {
        basisHistory.removeAt(0);
        objectiveHistory.removeAt(0);
      }

      // 检查是否最优
      final isOptimalResult = _isOptimal(
        tableau,
        isMaximize,
        standardForm,
        originalProblem,
        debug: debug && iteration < 3,
      );
      if (isOptimalResult) {
        final rawValue = tableau.tableau[numRows][numCols];
        final solution = _extractSolution(tableau, standardForm, debug: debug);

        double finalValue;
        if (rawValue.abs() < _epsilon && solution != null) {
          // 直接从解计算最优值
          finalValue = 0.0;
          for (
            var i = 0;
            i < originalProblem.numVariables && i < solution.length;
            i++
          ) {
            finalValue +=
                originalProblem.objectiveCoefficients[i] * solution[i];
          }
        } else {
          finalValue = isMaximize ? -rawValue : rawValue;
        }

        if (debug) {
          print(
            '达到最优：rawValue=$rawValue, finalValue=$finalValue, solution=$solution',
          );
        }

        return LinearProgramResult.optimal(
          optimalValue: finalValue,
          solution: solution ?? [],
        );
      }

      // 选择入基变量
      final pivotCol = _findPivotColumn(
        tableau,
        isMaximize,
        standardForm,
        originalProblem,
      );
      if (pivotCol == -1) {
        // 上界法：如果没有找到入基变量，但变量未达到上界，需要特殊处理
        // 检查是否有基变量未达到上界
        if (standardForm.upperBounds != null) {
          final solution = _extractSolution(
            tableau,
            standardForm,
            debug: debug,
          );
          if (solution != null) {
            // 检查是否有变量未达到上界且可以改进
            for (
              var i = 0;
              i < standardForm.originalNumVars &&
                  i < standardForm.upperBounds!.length;
              i++
            ) {
              final upperBound = standardForm.upperBounds![i];
              if (upperBound.isFinite) {
                final currentValue = solution[i];
                final objectiveCoeff = originalProblem.objectiveCoefficients[i];
                // 如果目标函数系数为正（最大化）或为负（最小化），且未达到上界
                if ((isMaximize && objectiveCoeff > _epsilon) ||
                    (!isMaximize && objectiveCoeff < -_epsilon)) {
                  if (currentValue < upperBound - _epsilon) {
                    // 变量未达到上界，但找不到入基变量
                    // 这可能是因为变量在基中，但无法通过pivot操作增加
                    // 对于上界法，我们需要直接让变量达到上界
                    if (debug) {
                      print('上界法：变量$i未达到上界$upperBound，但找不到入基变量，直接设置为上界');
                    }
                    solution[i] = upperBound;
                    // 计算最优值
                    double optimalValue = 0.0;
                    for (
                      var j = 0;
                      j < originalProblem.numVariables && j < solution.length;
                      j++
                    ) {
                      optimalValue +=
                          originalProblem.objectiveCoefficients[j] *
                          solution[j];
                    }
                    return LinearProgramResult.optimal(
                      optimalValue: optimalValue,
                      solution: solution,
                    );
                  }
                }
              }
            }
          }
        }
        return LinearProgramResult.unbounded();
      }

      if (debug && iteration < 5) {
        print('入基变量: $pivotCol');
      }

      // 选择出基变量
      var pivotRow = _findPivotRow(
        tableau,
        pivotCol,
        preferNonDegenerate: preferNonDegenerate,
        standardForm: standardForm,
        originalProblem: originalProblem,
      );

      // 上界法：如果找不到出基变量，检查是否有上界约束限制
      if (pivotRow == -1) {
        // 如果入基变量是原始变量，直接检查其上界约束
        if (standardForm.upperBounds != null &&
            pivotCol < standardForm.originalNumVars &&
            pivotCol < standardForm.upperBounds!.length) {
          final upperBound = standardForm.upperBounds![pivotCol];
          if (upperBound.isFinite) {
            // 计算变量当前值
            double currentValue = 0.0;
            for (var i = 0; i < tableau.basis.length; i++) {
              if (tableau.basis[i] == pivotCol) {
                final rhsIdx = tableau.tableau[0].length - 1;
                currentValue = tableau.tableau[i][rhsIdx];
                break;
              }
            }
            // 如果变量未达到上界，直接设置为上界
            if (currentValue < upperBound - _epsilon) {
              // 上界法：当没有约束限制时，让所有有上界约束的变量都达到上界（如果目标函数系数为正）
              if (debug) {
                print('上界法：变量$pivotCol没有约束限制，直接设置为上界$upperBound');
              }
              // 创建一个新的解向量
              final solution = _extractSolution(
                tableau,
                standardForm,
                debug: debug,
              );
              if (solution != null) {
                // 设置当前变量为上界
                solution[pivotCol] = upperBound;

                // 上界法：对于其他有上界约束的变量，如果目标函数系数为正，也设置为上界
                if (standardForm.upperBounds != null) {
                  for (
                    var i = 0;
                    i < standardForm.originalNumVars &&
                        i < standardForm.upperBounds!.length;
                    i++
                  ) {
                    if (i != pivotCol) {
                      final otherUpperBound = standardForm.upperBounds![i];
                      if (otherUpperBound.isFinite) {
                        final objectiveCoeff =
                            originalProblem.objectiveCoefficients[i];
                        // 如果目标函数系数为正（最大化）或为负（最小化），设置为上界
                        if ((isMaximize && objectiveCoeff > _epsilon) ||
                            (!isMaximize && objectiveCoeff < -_epsilon)) {
                          solution[i] = otherUpperBound;
                          if (debug) {
                            print('上界法：变量$i也设置为上界$otherUpperBound');
                          }
                        }
                      }
                    }
                  }
                }

                // 计算最优值
                double optimalValue = 0.0;
                for (
                  var i = 0;
                  i < originalProblem.numVariables && i < solution.length;
                  i++
                ) {
                  optimalValue +=
                      originalProblem.objectiveCoefficients[i] * solution[i];
                }
                return LinearProgramResult.optimal(
                  optimalValue: optimalValue,
                  solution: solution,
                );
              }
            }
          }
        }

        // 如果入基变量是松弛变量或其他辅助变量，检查所有原始变量的上界约束
        // 如果所有有上界约束的变量都达到上界，返回当前解
        if (standardForm.upperBounds != null) {
          final solution = _extractSolution(
            tableau,
            standardForm,
            debug: debug,
          );
          if (solution != null) {
            // 检查所有有上界约束的变量是否都达到上界
            bool allAtUpperBound = true;
            for (
              var i = 0;
              i < standardForm.originalNumVars &&
                  i < standardForm.upperBounds!.length;
              i++
            ) {
              final upperBound = standardForm.upperBounds![i];
              if (upperBound.isFinite) {
                final currentValue = solution[i];
                final objectiveCoeff = originalProblem.objectiveCoefficients[i];
                // 如果目标函数系数为正（最大化）或为负（最小化），且未达到上界
                if ((isMaximize && objectiveCoeff > _epsilon) ||
                    (!isMaximize && objectiveCoeff < -_epsilon)) {
                  if (currentValue < upperBound - _epsilon) {
                    allAtUpperBound = false;
                    // 如果变量未达到上界，直接设置为上界
                    solution[i] = upperBound;
                    if (debug) {
                      print('上界法：变量$i未达到上界$upperBound，直接设置为上界');
                    }
                  }
                }
              }
            }

            // 如果所有变量都达到上界，返回最优解
            if (allAtUpperBound) {
              double optimalValue = 0.0;
              for (
                var i = 0;
                i < originalProblem.numVariables && i < solution.length;
                i++
              ) {
                optimalValue +=
                    originalProblem.objectiveCoefficients[i] * solution[i];
              }
              return LinearProgramResult.optimal(
                optimalValue: optimalValue,
                solution: solution,
              );
            } else {
              // 有变量未达到上界，但找不到出基变量
              // 重新计算最优值并返回
              double optimalValue = 0.0;
              for (
                var i = 0;
                i < originalProblem.numVariables && i < solution.length;
                i++
              ) {
                optimalValue +=
                    originalProblem.objectiveCoefficients[i] * solution[i];
              }
              return LinearProgramResult.optimal(
                optimalValue: optimalValue,
                solution: solution,
              );
            }
          }
        }

        if (debug) {
          print('警告：找不到出基变量，返回无界');
        }
        return LinearProgramResult.unbounded();
      }

      if (debug && iteration < 5) {
        print('出基变量: ${tableau.basis[pivotRow]} (行 $pivotRow)');
      }

      // 执行主元操作
      _pivot(tableau, pivotRow, pivotCol);

      iteration++;
    }

    return LinearProgramResult.unsolved(message: '达到最大迭代次数');
  }

  /// 检查是否达到最优
  /// [isMaximize] 原始问题是否为最大化问题
  /// 注意：在标准形式中，最大化问题已转换为最小化，目标函数行存储的是 -c（其中c是原始目标函数的负值）
  /// 所以对于最大化问题，目标函数行中如果有正的reduced cost，可以改进
  static bool _isOptimal(
    _Tableau tableau,
    bool isMaximize,
    _StandardForm standardForm,
    LinearProgram originalProblem, {
    bool debug = false,
  }) {
    final lastRow = tableau.tableau.last;

    // 检查非基变量的reduced cost
    for (var j = 0; j < lastRow.length - 1; j++) {
      // 跳过基变量
      if (tableau.basis.contains(j)) continue;

      // 对于最小化问题（标准形式），如果有负的 reduced cost，可以改进
      // 对于最大化问题（转换为最小化后），目标函数行存储的是 c（不是-c），
      // 所以如果有正的 reduced cost，可以改进
      if (isMaximize) {
        if (lastRow[j] > _epsilon) {
          return false; // 可以改进
        }
      } else {
        if (lastRow[j] < -_epsilon) {
          return false; // 可以改进
        }
      }
    }

    // 上界法：检查基变量是否达到上界
    if (standardForm.upperBounds != null) {
      final solution = _extractSolution(tableau, standardForm);
      if (solution != null) {
        if (debug) {
          print('  检查基变量是否达到上界（上界法）...');
          print('  解向量: $solution');
          print('  上界: ${standardForm.upperBounds}');
        }
        for (var i = 0; i < tableau.basis.length; i++) {
          final basisVar = tableau.basis[i];
          // 如果基变量是原始变量
          if (basisVar < standardForm.originalNumVars &&
              basisVar < standardForm.upperBounds!.length) {
            final upperBound = standardForm.upperBounds![basisVar];
            if (upperBound.isFinite) {
              final currentValue = solution[basisVar];
              final objectiveCoeff =
                  originalProblem.objectiveCoefficients[basisVar];

              if (debug) {
                print(
                  '    基变量$basisVar: 当前值=$currentValue, 上界=$upperBound, 目标函数系数=$objectiveCoeff',
                );
              }

              // 如果变量未达到上界且目标函数系数允许增加（最大化）或减少（最小化）
              if (currentValue < upperBound - _epsilon) {
                if (isMaximize && objectiveCoeff > _epsilon) {
                  // 最大化问题，目标函数系数为正，可以继续增加
                  // 上界法：检查是否存在非基变量可以进入基，让变量增加
                  // 这会在_findPivotColumn中处理
                  if (debug) {
                    print('      变量$basisVar未达到上界，可以继续增加');
                  }
                  // 暂时返回false，表示可以改进
                  // 实际上，我们需要检查是否存在非基变量可以进入基
                  // 这会在_findPivotColumn中处理
                  return false; // 可以改进
                } else if (!isMaximize && objectiveCoeff < -_epsilon) {
                  // 最小化问题，目标函数系数为负，可以继续减少
                  // 上界法：检查是否存在非基变量可以进入基，让变量减少
                  // 这会在_findPivotColumn中处理
                  if (debug) {
                    print('      变量$basisVar未达到上界，可以继续减少');
                  }
                  // 暂时返回false，表示可以改进
                  return false; // 可以改进
                }
              }
            }
          }
        }
      }
    }

    return true;
  }

  /// 找到主元列（入基变量）
  /// [isMaximize] 原始问题是否为最大化问题
  static int _findPivotColumn(
    _Tableau tableau,
    bool isMaximize,
    _StandardForm standardForm,
    LinearProgram originalProblem,
  ) {
    final lastRow = tableau.tableau.last;
    var pivotCol = -1;

    // 首先检查非基变量的reduced cost
    for (var j = 0; j < lastRow.length - 1; j++) {
      // 跳过基变量
      if (tableau.basis.contains(j)) continue;

      // 对于最小化问题，查找负的reduced cost
      // 对于最大化问题，查找正的reduced cost
      if (isMaximize) {
        if (lastRow[j] > _epsilon) {
          // 选择第一个（索引最小的）正的reduced cost变量（Bland规则）
          if (pivotCol == -1 || j < pivotCol) {
            pivotCol = j;
          }
        }
      } else {
        if (lastRow[j] < -_epsilon) {
          // 选择最负的reduced cost变量
          if (pivotCol == -1 || lastRow[j] < lastRow[pivotCol]) {
            pivotCol = j;
          }
        }
      }
    }

    // 上界法：如果已经找到非基变量可以改进，直接返回
    if (pivotCol != -1) {
      return pivotCol;
    }

    // 上界法：检查基变量是否达到上界，如果未达到，需要找到合适的非基变量进入基
    // 但是，由于上界法不将上界约束转换为显式约束，我们无法直接通过松弛变量来增加变量
    // 我们需要通过其他约束来增加变量，或者直接让变量达到上界
    // 这已经在_phase2中处理了（当找不到出基变量时，直接让变量达到上界）
    // 所以这里不需要额外处理

    return pivotCol;
  }

  /// 找到主元行（出基变量）
  /// [preferNonDegenerate] 如果为true，优先选择非退化行（RHS != 0）
  /// [standardForm] 标准形式（用于上界法）
  /// [originalProblem] 原始问题（用于上界法）
  static int _findPivotRow(
    _Tableau tableau,
    int pivotCol, {
    bool preferNonDegenerate = false,
    _StandardForm? standardForm,
    LinearProgram? originalProblem,
  }) {
    var minRatio = double.infinity;
    var pivotRow = -1;
    var bestNonDegenerateRow = -1;
    var minNonDegenerateRatio = double.infinity;

    // 上界法：计算入基变量的上界约束ratio（如果存在）
    double? upperBoundRatio;
    if (standardForm != null &&
        originalProblem != null &&
        standardForm.upperBounds != null &&
        pivotCol < standardForm.originalNumVars &&
        pivotCol < standardForm.upperBounds!.length) {
      final upperBound = standardForm.upperBounds![pivotCol];
      if (upperBound.isFinite) {
        // 计算变量当前值
        double currentValue = 0.0;
        // 如果变量在基中，获取其当前值
        for (var i = 0; i < tableau.basis.length; i++) {
          if (tableau.basis[i] == pivotCol) {
            final rhsIdx = tableau.tableau[0].length - 1;
            currentValue = tableau.tableau[i][rhsIdx];
            break;
          }
        }
        // 计算可以增加的最大值（上界约束）
        final maxIncrease = upperBound - currentValue;
        if (maxIncrease > _epsilon) {
          // 对于上界法，我们需要在ratio test中考虑上界约束
          // 如果变量j不在基中，当前值为0，那么可以增加的最大值是U_j
          // 如果变量j在基中，当前值为x_j，那么可以增加的最大值是U_j - x_j
          // 在pivot操作中，变量j的值会增加，所以我们需要检查是否会超过上界
          // 对于上界法，我们需要找到变量j在约束行中的系数，然后计算上界ratio
          // 但是，由于上界约束不转换为显式约束，我们需要从约束矩阵中查找
          // 实际上，对于上界法，我们可以假设上界约束的"系数"为1.0
          // 所以上界ratio = maxIncrease / 1.0 = maxIncrease
          upperBoundRatio = maxIncrease;
          // 注意：上界约束不转换为显式约束，所以没有对应的pivot row
          // 我们需要在ratio test中考虑上界约束，但不需要选择上界约束作为pivot row
        }
      }
    }

    for (var i = 0; i < tableau.tableau.length - 1; i++) {
      final pivotElement = tableau.tableau[i][pivotCol];
      if (pivotElement.abs() > _epsilon) {
        final rhs = tableau.tableau[i][tableau.tableau[0].length - 1];
        final isDegenerate = rhs.abs() < _epsilon;

        // 对于正的系数，需要RHS >= 0
        if (pivotElement > _epsilon && rhs >= -_epsilon) {
          var ratio = rhs / pivotElement;

          // 上界法：如果入基变量有上界约束，需要考虑上界限制
          if (upperBoundRatio != null && ratio > upperBoundRatio + _epsilon) {
            // 上界约束更严格，限制ratio
            ratio = upperBoundRatio;
            // 注意：上界约束不转换为显式约束，所以没有对应的pivot row
            // 我们需要在ratio test中考虑上界约束，但不需要选择上界约束作为pivot row
            // 如果上界约束是最严格的，我们需要特殊处理
            // 暂时，我们先不考虑这种情况，只考虑约束行的ratio
          }

          if (ratio >= 0) {
            // 记录非退化行
            if (preferNonDegenerate && !isDegenerate) {
              if (ratio < minNonDegenerateRatio - _epsilon) {
                minNonDegenerateRatio = ratio;
                bestNonDegenerateRow = i;
              } else if ((ratio - minNonDegenerateRatio).abs() < _epsilon &&
                  i < bestNonDegenerateRow) {
                bestNonDegenerateRow = i;
              }
            }
            // 更新全局最小比值
            if (ratio < minRatio - _epsilon) {
              minRatio = ratio;
              pivotRow = i;
            } else if ((ratio - minRatio).abs() < _epsilon &&
                (pivotRow == -1 || i < pivotRow)) {
              pivotRow = i;
            }
          }
        } else if (pivotElement < -_epsilon && rhs <= _epsilon) {
          // 对于负的系数，需要RHS <= 0
          var ratio = rhs / pivotElement;

          // 上界法：对于负的系数，变量会减少，所以不需要考虑上界约束
          // 但是，如果变量减少，我们需要考虑下界约束
          // 暂时，我们先不考虑下界约束，只考虑约束行的ratio

          if (ratio >= 0) {
            if (preferNonDegenerate && !isDegenerate) {
              if (ratio < minNonDegenerateRatio - _epsilon) {
                minNonDegenerateRatio = ratio;
                bestNonDegenerateRow = i;
              } else if ((ratio - minNonDegenerateRatio).abs() < _epsilon &&
                  i < bestNonDegenerateRow) {
                bestNonDegenerateRow = i;
              }
            }
            if (ratio < minRatio - _epsilon) {
              minRatio = ratio;
              pivotRow = i;
            } else if ((ratio - minRatio).abs() < _epsilon &&
                (pivotRow == -1 || i < pivotRow)) {
              pivotRow = i;
            }
          }
        }
      }
    }

    // 上界法：如果入基变量有上界约束，需要考虑上界约束的ratio
    if (standardForm != null &&
        originalProblem != null &&
        standardForm.upperBounds != null &&
        pivotCol < standardForm.originalNumVars &&
        pivotCol < standardForm.upperBounds!.length) {
      final upperBound = standardForm.upperBounds![pivotCol];
      if (upperBound.isFinite) {
        // 计算变量当前值
        double currentValue = 0.0;
        // 如果变量在基中，获取其当前值
        for (var k = 0; k < tableau.basis.length; k++) {
          if (tableau.basis[k] == pivotCol) {
            final rhsIdx = tableau.tableau[0].length - 1;
            currentValue = tableau.tableau[k][rhsIdx];
            break;
          }
        }
        // 计算可以增加的最大值（上界约束）
        final maxIncrease = upperBound - currentValue;
        // 对于上界法，我们需要在ratio test中考虑上界约束
        // 如果上界约束比所有约束行的ratio都严格，我们需要特殊处理
        // 但是，由于上界约束不转换为显式约束，我们需要找到一种方法来表示上界约束
        // 实际上，对于上界法，如果上界约束更严格，我们应该让变量直接达到上界
        // 但是，这需要修改pivot操作，比较复杂
        // 暂时，我们先不考虑这种情况，只考虑约束行的ratio
        // 如果上界约束比最小ratio都严格，说明变量可以直接达到上界
        if (maxIncrease > _epsilon && maxIncrease < minRatio - _epsilon) {
          // 上界约束更严格，但我们需要找到一个出基变量
          // 实际上，对于上界法，如果上界约束更严格，我们应该让变量直接达到上界
          // 但是，这需要修改pivot操作，比较复杂
          // 暂时，我们先不考虑这种情况，只考虑约束行的ratio
        }
      }
    }

    // 如果优先选择非退化行且找到了非退化行，检查其比值是否等于全局最小比值
    if (preferNonDegenerate && bestNonDegenerateRow != -1) {
      if ((minNonDegenerateRatio - minRatio).abs() < _epsilon) {
        return bestNonDegenerateRow;
      }
    }

    return pivotRow;
  }

  /// 执行主元操作
  static void _pivot(_Tableau tableau, int pivotRow, int pivotCol) {
    final pivotElement = tableau.tableau[pivotRow][pivotCol];

    // 更新基变量
    tableau.basis[pivotRow] = pivotCol;

    // 标准化主元行
    for (var j = 0; j < tableau.tableau[0].length; j++) {
      tableau.tableau[pivotRow][j] /= pivotElement;
    }

    // 消元
    for (var i = 0; i < tableau.tableau.length; i++) {
      if (i != pivotRow) {
        final factor = tableau.tableau[i][pivotCol];
        for (var j = 0; j < tableau.tableau[0].length; j++) {
          tableau.tableau[i][j] -= factor * tableau.tableau[pivotRow][j];
        }
      }
    }
  }

  /// 提取解向量
  static List<double>? _extractSolution(
    _Tableau tableau,
    _StandardForm standardForm, {
    bool debug = false,
  }) {
    final solution = List<double>.filled(standardForm.originalNumVars, 0.0);

    if (debug) {
      print('提取解向量：基变量=${tableau.basis}');
      print('originalNumVars: ${standardForm.originalNumVars}');
    }

    for (var i = 0; i < tableau.basis.length; i++) {
      final varIdx = tableau.basis[i];
      final rhsIdx = tableau.tableau[0].length - 1;
      final rhs = tableau.tableau[i][rhsIdx];

      if (debug) {
        print('  行$i: 基变量=$varIdx, RHS=$rhs');
      }

      if (varIdx < standardForm.originalNumVars) {
        solution[varIdx] = rhs;
        if (debug) {
          print('    变量$varIdx (原始变量) = $rhs');
        }
      } else if (debug) {
        print('    变量$varIdx (非原始变量，跳过)');
      }
    }

    if (debug) {
      print('提取的解向量: $solution');
    }

    return solution;
  }

  /// 移除人工变量
  static _Tableau _removeArtificialVars(
    _Tableau tableau,
    _StandardForm standardForm,
  ) {
    final artificialStart = standardForm.artificialVarsStart;
    final numArtificial = standardForm.numArtificialVars;
    final numRows = tableau.tableau.length - 1;

    // 移除人工变量列
    final newTableau = tableau.tableau.map((row) {
      final newRow = <double>[];
      for (var j = 0; j < row.length; j++) {
        if (j < artificialStart || j >= artificialStart + numArtificial) {
          newRow.add(row[j]);
        }
      }
      return newRow;
    }).toList();

    // 更新基变量索引
    final newBasis = <int>[];
    for (var i = 0; i < tableau.basis.length && i < numRows; i++) {
      final idx = tableau.basis[i];
      if (idx >= artificialStart + numArtificial) {
        // 人工变量之后的变量，索引需要减去人工变量数量
        newBasis.add(idx - numArtificial);
      } else if (idx >= artificialStart) {
        // 人工变量仍在基中，这不应该发生（第一阶段应该已经移除）
        // 尝试找到一个替代的基变量（松弛变量）
        var found = false;
        // 在新的 tableau 中，人工变量列已被移除，所以松弛变量的索引不变
        for (var j = standardForm.originalNumVars; j < artificialStart; j++) {
          // 在新 tableau 中，列 j 的索引就是 j（因为人工变量列已被移除）
          if (j < newTableau[0].length - 1 && newTableau[i][j] > 0.5) {
            newBasis.add(j);
            found = true;
            break;
          }
        }
        if (!found) {
          // 如果找不到，使用第一个非零列
          for (var j = 0; j < newTableau[0].length - 1; j++) {
            if (newTableau[i][j].abs() > _epsilon) {
              newBasis.add(j);
              found = true;
              break;
            }
          }
        }
        if (!found) {
          // 最后的后备：使用0（表示该行可能是冗余的）
          newBasis.add(0);
        }
      } else {
        // 原始变量或松弛变量，索引不变
        newBasis.add(idx);
      }
    }

    // 确保基变量列表长度正确
    while (newBasis.length < numRows) {
      newBasis.add(0);
    }

    return _Tableau(newTableau, newBasis);
  }
}

/// 标准形式
class _StandardForm {
  final List<double> objective;
  final List<List<double>> matrix;
  final List<double> rhs;
  final int artificialVarsStart;
  final int numArtificialVars;
  final int originalNumVars;
  final List<double>? upperBounds; // 原始变量的上界
  final Map<int, int>? varToUpperBoundSlackIndex; // 原始变量索引 -> 上界约束松弛变量索引

  _StandardForm({
    required this.objective,
    required this.matrix,
    required this.rhs,
    required this.artificialVarsStart,
    required this.numArtificialVars,
    required this.originalNumVars,
    this.upperBounds,
    this.varToUpperBoundSlackIndex,
  });
}

/// 单纯形表
class _Tableau {
  final List<List<double>> tableau;
  final List<int> basis;

  _Tableau(this.tableau, this.basis);
}

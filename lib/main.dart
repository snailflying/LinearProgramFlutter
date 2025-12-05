import 'package:flutter/material.dart';
import 'package:demo_flutter/linear_programming/linear_programming.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: '线性规划求解器示例'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<Map<String, dynamic>> _examples = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _runExamples();
  }

  void _runExamples() {
    setState(() {
      _isLoading = true;
      _examples.clear();
    });

    // 示例1：简单的线性规划问题（最大化）
    _runExample1();

    // 示例2：带等式约束的线性规划问题
    _runExample2();

    // 示例3：带变量边界的线性规划问题
    _runExample3();

    // 示例4：整数线性规划问题
    _runExample4();

    setState(() {
      _isLoading = false;
    });
  }

  /// 示例1：最大化问题
  void _runExample1() {
    final problem = LinearProgram(
      optimizationType: OptimizationType.maximize,
      objectiveCoefficients: [3.0, 2.0],
      constraintMatrix: [
        [1.0, 1.0],  // x + y <= 4
        [2.0, 1.0],  // 2x + y <= 6
      ],
      constraintRhs: [4.0, 6.0],
      constraintTypes: [
        ConstraintType.lessThanOrEqual,
        ConstraintType.lessThanOrEqual,
      ],
    );

    final result = SimplexSolver.solve(problem);
    _examples.add({
      'title': '示例1：最大化问题',
      'description': '目标函数: max z = 3x + 2y\n约束: x + y <= 4, 2x + y <= 6',
      'result': result,
    });
  }

  /// 示例2：带等式约束的问题
  void _runExample2() {
    final problem = LinearProgram(
      optimizationType: OptimizationType.minimize,
      objectiveCoefficients: [1.0, 2.0],
      constraintMatrix: [
        [1.0, 1.0],  // x + y = 3
        [1.0, 0.0],  // x <= 2
        [0.0, 1.0],  // y <= 2
      ],
      constraintRhs: [3.0, 2.0, 2.0],
      constraintTypes: [
        ConstraintType.equal,
        ConstraintType.lessThanOrEqual,
        ConstraintType.lessThanOrEqual,
      ],
    );

    final result = SimplexSolver.solve(problem);
    _examples.add({
      'title': '示例2：带等式约束的问题',
      'description': '目标函数: min z = x + 2y\n约束: x + y = 3, x <= 2, y <= 2',
      'result': result,
    });
  }

  /// 示例3：带变量边界的问题
  void _runExample3() {
    final problem = LinearProgram(
      optimizationType: OptimizationType.maximize,
      objectiveCoefficients: [2.0, 3.0],
      constraintMatrix: [
        [1.0, 1.0],  // x + y <= 5
      ],
      constraintRhs: [5.0],
      constraintTypes: [
        ConstraintType.lessThanOrEqual,
      ],
      lowerBounds: [0.0, 1.0],
      upperBounds: [3.0, 4.0],
    );

    final result = SimplexSolver.solve(problem);
    _examples.add({
      'title': '示例3：带变量边界的问题',
      'description': '目标函数: max z = 2x + 3y\n约束: x + y <= 5, 0 <= x <= 3, 1 <= y <= 4',
      'result': result,
    });
  }

  /// 示例4：整数线性规划问题
  void _runExample4() {
    final problem = LinearProgram(
      optimizationType: OptimizationType.maximize,
      objectiveCoefficients: [5.0, 8.0],
      constraintMatrix: [
        [1.0, 1.0],   // x + y <= 6
        [5.0, 9.0],   // 5x + 9y <= 45
      ],
      constraintRhs: [6.0, 45.0],
      constraintTypes: [
        ConstraintType.lessThanOrEqual,
        ConstraintType.lessThanOrEqual,
      ],
      integerVariables: {0, 1}, // x 和 y 都是整数
    );

    final result = IntegerSolver.solve(problem);
    _examples.add({
      'title': '示例4：整数线性规划问题',
      'description': '目标函数: max z = 5x + 8y\n约束: x + y <= 6, 5x + 9y <= 45\nx, y 为整数',
      'result': result,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runExamples,
            tooltip: '重新运行示例',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _examples.length,
              itemBuilder: (context, index) {
                final example = _examples[index];
                final result = example['result'] as LinearProgramResult;
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          example['title'] as String,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          example['description'] as String,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          '求解结果:',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text('状态: ${_getStatusText(result.status)}'),
                        Text('消息: ${result.message}'),
                        if (result.isOptimal) ...[
                          const SizedBox(height: 8),
                          Text(
                            '最优值: ${result.optimalValue?.toStringAsFixed(4)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          if (result.solution != null) ...[
                            const SizedBox(height: 8),
                            const Text('最优解:'),
                            ...result.solution!.asMap().entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.only(left: 16, top: 4),
                                child: Text(
                                  'x${entry.key + 1} = ${entry.value.toStringAsFixed(4)}',
                                ),
                              );
                            }),
                          ],
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _getStatusText(SolutionStatus status) {
    switch (status) {
      case SolutionStatus.optimal:
        return '最优解';
      case SolutionStatus.infeasible:
        return '无可行解';
      case SolutionStatus.unbounded:
        return '无界';
      case SolutionStatus.unsolved:
        return '未求解';
    }
  }
}

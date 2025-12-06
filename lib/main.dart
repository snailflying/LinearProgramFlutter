import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:demo_flutter/yalps/yalps.dart';
import 'marketing/promotion_model.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '营销活动优化',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const PromotionOptimizerPage(),
    );
  }
}

class PromotionOptimizerPage extends StatefulWidget {
  const PromotionOptimizerPage({super.key});

  @override
  State<PromotionOptimizerPage> createState() => _PromotionOptimizerPageState();
}

class _PromotionOptimizerPageState extends State<PromotionOptimizerPage> {
  final List<ProductItem> _products = [];
  final List<Promotion> _promotions = [];
  PromotionSolution? _solution;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadExample();
  }

  void _loadExample() {
    setState(() {
      _products.clear();
      _promotions.clear();

      // 示例商品
      _products.addAll([
        ProductItem(id: 'T1', name: '演唱会A-内场', price: 680, quantity: 2),
        ProductItem(id: 'T2', name: '演唱会A-看台', price: 380, quantity: 3),
        ProductItem(id: 'T3', name: '舞台剧B-普通', price: 260, quantity: 1),
        ProductItem(id: 'T4', name: '舞台剧B-VIP', price: 420, quantity: 2),
        ProductItem(id: 'T5', name: '展览C-单日票', price: 120, quantity: 4),
        ProductItem(id: 'T6', name: '展览C-双人票', price: 200, quantity: 1),
        ProductItem(id: 'T7', name: '乐园D-成人票', price: 399, quantity: 2),
        ProductItem(id: 'T8', name: '乐园D-儿童票', price: 299, quantity: 3),
        ProductItem(id: 'T9', name: '体育E-看台票', price: 480, quantity: 2),
        ProductItem(id: 'T10', name: '体育E-内场票', price: 880, quantity: 1),
      ]);

      // 示例优惠券
      _promotions.addAll([
        Promotion(
          id: 'P1',
          name: '演唱会A满2000减150',
          type: PromotionType.amountOff,
          applicableProductIds: ['T1', 'T2'],
          thresholdAmount: 2000,
          discountAmount: 150,
        ),
        Promotion(
          id: 'P2',
          name: '剧场+展览组合满1000减120',
          type: PromotionType.amountOff,
          applicableProductIds: ['T3', 'T4', 'T5', 'T6'],
          thresholdAmount: 1000,
          discountAmount: 120,
        ),
        Promotion(
          id: 'P3',
          name: '展览C/乐园D儿童 满5件减80',
          type: PromotionType.countOff,
          applicableProductIds: ['T5', 'T8'],
          thresholdCount: 5,
          discountAmount: 80,
        ),
        Promotion(
          id: 'P4',
          name: '乐园成人+体育看台 满3件减150',
          type: PromotionType.countOff,
          applicableProductIds: ['T7', 'T9'],
          thresholdCount: 3,
          discountAmount: 150,
        ),
        Promotion(
          id: 'P5',
          name: '剧场+乐园 每满3件减90',
          type: PromotionType.eachCountOff,
          applicableProductIds: ['T3', 'T4', 'T7'],
          thresholdCount: 3,
          discountAmountPerStep: 90,
        ),
        Promotion(
          id: 'P6',
          name: '高价票组合 每满1000减120',
          type: PromotionType.eachAmountOff,
          applicableProductIds: ['T1', 'T10'],
          thresholdAmount: 1000,
          discountAmountPerStep: 120,
        ),
        Promotion(
          id: 'P7',
          name: '看台+儿童+看台票 满5件打8折',
          type: PromotionType.countDiscount,
          applicableProductIds: ['T2', 'T8', 'T9'],
          thresholdCount: 5,
          discountRate: 0.8,
        ),
        Promotion(
          id: 'P8',
          name: 'VIP/双人/乐园成人 满1000打85折',
          type: PromotionType.amountDiscount,
          applicableProductIds: ['T4', 'T6', 'T7'],
          thresholdAmount: 1000,
          discountRate: 0.85,
        ),
        Promotion(
          id: 'P9',
          name: '全场 每满500减20',
          type: PromotionType.eachAmountOff,
          applicableProductIds: [
            'T1',
            'T2',
            'T3',
            'T4',
            'T5',
            'T6',
            'T7',
            'T8',
            'T9',
            'T10',
          ],
          thresholdAmount: 500,
          discountAmountPerStep: 20,
        ),
        Promotion(
          id: 'P10',
          name: 'A/B/展览 满4件每满4件减50',
          type: PromotionType.eachCountOff,
          applicableProductIds: ['T1', 'T2', 'T3', 'T4', 'T5'],
          thresholdCount: 4,
          discountAmountPerStep: 50,
        ),
      ]);
    });
  }

  void _solve() {
    if (_products.isEmpty || _promotions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请至少添加一个商品和一个优惠券')));
      return;
    }

    setState(() {
      _isLoading = true;
      _solution = null;
    });

    // 将所有商品放入一个订单（也可以支持多个订单）
    final order = Order(id: 'O1', items: _products);

    try {
      final solution = PromotionOptimizer.solve([order], _promotions);
      setState(() {
        _solution = solution;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('求解失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('营销活动优化'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadExample,
            tooltip: '加载示例',
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: _isLoading ? null : _solve,
            tooltip: '开始优化',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProductsSection(),
                  const SizedBox(height: 24),
                  _buildPromotionsSection(),
                  const SizedBox(height: 24),
                  if (_solution != null) _buildSolutionSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildProductsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '商品列表 (${_products.length})',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showAddProductDialog(),
                ),
              ],
            ),
            const Divider(),
            if (_products.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('暂无商品，点击 + 添加'),
              )
            else
              ..._products.asMap().entries.map((entry) {
                final index = entry.key;
                final product = entry.value;
                return ListTile(
                  title: Text(product.name),
                  subtitle: Text(
                    '单价: ¥${product.price.toStringAsFixed(2)}, '
                    '数量: ${product.quantity}, '
                    '小计: ¥${product.totalAmount.toStringAsFixed(2)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      setState(() {
                        _products.removeAt(index);
                        _solution = null;
                      });
                    },
                  ),
                );
              }),
            const SizedBox(height: 8),
            Text(
              '商品总金额: ¥${_products.fold<double>(0, (sum, p) => sum + p.totalAmount).toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '优惠券列表 (${_promotions.length})',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showAddPromotionDialog(),
                ),
              ],
            ),
            const Divider(),
            if (_promotions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('暂无优惠券，点击 + 添加'),
              )
            else
              ..._promotions.asMap().entries.map((entry) {
                final index = entry.key;
                final promotion = entry.value;
                return ListTile(
                  title: Text(promotion.name),
                  subtitle: Text(_getPromotionDescription(promotion)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      setState(() {
                        _promotions.removeAt(index);
                        _solution = null;
                      });
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  String _getPromotionDescription(Promotion promotion) {
    switch (promotion.type) {
      case PromotionType.amountOff:
        return '满${promotion.thresholdAmount}元减${promotion.discountAmount}元';
      case PromotionType.countOff:
        return '满${promotion.thresholdCount}件减${promotion.discountAmount}元';
      case PromotionType.eachAmountOff:
        return '每满${promotion.thresholdAmount}元减${promotion.discountAmountPerStep}元';
      case PromotionType.eachCountOff:
        return '每满${promotion.thresholdCount}件减${promotion.discountAmountPerStep}元';
      case PromotionType.amountDiscount:
        return '满${promotion.thresholdAmount}元打${(promotion.discountRate! * 10).toStringAsFixed(0)}折';
      case PromotionType.countDiscount:
        return '满${promotion.thresholdCount}件打${(promotion.discountRate! * 10).toStringAsFixed(0)}折';
    }
  }

  Widget _buildSolutionSection() {
    if (_solution == null) return const SizedBox.shrink();

    final solution = _solution!;
    final totalAmount = _products.fold<double>(
      0,
      (sum, p) => sum + p.totalAmount,
    );
    final finalAmount = totalAmount - solution.totalDiscount;

    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '优化结果',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green.shade900,
              ),
            ),
            const Divider(),
            Text(
              '求解状态: ${_getStatusText(solution.status)}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '总优惠金额: ¥${solution.totalDiscount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '原价: ¥${totalAmount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              '实付: ¥${finalAmount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 16),
            if (solution.orderPromotion.isNotEmpty) ...[
              Text(
                '订单优惠分配:',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...solution.orderPromotion.entries.map((entry) {
                final orderId = entry.key;
                final promotionId = entry.value;
                final promotion = _promotions.firstWhere(
                  (p) => p.id == promotionId,
                  orElse: () => Promotion(
                    id: '',
                    name: '无',
                    type: PromotionType.amountOff,
                    applicableProductIds: [],
                  ),
                );
                final discount = solution.promotionDiscount[promotionId] ?? 0.0;
                return ListTile(
                  dense: true,
                  title: Text('订单 $orderId'),
                  subtitle: Text(
                    promotionId != null
                        ? '使用: ${promotion.name} (优惠¥${discount.toStringAsFixed(2)})'
                        : '未使用优惠券',
                  ),
                );
              }),
            ],
            if (solution.promotionDiscount.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '各优惠券优惠明细:',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...solution.promotionDiscount.entries.map((entry) {
                final promotionId = entry.key;
                final discount = entry.value;
                final promotion = _promotions.firstWhere(
                  (p) => p.id == promotionId,
                );
                return ListTile(
                  dense: true,
                  title: Text(promotion.name),
                  trailing: Text(
                    '¥${discount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
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
      case SolutionStatus.cycled:
        return '循环';
      case SolutionStatus.timedout:
        return '超时';
    }
  }

  void _showAddProductDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final quantityController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加商品'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '商品名称'),
            ),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: '单价'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(labelText: '数量'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text;
              final price = double.tryParse(priceController.text) ?? 0.0;
              final quantity = int.tryParse(quantityController.text) ?? 1;

              if (name.isNotEmpty && price > 0 && quantity > 0) {
                setState(() {
                  _products.add(
                    ProductItem(
                      id: 'P${_products.length + 1}',
                      name: name,
                      price: price,
                      quantity: quantity,
                    ),
                  );
                  _solution = null;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showAddPromotionDialog() {
    // 简化版：这里可以扩展为完整的表单
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('请使用示例数据或扩展此功能')));
  }
}

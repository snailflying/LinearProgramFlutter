# YALPS Dart 测试套件

## 概述

这是 YALPS (Yet Another Linear Programming Solver) 的 Dart 版本测试套件，包含所有原始 TypeScript 测试用例的 Dart 翻译版本。

## 测试文件结构

```
test/yalps/
├── helpers/
│   ├── read.dart          # 测试用例读取和解析
│   ├── validate.dart      # 解验证逻辑
│   └── util.dart          # 测试工具函数
├── yalps_test.dart        # 基本功能测试
├── yalps_complete_test.dart  # 小型测试用例（43个，排除大型用例）
├── yalps_all_tests.dart   # 所有测试用例（46个，包含大型用例）
└── README.md              # 本文件
```

## 测试用例

### 小型测试用例（43个）

排除以下大型测试用例以加快测试速度：
- Monster 2
- Monster Problem
- Vendor Selection

### 所有测试用例（46个）

包含所有 YALPS 原始测试用例，包括：
- 线性规划问题
- 整数规划问题
- 混合整数规划问题
- 无界问题
- 不可行问题
- 循环检测问题

## 运行测试

### 运行所有测试用例
```bash
flutter test test/yalps/yalps_all_tests.dart
```

### 运行小型测试用例（快速）
```bash
flutter test test/yalps/yalps_complete_test.dart
```

### 运行基本功能测试
```bash
flutter test test/yalps/yalps_test.dart
```

### 运行所有 YALPS 测试
```bash
flutter test test/yalps/
```

## 测试结果

✅ **所有 46 个测试用例全部通过**

测试覆盖：
- ✅ 线性规划（LP）
- ✅ 整数规划（ILP）
- ✅ 混合整数规划（MILP）
- ✅ 无界问题
- ✅ 不可行问题
- ✅ 循环检测
- ✅ 退化问题
- ✅ 各种边界情况

## 测试用例来源

所有测试用例来自 YALPS 原始仓库：
- `docs/YALPS/tests/cases/*.json`

## 作者

LiuZhiQiang


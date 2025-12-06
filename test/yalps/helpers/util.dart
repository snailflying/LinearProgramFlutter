/// 测试工具函数
/// 
/// 作者: LiuZhiQiang

/// 获取键列表
List<K> getKeys<K, V>(List<(K, V)> array) {
  return array.map((e) => e.$1).toList();
}

/// 值映射函数
(K, V2) valueMapping<K, V1, V2>(V2 Function(V1) mapping, (K, V1) entry) {
  return (entry.$1, mapping(entry.$2));
}

/// 枚举函数
List<(int, T)> enumerate<T>(List<T> array) {
  return array.asMap().entries.map((e) => (e.key, e.value)).toList();
}

/// 延迟求值
T Function() lazy<T>(T Function() thunk) {
  T? value;
  return () {
    value ??= thunk();
    return value!;
  };
}

/// 哈希函数（基于 hash-prospector）
int prospectorHash(int n) {
  int x = n;
  x ^= x >>> 16;
  x = (x * 0x21f0aaad) & 0xFFFFFFFF;
  x ^= x >>> 15;
  x = (x * 0xd35a2d97) & 0xFFFFFFFF;
  x ^= x >>> 15;
  return x;
}

/// 字符串哈希
int hashString(String s) {
  int x = 42;
  for (int i = 0; i < s.length; i++) {
    x = prospectorHash(x ^ s.codeUnitAt(i));
  }
  return x;
}

/// 创建随机数生成器
double Function() newRand(int seed) {
  int currentSeed = seed;
  return () {
    currentSeed = (currentSeed + 0x9e3779b9) & 0xFFFFFFFF;
    return (prospectorHash(currentSeed) >>> 0) / 4294967296;
  };
}

/// 随机索引
int randomIndex(double Function() rand, List<dynamic> array, [int startingIndex = 0]) {
  return (rand() * (array.length - startingIndex)).floor() + startingIndex;
}

/// 随机元素
T randomElement<T>(double Function() rand, List<T> array) {
  return array[randomIndex(rand, array)];
}

/// Fisher-Yates shuffle 采样
List<T> sample<T>(double Function() rand, List<T> array, [int? count]) {
  final n = count ?? randomIndex(rand, array);
  final result = List<T>.from(array);
  for (int i = 0; i < n && i < result.length; i++) {
    final j = randomIndex(rand, result, i);
    final temp = result[i];
    result[i] = result[j];
    result[j] = temp;
  }
  return result.sublist(0, n < result.length ? n : result.length);
}


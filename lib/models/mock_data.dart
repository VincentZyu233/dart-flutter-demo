import 'dart:math';

final _random = Random();

const _names = [
  'Alice', 'Bob', 'Charlie', 'Diana', 'Eve', 'Frank',
  'Grace', 'Hank', 'Ivy', 'Jack', 'Kate', 'Leo',
  'Mia', 'Nathan', 'Olivia', 'Paul', 'Quinn', 'Rita',
];

const _loremWords = [
  'lorem', 'ipsum', 'dolor', 'sit', 'amet', 'consectetur',
  'adipiscing', 'elit', 'sed', 'do', 'eiusmod', 'tempor',
  'incididunt', 'ut', 'labore', 'et', 'dolore', 'magna',
  'aliqua', 'enim', 'ad', 'minim', 'veniam', 'quis',
  'nostrud', 'exercitation', 'ullamco', 'laboris', 'nisi',
];

Color randomColor() {
  return Color.fromARGB(
    255,
    _random.nextInt(200) + 55,
    _random.nextInt(200) + 55,
    _random.nextInt(200) + 55,
  );
}

String randomName() {
  return _names[_random.nextInt(_names.length)];
}

String randomSentence({int words = 10}) {
  return List.generate(
    words,
    (_) => _loremWords[_random.nextInt(_loremWords.length)],
  ).join(' ');
}

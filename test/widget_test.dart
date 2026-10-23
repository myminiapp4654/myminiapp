import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/net/server_client.dart';

void main() {
  test("Doc: bo'sh hujjat mavjud emas", () {
    expect(const Doc(null).exists, isFalse);
    expect(const Doc({'a': 1}).data(), {'a': 1});
  });
}

import 'package:map_stream/map_stream.dart';

void main() {
  final exampleMap = MapStream.from({'counter1': 0});

  final listenerAll = exampleMap.listen((mapUpdate) {
    print('listenerAll ${mapUpdate.toString()}');
  });

  final listener1 = exampleMap.listen((mapUpdate) {
    print('listener1 ${mapUpdate.toString()}');
  }, ['counter1']);

  exampleMap['counter2'] = 10;

  exampleMap.update('counter1', (value) {
    return (value ?? 0) + 5;
  });

  print(exampleMap.toString());
}

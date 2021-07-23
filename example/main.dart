import 'package:map_stream/map_stream.dart';

void main() {
  final exampleMap = MapStream.from({'counter1': 0});

  exampleMap.listen((mapUpdate) {
    print('\nListener ${mapUpdate.toString()}');
  });

  exampleMap['counter2'] = 10;

  exampleMap.updateAll((key, value) {
    return value != null ? value + 5 : null;
  });

  print(exampleMap.toString());
}

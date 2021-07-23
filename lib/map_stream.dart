/// An implementation of the **Dart Map** object, adding functionality to listen
/// to streams of entry changes.
///
/// **Asynchronous Streams** from the [dart:async] library are created by
/// listening to **MapStream**. Whenever changes occur to the **MapEntries**,
/// updates are pushed along with the current and previous versions of the map
/// in the form of **MapUpdate**.
///
/// **Streams** can be predefined during attachment to selectively listen to
/// only updates from specific keys.
///
/// All **Map** methods work as per [dart:core] **Map** documentation.
///
/// **TypeSafe** maps can only have one value type for each MapEntry. Once set,
/// if the value type is changed after its first assignment a
/// **MapTypeException** is thrown.

import 'dart:async';

/// A **Map** that supports listening to changes.
class MapStream<K, V> implements Map<K, V?> {
  /// Flag whether typeChecking is performed on updates.
  bool typeSafe = false;

  Map<K, V?> _map;
  final Map<K, V?> _defaultMap;
  final Map<K, Type> _mapTypes = {};
  final Map<K, StreamSubscription<V?>> _streamsSubscriptions = {};
  late final StreamController<MapUpdate<K, V?>> _changeStreamController;
  late final Stream<MapUpdate<K, V?>> _changeStream;

  MapStream._({
    Map<K, V?> defaultMap = const {},
    this.typeSafe = false,
  })  : _changeStreamController =
            StreamController<MapUpdate<K, V?>>.broadcast(),
        _defaultMap = defaultMap,
        _map = {...defaultMap} {
    _changeStream = _changeStreamController.stream;
  }

  /// Creates an empty **MapStream**
  MapStream() : this._();

  /// Creates a **MapStream** with the same keys and values as [other].
  MapStream.from(Map<K, V?> other)
      : this._(defaultMap: Map.unmodifiable(other));

  /// Creates a type safe **MapStream**.
  ///
  /// If [other] is passed then **MapStream** is created with the same keys
  /// and values as [other].
  MapStream.typeSafe([Map<K, V?>? other])
      : this._(
          defaultMap: other == null ? {} : Map.unmodifiable(other),
          typeSafe: true,
        );

  // Map properties

  /// The map entries of **this**.
  @override
  Iterable<MapEntry<K, V?>> get entries {
    return _map.entries;
  }

  /// Whether there is no key/value pair in the map.
  @override
  bool get isEmpty {
    return _map.isEmpty;
  }

  /// Whether there is at least one key/value pair in the map.
  @override
  bool get isNotEmpty {
    return _map.isNotEmpty;
  }

  /// The keys of **this**.
  @override
  Iterable<K> get keys {
    return _map.keys;
  }

  /// The number of key/value pairs in the map.
  @override
  int get length {
    return _map.length;
  }

  /// The values of **this**.
  @override
  Iterable<V?> get values {
    return _map.values;
  }

  // Map methods

  @override
  V? operator [](Object? key) {
    return _map[key];
  }

  /// Adds key/value pair to **this**.
  ///
  /// If the key/value pair is new or changed then a **MapUpdate** is sent to
  /// attached streams.
  @override
  void operator []=(K key, V? value) {
    addAll({key: value});
  }

  /// Adds all key/value pairs of [other] to **this**.
  ///
  /// If any key/value pairs are new or changed then a **MapUpdate** is sent to
  /// attached streams.
  @override
  void addAll(Map<K, V?> other) {
    if (isClosed) {
      throw StateError('Cannot update state stream because it is closed');
    }

    final updatedMap = _createUpdatedMap(other);

    if (updatedMap.isNotEmpty) {
      final prevMap = {..._map};
      _map.addAll(updatedMap);

      _send(updatedMap, _map, prevMap);
    }
  }

  /// Adds all key/value pairs of [newEntries] to **this**.
  ///
  /// If any key/value pairs are new or changed then a **MapUpdate** is sent to
  /// attached streams.
  @override
  void addEntries(Iterable<MapEntry<K, V?>> newEntries) {
    addAll(Map.fromEntries(newEntries));
  }

  /// Unsupported for **MapStream**
  @override
  Map<RK, RV> cast<RK, RV>() {
    throw UnsupportedError('Cannont cast MapStream');
  }

  /// Removes all entries from the map.
  ///
  /// **MapUpdate** is sent with all map values set as *null*.
  @override
  void clear() {
    addAll(map((k, v) => MapEntry(k, null)));
    _map.clear();
  }

  /// Whether this map contains the given [key].
  @override
  bool containsKey(Object? key) {
    return _map.containsKey(key);
  }

  /// Whether this map contains the given [value].
  @override
  bool containsValue(Object? value) {
    return _map.containsValue(value);
  }

  /// Applies [action] to each key/value pair of the map.
  @override
  void forEach(void Function(K key, V? value) action) {
    _map.forEach(action);
  }

  /// Returns a new **Map** where all entries of this **MapStream** are
  /// transformed by the given [convert] function.
  @override
  Map<K2, V2> map<K2, V2>(MapEntry<K2, V2> Function(K key, V? value) convert) {
    return _map.map(convert);
  }

  /// Look up the value of key, or add a new entry if it isn't there.
  ///
  /// If the key/value pair is new or changed then a **MapUpdate** is sent to
  /// attached streams.
  @override
  V? putIfAbsent(K key, V? Function() ifAbsent) {
    final currentV = this[key];

    if (currentV != null) {
      return currentV;
    }

    final newV = ifAbsent();
    this[key] = newV;
    return newV;
  }

  /// Removes key and its associated value, if present, from the map.
  ///
  /// **MapUpdate** is sent with key/value set as *null*.
  @override
  V? remove(Object? key) {
    final currentV = this[key];
    this[key as K] = null;
    _map.remove(key);
    return currentV;
  }

  /// Removes all entries of this map that satisfy the given [test].
  ///
  /// **MapUpdate** is sent with removed key/value pairs set as *null*.
  @override
  void removeWhere(bool Function(K key, V? value) test) {
    final removeEntries = entries.where((mapEntry) => test(
          mapEntry.key,
          mapEntry.value,
        ));

    final removeMap = Map.fromEntries(removeEntries.map((mapEntry) {
      return MapEntry(mapEntry.key, null);
    }));

    addAll(removeMap);
    _map.removeWhere(test);
  }

  /// Updates the value for the provided key.
  ///
  /// If the key/value pair is new or changed then a **MapUpdate** is sent to
  /// attached streams.
  @override
  V? update(
    K key,
    V? Function(V? value) update, {
    V? Function()? ifAbsent,
  }) {
    final v = this[key];

    if (v == null) {
      if (ifAbsent == null) {
        throw ArgumentError.notNull(
            'ifAbsent cannot be null if key does not exist on map');
      } else {
        final absentV = ifAbsent();
        this[key] = absentV;
        return absentV;
      }
    }
    final updatedV = update(v);
    this[key] = updatedV;
    return updatedV;
  }

  /// Updates all values.
  ///
  /// If any key/value pairs are new or changed then a **MapUpdate** is sent to
  /// attached streams.
  @override
  void updateAll(V? Function(K key, V? value) update) {
    final mapCopy = {..._map};
    mapCopy.updateAll(update);
    addAll(mapCopy);
  }

  /// Reverts key back to that in *defaultMap*.
  ///
  /// If the key/value pair changed changed then a **MapUpdate** is sent to
  /// attached streams.
  void revert(K key) {
    final currentV = _defaultMap[key];
    if (currentV == null) {
      _map.remove(key);
    } else {
      this[key] = currentV;
    }
  }

  /// Reverts all values back to *defaultMap*.
  ///
  /// If any key/value pairs are changed then a **MapUpdate** is sent to
  /// attached streams.
  void revertAll() {
    addAll(map((k, v) => MapEntry(k, _defaultMap[k])));
    _map = {..._defaultMap};
  }

  // Stream methods

  /// Adds a subscription to this **MapStream**'s stream.
  ///
  /// Optional parameter [keys] can be passed so only updates to specified
  /// keys are sent down stream.
  ///
  /// Return **StreamSubscription** can be used to close the stream.
  StreamSubscription<MapUpdate<K, V?>> listen(
    void Function(MapUpdate mapUpdate) onUpdate, [
    List? keys,
  ]) {
    if (isClosed) {
      throw StateError('Cannot listen to state stream because it is closed');
    }

    final subscribedStreamController = StreamController<MapUpdate<K, V?>>();

    final changeStreamSubscription = _changeStream.listen((mapUpdate) {
      final updatedMap = mapUpdate.updatedMap;

      if (
          // If [keys] is null then updates are always sent.
          keys == null ||
              // The only time an empty update is sent is during resendAll.
              updatedMap.isEmpty ||
              // Otherwise only sends update if it contains a listened for key.
              updatedMap.keys.any((k) => keys.contains(k))) {
        subscribedStreamController.add(mapUpdate);
      }
    });

    changeStreamSubscription.onDone(subscribedStreamController.close);

    subscribedStreamController.onCancel = () {
      changeStreamSubscription.cancel();
    };

    return subscribedStreamController.stream.listen(onUpdate);
  }

  /// Closes all attached streams.
  ///
  /// Note: Once closed **MapStream** cannot reopen. Mutating the map will no
  /// longer send updates and no new listerners can be attached
  Future close() async {
    await _changeStreamController.close();
  }

  /// Whether there are any subscribers.
  bool get hasListener {
    return _changeStreamController.hasListener;
  }

  /// Whether the stream controller is closed for adding more events.
  bool get isClosed {
    return _changeStreamController.isClosed;
  }

  /// Returns a multi-subscription stream that emits the **MapUpdate**s.
  Stream<MapUpdate<K, V?>> asBroadcastStream() {
    return _changeStream.asBroadcastStream();
  }

  /// Sends a **MapUpdate** down the stream with the [key]'s **MapEntry**
  void resend(K key) {
    _send({key: this[key]}, _map, _map);
  }

  /// Sends an empty **MapUpdate** down the stream to all attached listeners.
  void resendAll() {
    _send({}, _map, _map);
  }

  // Connect methods

  /// Connect a stream to a [key] in the map.
  ///
  /// Changes from the connected stream are propagated as a **MapUpdate** to
  /// attached listeners.
  void connect(K key, Stream<V> stream) {
    disconnect(key);
    _streamsSubscriptions[key] = stream.listen((value) => this[key] = value);
  }

  /// Disconnect a connected stream from a [key] in the map.
  void disconnect(K key) {
    final streamSubscription = _streamsSubscriptions[key];

    if (streamSubscription != null) {
      streamSubscription.cancel();
      _streamsSubscriptions.remove(key);
    }
  }

  /// Disconnect all connected streams
  void disconnectAll() {
    _streamsSubscriptions.values
        .forEach((subscription) => subscription.cancel());
  }

  // Utility methods

  void _send(
    Map<K, V?> updatedMap,
    Map<K, V?> currentMap,
    Map<K, V?> prevMap,
  ) {
    // MapUpdate only sent to stream if currently being listened to in order
    // to reduce unnecessary processing.
    if (hasListener) {
      _changeStreamController.add(MapUpdate(
        updatedMap,
        currentMap,
        prevMap,
      ));
    }
  }

  Map<K, V?> _createUpdatedMap(Map<K, V?> mapUpdate) {
    final updatedMap = Map<K, V?>();

    mapUpdate.forEach((k, v) {
      if (typeSafe) {
        _checkUpdateValueType(k, v);
      }

      if (v != _map[k]) {
        updatedMap[k] = v;
      }
    });

    return updatedMap;
  }

  void _checkUpdateValueType(K key, V? value) {
    if (value != null) {
      final expectedType = _mapTypes.putIfAbsent(key, () => value.runtimeType);
      final actualType = value.runtimeType;

      if (actualType != expectedType) {
        throw MapTypeException(key.toString(), expectedType, actualType);
      }
    }
  }

  /// Returns this **MapStream** as a **Dart Map**.
  Map<K, V?> toMap() {
    return {..._map};
  }

  /// Returns a string representation of this object.
  @override
  String toString() {
    return _map.toString();
  }
}

/// **MapStream** stream event.
class MapUpdate<K, V> {
  /// Changes to map during update.
  final Map<K, V?> updatedMap;

  /// Map before update.
  final Map<K, V?> currentMap;
  // Map after update.
  final Map<K, V?> prevMap;

  MapUpdate(this.updatedMap, this.currentMap, this.prevMap);

  @override
  String toString() {
    return '\nupdate: ${updatedMap.toString()}'
        '\nnew: ${currentMap.toString()}'
        '\nprev: ${prevMap.toString()}';
  }
}

/// Thrown by type safe **MapStream**'s are updated with entry value types that
/// conflict with exisiting type.
class MapTypeException implements Exception {
  late final String message;

  MapTypeException(String key, Type expectedType, Type actualType) {
    message = "key '$key' on StreamingMap was expected "
        'to be $expectedType instead of $actualType';

    print('Warning ' + toString());
  }

  @override
  String toString() => 'StreamingMapTypeException: $message';
}

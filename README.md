An implementation of the **Dart Map** object, adding functionality to listen to streams of entry changes.

**Asynchronous Streams** from the [dart:async] library are created by listening to **MapStream**. Whenever changes occur to the **MapEntries**, updates are pushed along with the current and previous versions of the map in the form of **MapUpdate**.

**Streams** can be predefined during attachment to selectively listen to
only updates from specific keys.

All **Map** methods work as per [dart:core] **Map** documentation.

**TypeSafe** maps can only have one value type for each **MapEntry**. Once set, if the value type is changed after its first assignment a **MapTypeException** is thrown.

See documentation for more information.

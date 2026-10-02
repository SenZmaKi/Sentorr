import 'package:flutter/widgets.dart';

/// Rebuilds [builder] with the latest value of one player stream, starting
/// from the player's current state so the first frame is never empty.
class PlayerValue<T> extends StatelessWidget {
  const PlayerValue({
    super.key,
    required this.stream,
    required this.initial,
    required this.builder,
  });

  final Stream<T> stream;
  final T initial;
  final Widget Function(BuildContext context, T value) builder;

  @override
  Widget build(BuildContext context) => StreamBuilder<T>(
    stream: stream,
    initialData: initial,
    builder: (context, snapshot) => builder(context, snapshot.data as T),
  );
}

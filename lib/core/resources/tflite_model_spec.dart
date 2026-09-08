/// Describes a bundled TFLite model: where it lives and the tensor contract it
/// expects. Interpreter code reads its shapes from here instead of hard-coding
/// magic numbers at the call site.
class TfLiteModelSpec {
  const TfLiteModelSpec({
    required this.assetPath,
    required this.inputShape,
    required this.inputRange,
    required this.outputs,
  });

  final String assetPath;

  /// `[batch, height, width, channels]`, matching the model's input tensor.
  final List<int> inputShape;

  /// Range each pixel must be normalised into before inference.
  final (double min, double max) inputRange;

  /// Output tensor name to shape, in the order the model declares them.
  final Map<String, List<int>> outputs;

  int get inputHeight => inputShape[1];

  int get inputWidth => inputShape[2];

  int get inputChannels => inputShape[3];

  /// Shape of a named output, or `null` when the model has no such tensor.
  List<int>? outputShape(String name) => outputs[name];
}

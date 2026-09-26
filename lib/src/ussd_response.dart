/// A reply to a single-response USSD request.
class UssdResponse {
  /// Creates a response.
  const UssdResponse({
    required this.request,
    required this.text,
    required this.subscriptionId,
    required this.receivedAt,
  });

  /// The normalised code that was sent, for example `*222#`.
  final String request;

  /// The text returned by the network.
  final String text;

  /// The subscription the request went through, or null for the default SIM.
  final int? subscriptionId;

  /// When the platform received the reply (UTC).
  final DateTime receivedAt;

  @override
  String toString() => 'UssdResponse($request -> "$text")';
}

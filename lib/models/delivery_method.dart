class DeliveryMethod {
  final String id;
  final String name;

  DeliveryMethod({
    required this.id,
    required this.name,
  });

  factory DeliveryMethod.fromJson(
    String id,
    String name,
  ) {
    return DeliveryMethod(
      id: id,
      name: name,
    );
  }
}

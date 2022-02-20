class OrderBy {
  final String property;
  final Order order;

  OrderBy({required this.property, required this.order});
}

enum Order { asc, desc }

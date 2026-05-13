enum AlertType { price, percent }
enum AlertDirection { above, below }

class PriceAlert {
  final String id;
  final AlertType type;
  final AlertDirection direction;
  final double value;
  final double targetPrice;

  PriceAlert({
    required this.id,
    required this.type,
    required this.direction,
    required this.value,
    required this.targetPrice,
  });

  static PriceAlert create({
    required AlertType type,
    required AlertDirection direction,
    required double value,
    required double currentPrice,
  }) {
    final double target;
    if (type == AlertType.price) {
      target = value;
    } else {
      target = direction == AlertDirection.above
          ? currentPrice * (1 + value / 100)
          : currentPrice * (1 - value / 100);
    }
    return PriceAlert(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      direction: direction,
      value: value,
      targetPrice: target,
    );
  }

  bool isTriggered(double currentPrice) => direction == AlertDirection.above
      ? currentPrice >= targetPrice
      : currentPrice <= targetPrice;

  String get label {
    final arrow = direction == AlertDirection.above ? '↑' : '↓';
    if (type == AlertType.price) {
      return '$arrow \$${value.toStringAsFixed(2)}';
    } else {
      return '$arrow ${direction == AlertDirection.above ? '+' : '-'}${value.toStringAsFixed(1)}%  (target \$${targetPrice.toStringAsFixed(2)})';
    }
  }

  String notificationBody(String symbol, double price) {
    if (direction == AlertDirection.above) {
      return type == AlertType.percent
          ? '$symbol up ${value.toStringAsFixed(1)}% — now \$${price.toStringAsFixed(2)}'
          : '$symbol hit \$${price.toStringAsFixed(2)} (above target \$${value.toStringAsFixed(2)})';
    } else {
      return type == AlertType.percent
          ? '$symbol down ${value.toStringAsFixed(1)}% — now \$${price.toStringAsFixed(2)}'
          : '$symbol dropped to \$${price.toStringAsFixed(2)} (below target \$${value.toStringAsFixed(2)})';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'direction': direction.name,
        'value': value,
        'targetPrice': targetPrice,
      };

  factory PriceAlert.fromJson(Map<String, dynamic> json) => PriceAlert(
        id: json['id'] as String,
        type: AlertType.values.byName(json['type'] as String),
        direction: AlertDirection.values.byName(json['direction'] as String),
        value: (json['value'] as num).toDouble(),
        targetPrice: (json['targetPrice'] as num).toDouble(),
      );
}

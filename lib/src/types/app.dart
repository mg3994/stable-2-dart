class AppState {
  dynamic product;
  Map<String, String> selectedVariants;
  int currentSlide;
  int quantity;
  String? lastClickedAttribute;
  dynamic selectedPackage;
  dynamic verifiedLocation;
  dynamic orderDelivery;

  AppState({
    this.product,
    Map<String, String>? selectedVariants,
    this.currentSlide = 0,
    this.quantity = 1,
    this.lastClickedAttribute,
    this.selectedPackage,
    this.verifiedLocation,
    this.orderDelivery,
  }) : selectedVariants = selectedVariants ?? {};
}

class LocationData {
  double? lat;
  double? lon;
  String? pin;
  String? city;

  LocationData({
    this.lat,
    this.lon,
    this.pin,
    this.city,
  });

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lon': lon,
        'pin': pin,
        'city': city,
      };

  factory LocationData.fromJson(Map<String, dynamic> json) => LocationData(
        lat: json['lat'] != null ? (json['lat'] as num).toDouble() : null,
        lon: json['lon'] != null ? (json['lon'] as num).toDouble() : null,
        pin: json['pin'] as String?,
        city: json['city'] as String?,
      );
}

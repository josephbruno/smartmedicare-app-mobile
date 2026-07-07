class Pet {
  Pet({
    required this.id,
    required this.customerId,
    required this.name,
    this.species,
    this.breed,
    required this.gender,
  });

  final int id;
  final int customerId;
  final String name;
  final String? species;
  final String? breed;
  final String gender;

  factory Pet.fromJson(Map<String, dynamic> j) => Pet(
        id: (j['id'] as num?)?.toInt() ?? 0,
        customerId: (j['customer_id'] as num?)?.toInt() ?? 0,
        name: j['name']?.toString() ?? '',
        species: j['species']?.toString(),
        breed: j['breed']?.toString(),
        gender: j['gender']?.toString() ?? '',
      );
}

class Customer {
  Customer({
    required this.id,
    required this.name,
    this.email,
    required this.phone,
    this.city,
    this.state,
    this.gstin,
    required this.isActive,
    this.outstandingBalance,
    this.pets,
  });

  final int id;
  final String name;
  final String? email;
  final String phone;
  final String? city;
  final String? state;
  final String? gstin;
  final bool isActive;
  final double? outstandingBalance;
  final List<Pet>? pets;

  factory Customer.fromJson(Map<String, dynamic> j) {
    List<Pet>? pets;
    if (j['pets'] is List) {
      pets = (j['pets'] as List)
          .whereType<Map>()
          .map((e) => Pet.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return Customer(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: j['name']?.toString() ?? '',
      email: j['email']?.toString(),
      phone: j['phone']?.toString() ?? '',
      city: j['city']?.toString(),
      state: j['state']?.toString(),
      gstin: j['gstin']?.toString(),
      isActive: j['is_active'] as bool? ?? true,
      outstandingBalance: (j['outstanding_balance'] as num?)?.toDouble(),
      pets: pets,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (email != null) 'email': email,
        'phone': phone,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        'is_active': isActive,
        if (outstandingBalance != null)
          'outstanding_balance': outstandingBalance,
      };
}

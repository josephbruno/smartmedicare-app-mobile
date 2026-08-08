import '../json_helpers.dart';

class Pet {
  Pet({
    required this.id,
    required this.customerId,
    required this.name,
    this.species,
    this.breed,
    required this.gender,
    this.dob,
    this.age,
    this.weight,
    this.color,
  });

  final int id;
  final int customerId;
  final String name;
  final String? species;
  final String? breed;
  final String gender;
  final String? dob;
  final String? age;
  final double? weight;
  final String? color;

  factory Pet.fromJson(Map<String, dynamic> j) => Pet(
        id: intOrNull(j['id']) ?? 0,
        customerId: intOrNull(j['customer_id']) ?? 0,
        name: j['name']?.toString() ?? '',
        species: j['species']?.toString(),
        breed: j['breed']?.toString(),
        gender: j['gender']?.toString() ?? '',
        dob: j['dob']?.toString(),
        age: j['age']?.toString(),
        weight: numOrNull(j['weight']),
        color: j['color']?.toString(),
      );
}

class PetSpecies {
  PetSpecies({
    required this.id,
    required this.code,
    required this.name,
  });

  final int id;
  final String code;
  final String name;

  factory PetSpecies.fromJson(Map<String, dynamic> j) => PetSpecies(
        id: intOrNull(j['id']) ?? 0,
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
      );
}

class PetBreed {
  PetBreed({
    required this.id,
    required this.speciesId,
    required this.name,
  });

  final int id;
  final int speciesId;
  final String name;

  factory PetBreed.fromJson(Map<String, dynamic> j) => PetBreed(
        id: intOrNull(j['id']) ?? 0,
        speciesId: intOrNull(j['species_id']) ?? 0,
        name: j['name']?.toString() ?? '',
      );
}

class Customer {
  Customer({
    required this.id,
    required this.name,
    this.email,
    required this.phone,
    this.alternatePhone,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.dob,
    this.gender,
    this.gstin,
    this.creditLimit,
    this.loyaltyPoints = 0,
    this.advanceBalance = 0,
    this.whatsappOpted,
    this.notes,
    required this.isActive,
    this.outstandingBalance,
    this.pets,
  });

  final int id;
  final String name;
  final String? email;
  final String phone;
  final String? alternatePhone;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? dob;
  final String? gender;
  final String? gstin;
  final double? creditLimit;
  final int loyaltyPoints;
  final double advanceBalance;
  final bool? whatsappOpted;
  final String? notes;
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
      id: intOrNull(j['id']) ?? 0,
      name: j['name']?.toString() ?? '',
      email: j['email']?.toString(),
      phone: j['phone']?.toString() ?? '',
      alternatePhone: j['alternate_phone']?.toString(),
      address: j['address']?.toString(),
      city: j['city']?.toString(),
      state: j['state']?.toString(),
      pincode: j['pincode']?.toString(),
      dob: j['dob']?.toString(),
      gender: j['gender']?.toString(),
      gstin: j['gstin']?.toString(),
      creditLimit: numOrNull(j['credit_limit']),
      loyaltyPoints: intOrNull(j['loyalty_points']) ?? 0,
      advanceBalance: numOrNull(j['advance_balance']) ?? 0,
      whatsappOpted: j['whatsapp_opted'] as bool?,
      notes: j['notes']?.toString(),
      isActive: j['is_active'] as bool? ?? true,
      outstandingBalance: numOrNull(j['outstanding_balance']),
      pets: pets,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (email != null) 'email': email,
        'phone': phone,
        if (alternatePhone != null) 'alternate_phone': alternatePhone,
        if (address != null) 'address': address,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        if (pincode != null) 'pincode': pincode,
        if (dob != null) 'dob': dob,
        if (gender != null) 'gender': gender,
        if (gstin != null) 'gstin': gstin,
        if (creditLimit != null) 'credit_limit': creditLimit,
        'loyalty_points': loyaltyPoints,
        'advance_balance': advanceBalance,
        if (whatsappOpted != null) 'whatsapp_opted': whatsappOpted,
        if (notes != null) 'notes': notes,
        'is_active': isActive,
        if (outstandingBalance != null)
          'outstanding_balance': outstandingBalance,
      };

  Customer copyWith({
    double? advanceBalance,
    int? loyaltyPoints,
    double? outstandingBalance,
  }) =>
      Customer(
        id: id,
        name: name,
        email: email,
        phone: phone,
        alternatePhone: alternatePhone,
        address: address,
        city: city,
        state: state,
        pincode: pincode,
        dob: dob,
        gender: gender,
        gstin: gstin,
        creditLimit: creditLimit,
        loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
        advanceBalance: advanceBalance ?? this.advanceBalance,
        whatsappOpted: whatsappOpted,
        notes: notes,
        isActive: isActive,
        outstandingBalance: outstandingBalance ?? this.outstandingBalance,
        pets: pets,
      );
}

import 'package:equatable/equatable.dart';

class Customer extends Equatable {
  const Customer({
    required this.id,
    required this.userId,
    required this.name,
    required this.contactInfo,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final int userId;
  final String name;
  final String? contactInfo;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    id,
    userId,
    name,
    contactInfo,
    createdAt,
    updatedAt,
  ];
}

class Site extends Equatable {
  const Site({
    required this.id,
    required this.userId,
    required this.customerId,
    required this.customerName,
    required this.siteName,
    required this.address,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final int userId;
  final String customerId;
  final String customerName;
  final String siteName;
  final String? address;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    id,
    userId,
    customerId,
    customerName,
    siteName,
    address,
    createdAt,
    updatedAt,
  ];
}

class FieldNote extends Equatable {
  const FieldNote({
    required this.id,
    required this.userId,
    required this.siteId,
    required this.siteName,
    this.siteAddress,
    required this.customerId,
    required this.customerName,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.notedAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.localPhotoPath,
    required this.remoteHasPhoto,
  });

  final String id;
  final int userId;
  final String siteId;
  final String siteName;
  final String? siteAddress;
  final String customerId;
  final String customerName;
  final String title;
  final String? description;
  final double? latitude;
  final double? longitude;
  final DateTime notedAt;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? localPhotoPath;
  final bool remoteHasPhoto;

  bool get hasPhoto =>
      (localPhotoPath != null && localPhotoPath!.isNotEmpty) || remoteHasPhoto;

  @override
  List<Object?> get props => [
    id,
    userId,
    siteId,
    siteName,
    siteAddress,
    customerId,
    customerName,
    title,
    description,
    latitude,
    longitude,
    notedAt,
    status,
    createdAt,
    updatedAt,
    localPhotoPath,
    remoteHasPhoto,
  ];
}

class NoteDraft {
  const NoteDraft({
    this.id,
    required this.siteId,
    required this.title,
    this.description,
    this.latitude,
    this.longitude,
    required this.notedAt,
    required this.status,
    this.newPhotoPath,
  });

  final String? id;
  final String siteId;
  final String title;
  final String? description;
  final double? latitude;
  final double? longitude;
  final DateTime notedAt;
  final String status;
  final String? newPhotoPath;
}

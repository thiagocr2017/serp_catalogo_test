import '../../api/sales_api.dart';

class SalesAgentModel {
  const SalesAgentModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.isActive,
  });

  final String id;
  final String name;
  final String phone;
  final bool isActive;

  factory SalesAgentModel.fromJson(Map<String, dynamic> json) =>
      SalesAgentModel(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        isActive: json['is_active'] as bool? ?? true,
      );

  SalesAgentDto toApi() => SalesAgentDto(
    id: id,
    name: name,
    phone: phone,
    isActive: isActive,
    version: 0,
  );
}

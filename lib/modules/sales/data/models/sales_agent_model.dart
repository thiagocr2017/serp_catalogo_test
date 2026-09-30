import '../../api/sales_api.dart';

class SalesAgentModel {
  const SalesAgentModel({
    required this.id,
    required this.name,
    required this.phone,
  });

  final String id;
  final String name;
  final String phone;

  factory SalesAgentModel.fromJson(Map<String, dynamic> json) =>
      SalesAgentModel(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
      );

  SalesAgentDto toApi() => SalesAgentDto(
    id: id,
    name: name,
    phone: phone,
    isActive: true,
    version: 0,
  );
}

import '../../../core/identity/identity_context.dart';

class CreateSalesAgentCommand {
  const CreateSalesAgentCommand({
    required this.commandId,
    required this.name,
    required this.phone,
    required this.identity,
  });

  final String commandId;
  final String name;
  final String phone;
  final IdentityContext identity;
}

class UpdateSalesAgentCommand {
  const UpdateSalesAgentCommand({
    required this.id,
    required this.name,
    required this.phone,
    required this.expectedVersion,
    required this.identity,
  });

  final String id;
  final String name;
  final String phone;
  final int expectedVersion;
  final IdentityContext identity;
}

class ActivateSalesAgentCommand {
  const ActivateSalesAgentCommand({
    required this.id,
    required this.expectedVersion,
    required this.identity,
  });

  final String id;
  final int expectedVersion;
  final IdentityContext identity;
}

class DeactivateSalesAgentCommand {
  const DeactivateSalesAgentCommand({
    required this.id,
    required this.expectedVersion,
    required this.identity,
  });

  final String id;
  final int expectedVersion;
  final IdentityContext identity;
}

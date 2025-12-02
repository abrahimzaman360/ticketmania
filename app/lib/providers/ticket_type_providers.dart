import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/ticket_type_repository.dart';
import '../providers/connectivity_provider.dart';
import '../models/ticket_type.dart';

/// Provider for ticket types
final ticketTypesProvider = FutureProvider<List<TicketType>>((ref) async {
  final isOnline = ref.watch(isOnlineProvider);
  final repository = ref.watch(ticketTypeRepositoryProvider(isOnline));
  return repository.getTicketTypes();
});


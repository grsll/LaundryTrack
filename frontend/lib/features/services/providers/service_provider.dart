import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/service_model.dart';
import '../data/service_repository.dart';

class ServiceState {
  final List<ServiceModel> services;
  final bool isLoading;
  final String? errorMessage;
  final String priceTypeFilter; // "all", "per_kg", "per_item"
  final String searchQuery;

  const ServiceState({
    this.services = const [],
    this.isLoading = false,
    this.errorMessage,
    this.priceTypeFilter = 'all',
    this.searchQuery = '',
  });

  ServiceState copyWith({
    List<ServiceModel>? services,
    bool? isLoading,
    String? errorMessage,
    String? priceTypeFilter,
    String? searchQuery,
  }) {
    return ServiceState(
      services: services ?? this.services,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      priceTypeFilter: priceTypeFilter ?? this.priceTypeFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class ServiceNotifier extends Notifier<ServiceState> {
  late final ServiceRepository _repository;

  @override
  ServiceState build() {
    _repository = ref.watch(serviceRepositoryProvider);
    Future.microtask(() => loadServices());
    return const ServiceState(isLoading: true);
  }

  Future<void> loadServices({String? query, String? priceType}) async {
    final activePriceType = priceType ?? state.priceTypeFilter;
    final activeQuery = query ?? state.searchQuery;

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      priceTypeFilter: activePriceType,
      searchQuery: activeQuery,
    );

    try {
      final list = await _repository.getServices(
        query: activeQuery,
        priceType: activePriceType == 'all' ? null : activePriceType,
      );
      state = state.copyWith(services: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> createService(Map<String, dynamic> payload) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final created = await _repository.createService(payload);
      state = state.copyWith(
        services: [...state.services, created],
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> updateService(String id, Map<String, dynamic> payload) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final updated = await _repository.updateService(id, payload);
      final updatedList = state.services.map((s) => s.id == id ? updated : s).toList();
      state = state.copyWith(services: updatedList, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> archiveService(String id) async {
    try {
      final archived = await _repository.archiveService(id);
      final updatedList = state.services.map((s) => s.id == id ? archived : s).toList();
      state = state.copyWith(services: updatedList);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
}

final serviceProvider = NotifierProvider<ServiceNotifier, ServiceState>(() {
  return ServiceNotifier();
});

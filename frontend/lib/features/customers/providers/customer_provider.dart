import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/customer_model.dart';
import '../data/customer_repository.dart';

class CustomerState {
  final List<CustomerModel> customers;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;

  const CustomerState({
    this.customers = const [],
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery = '',
  });

  CustomerState copyWith({
    List<CustomerModel>? customers,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
  }) {
    return CustomerState(
      customers: customers ?? this.customers,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class CustomerNotifier extends Notifier<CustomerState> {
  late final CustomerRepository _repository;

  @override
  CustomerState build() {
    _repository = ref.watch(customerRepositoryProvider);
    // Initial fetch
    Future.microtask(() => loadCustomers());
    return const CustomerState(isLoading: true);
  }

  Future<void> loadCustomers({String? query}) async {
    state = state.copyWith(isLoading: true, errorMessage: null, searchQuery: query ?? state.searchQuery);
    try {
      final list = await _repository.getCustomers(query: query ?? state.searchQuery);
      state = state.copyWith(customers: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> createCustomer(Map<String, dynamic> payload) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final newCustomer = await _repository.createCustomer(payload);
      state = state.copyWith(
        customers: [newCustomer, ...state.customers],
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> updateCustomer(String id, Map<String, dynamic> payload) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final updated = await _repository.updateCustomer(id, payload);
      final updatedList = state.customers.map((c) => c.id == id ? updated : c).toList();
      state = state.copyWith(customers: updatedList, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> archiveCustomer(String id) async {
    try {
      final archived = await _repository.archiveCustomer(id);
      final updatedList = state.customers.map((c) => c.id == id ? archived : c).toList();
      state = state.copyWith(customers: updatedList);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
}

final customerProvider = NotifierProvider<CustomerNotifier, CustomerState>(() {
  return CustomerNotifier();
});

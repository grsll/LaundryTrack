import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/order_model.dart';
import '../data/order_repository.dart';

class OrderState {
  final List<OrderModel> orders;
  final bool isLoading;
  final String? errorMessage;
  final String statusFilter; // "all", "received", "washing", etc.
  final String searchQuery;

  const OrderState({
    this.orders = const [],
    this.isLoading = false,
    this.errorMessage,
    this.statusFilter = 'all',
    this.searchQuery = '',
  });

  OrderState copyWith({
    List<OrderModel>? orders,
    bool? isLoading,
    String? errorMessage,
    String? statusFilter,
    String? searchQuery,
  }) {
    return OrderState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      statusFilter: statusFilter ?? this.statusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class OrderNotifier extends Notifier<OrderState> {
  late final OrderRepository _repository;

  @override
  OrderState build() {
    _repository = ref.watch(orderRepositoryProvider);
    Future.microtask(() => loadOrders());
    return const OrderState(isLoading: true);
  }

  Future<void> loadOrders({String? query, String? status}) async {
    final activeStatus = status ?? state.statusFilter;
    final activeQuery = query ?? state.searchQuery;

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      statusFilter: activeStatus,
      searchQuery: activeQuery,
    );

    try {
      final list = await _repository.getOrders(
        query: activeQuery,
        status: activeStatus == 'all' ? null : activeStatus,
      );
      state = state.copyWith(orders: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<OrderModel?> createOrder(Map<String, dynamic> payload) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final created = await _repository.createOrder(payload);
      state = state.copyWith(
        orders: [created, ...state.orders],
        isLoading: false,
      );
      return created;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }

  Future<bool> transitionStatus(String orderId, String newStatus, {String? notes}) async {
    try {
      final updated = await _repository.transitionStatus(orderId, newStatus, notes: notes);
      final updatedList = state.orders.map((o) => o.id == orderId ? updated : o).toList();
      state = state.copyWith(orders: updatedList);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> cancelOrder(String orderId, String reason) async {
    try {
      final updated = await _repository.cancelOrder(orderId, reason);
      final updatedList = state.orders.map((o) => o.id == orderId ? updated : o).toList();
      state = state.copyWith(orders: updatedList);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
}

final orderProvider = NotifierProvider<OrderNotifier, OrderState>(() {
  return OrderNotifier();
});

final orderDetailProvider = FutureProvider.family.autoDispose<OrderModel, String>((ref, orderId) async {
  final repository = ref.watch(orderRepositoryProvider);
  return repository.getOrderDetail(orderId);
});

final orderTimelineProvider =
    FutureProvider.family.autoDispose<List<OrderStatusLogModel>, String>((ref, orderId) async {
  final repository = ref.watch(orderRepositoryProvider);
  return repository.getOrderTimeline(orderId);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/tracking_model.dart';
import '../data/tracking_repository.dart';

final publicTrackingProvider =
    FutureProvider.family<PublicTrackingModel, String>((ref, token) async {
  final repo = ref.watch(trackingRepositoryProvider);
  return repo.getPublicTracking(token);
});

final trackingLinkProvider =
    FutureProvider.family<TrackingLinkModel, String>((ref, orderId) async {
  final repo = ref.watch(trackingRepositoryProvider);
  return repo.getOrderTrackingLink(orderId);
});

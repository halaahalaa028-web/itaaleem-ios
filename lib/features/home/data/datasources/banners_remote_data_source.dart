import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/core/network/dio_client.dart';
import 'package:itaaleem/features/home/domain/entities/app_banner.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BannersRemoteDataSource {
  BannersRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<AppBanner>> getBanners() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.banners,
    );
    if (kDebugMode) {
      debugPrint('>>> GET ${ApiEndpoints.banners} raw response: ${response.data}');
    }
    final data = response.data?['data'];
    final rawList = data is List ? data : const [];
    return rawList
        .map((e) => _bannerFromJson(e as Map<String, dynamic>))
        .toList();
  }

  AppBanner _bannerFromJson(Map<String, dynamic> json) {
    final imageUrl =
        (json['image'] ?? json['image_url'] ?? json['banner'] ?? json['photo'])
            as String?;
    return AppBanner(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      imageUrl: ApiEndpoints.mediaUrl(imageUrl) ?? imageUrl ?? '',
      title: (json['title'] ?? json['name']) as String?,
      linkUrl: (json['link'] ?? json['link_url'] ?? json['url']) as String?,
    );
  }
}

final bannersRemoteDataSourceProvider = Provider<BannersRemoteDataSource>((
  ref,
) {
  final dio = ref.watch(dioClientProvider);
  return BannersRemoteDataSource(dio);
});

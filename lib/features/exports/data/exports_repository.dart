import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class ExportsRepository {
  ExportsRepository(this._dio);
  final Dio _dio;

  Future<Uint8List> monthlyPdf({required String month}) async {
    final res = await _dio.get<List<int>>(
      '/exports/monthly.pdf',
      queryParameters: {'month': month},
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data!);
  }

  Future<Uint8List> monthlyXlsx({required String month}) async {
    final res = await _dio.get<List<int>>(
      '/exports/monthly.xlsx',
      queryParameters: {'month': month},
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data!);
  }
}

final exportsRepositoryProvider = Provider<ExportsRepository>((ref) {
  return ExportsRepository(ref.watch(apiClientProvider));
});

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/page_result.dart';
import '../../../core/network/api_client.dart';
import 'submission_models.dart';

class SubmissionsRepository {
  SubmissionsRepository(this._dio);
  final Dio _dio;

  Future<PageResult<Submission>> queue({int page = 1, int pageSize = 50}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/submissions/queue',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return PageResult.fromJson<Submission>(res.data!, Submission.fromJson);
  }

  /// Lists submissions, optionally filtered by status. Role-scoped on the
  /// server. Used e.g. by Ops Excellence to find APPROVED submissions to score.
  Future<PageResult<Submission>> list({
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/submissions',
      queryParameters: {
        'status': ?status,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return PageResult.fromJson<Submission>(res.data!, Submission.fromJson);
  }

  Future<Submission> getById(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/submissions/$id');
    return Submission.fromJson(res.data!['submission'] as Map<String, dynamic>);
  }

  Future<Submission> decide({
    required String submissionId,
    required bool approve,
    String? comment,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/submissions/$submissionId/decision',
      data: {
        'decision': approve ? 'APPROVE' : 'REJECT',
        'comment': ?comment,
      },
    );
    return Submission.fromJson(res.data!['submission'] as Map<String, dynamic>);
  }

  /// Allocates marks for one item. Pass [opsRemark] to set the Ops Excellence
  /// note ('' clears it); leave it null to keep whatever is stored.
  Future<Submission> scoreItem({
    required String submissionId,
    required String itemId,
    required int awardedMarks,
    String? opsRemark,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/submissions/$submissionId/items/$itemId/score',
      data: {
        'awardedMarks': awardedMarks,
        'opsRemark': ?opsRemark,
      },
    );
    return Submission.fromJson(res.data!['submission'] as Map<String, dynamic>);
  }

  Future<CycleSnapshot> getCycle({required String projectId, required String month}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/submissions/cycle',
      queryParameters: {'projectId': projectId, 'month': month},
    );
    return CycleSnapshot.fromJson(res.data!);
  }

  /// Streams a file to the server. `onProgress` is called as bytes go out so
  /// the UI can render a progress bar.
  Future<Submission> uploadFile({
    required String projectId,
    required String month,
    required String categoryId,
    required Uint8List bytes,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'projectId': projectId,
      'month': month,
      'categoryId': categoryId,
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    final res = await _dio.post<Map<String, dynamic>>(
      '/submissions/upload',
      data: form,
      onSendProgress: onProgress,
    );
    return Submission.fromJson(res.data!['submission'] as Map<String, dynamic>);
  }

  Future<Submission> submitForApproval(String submissionId) async {
    final res = await _dio.post<Map<String, dynamic>>('/submissions/$submissionId/submit');
    return Submission.fromJson(res.data!['submission'] as Map<String, dynamic>);
  }

  Future<Uint8List> downloadItem(String itemId) async {
    final res = await _dio.get<List<int>>(
      '/submissions/items/$itemId/download',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data!);
  }
}

final submissionsRepositoryProvider = Provider<SubmissionsRepository>((ref) {
  return SubmissionsRepository(ref.watch(apiClientProvider));
});

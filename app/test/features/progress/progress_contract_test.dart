import 'package:dio/dio.dart';
import 'package:fitness_app/core/api/api_client.dart';
import 'package:fitness_app/features/progress/data/repositories/api_progress_repository.dart';
import 'package:fitness_app/features/progress/domain/models/progress_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'measurement request omits empty fields and leaves local day to server',
    () {
      expect(const MeasurementRequest(weightKg: 70.5, waistCm: 85).toJson(), {
        'weightKg': 70.5,
        'waistCm': 85.0,
      });
      expect(const MeasurementRequest().hasValue, isFalse);
    },
  );
  test('API reads 90 days and parses nullable achievements', () async {
    final client = ApiClient(
      baseUrl: 'http://test.invalid',
      tokenProvider: () async => 'test-token',
    );
    final requests = <RequestOptions>[];
    const measurement = {
      'measuredOn': '2026-10-04',
      'weightKg': 70.5,
      'waistCm': 85,
      'hipCm': null,
      'chestCm': null,
      'armCm': null,
      'bodyFatPct': null,
    };
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: request.method == 'GET'
                  ? {
                      'days': 90,
                      'items': [measurement],
                    }
                  : {
                      'measurement': measurement,
                      'newAchievements': [
                        {
                          'code': 'waist_down',
                          'nameVi': null,
                          'descriptionVi': null,
                        },
                      ],
                    },
            ),
          );
        },
      ),
    );
    final repo = ApiProgressRepository(client);
    final history = await repo.history();
    final saved = await repo.save(
      const MeasurementRequest(weightKg: 70.5, waistCm: 85),
    );
    expect(requests.first.path, '/measurements');
    expect(requests.first.queryParameters, {'days': 90});
    expect(requests.last.data, {'weightKg': 70.5, 'waistCm': 85.0});
    expect(history.items.single.hipCm, isNull);
    expect(saved.measurement.measuredOn, '2026-10-04');
    expect(saved.newAchievements.single.code, 'waist_down');
    expect(saved.newAchievements.single.nameVi, isNull);
    client.dio.close();
  });
}

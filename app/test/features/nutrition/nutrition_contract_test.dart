import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fitness_app/core/api/api_client.dart';
import 'package:fitness_app/core/api/api_exceptions.dart';
import 'package:fitness_app/features/nutrition/data/photo/meal_photo.dart';
import 'package:fitness_app/features/nutrition/data/repositories/api_nutrition_repository.dart';
import 'package:fitness_app/features/nutrition/domain/models/nutrition_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

const foodJson = {
  'foodId': '000000000000000000000001',
  'nameVi': 'Cơm trắng',
  'category': 'rice',
  'servingDesc': '1 chén',
  'servingGrams': 100.0,
  'kcal': 130,
  'proteinG': 2.7,
  'carbsG': 28.0,
  'fatG': 0.3,
};
const todayJson = {
  'localDate': '2026-10-04',
  'target': {
    'kcal': 1800,
    'proteinG': 110,
    'carbsG': 200,
    'fatG': 60,
    'waterMl': 2000,
  },
  'consumed': {'kcal': 130, 'proteinG': 2.7, 'carbsG': 28, 'fatG': .3},
  'remaining': {'kcal': 1670, 'proteinG': 107.3, 'carbsG': 172, 'fatG': 59.7},
  'waterMl': 250,
  'meals': [
    {
      'id': 'meal',
      'meal': 'lunch',
      'method': 'search',
      'eatenAt': '2026-10-04T05:00:00Z',
      'kcal': 130,
      'proteinG': 2.7,
      'carbsG': 28,
      'fatG': .3,
      'items': [
        {
          'foodId': '000000000000000000000001',
          'name': 'Cơm trắng',
          'grams': 100,
          'kcal': 130,
          'proteinG': 2.7,
          'carbsG': 28,
          'fatG': .3,
        },
      ],
    },
  ],
  'suggestion': {
    'message': 'Thêm đạm',
    'foods': [foodJson],
  },
};

void main() {
  test('photo JSON hashes the exact base64 bytes locally', () {
    final photo = MealPhoto(
      Uint8List.fromList(utf8.encode('abc')),
      'image/jpeg',
    );
    expect(photo.toJson(), {
      'imageBase64': 'YWJj',
      'mediaType': 'image/jpeg',
      'sha256':
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    });
  });
  test('compression encodes JPEG under 2 MB and scales large image', () {
    final original = img.Image(width: 2000, height: 1000);
    final bytes = compressMealPhoto(img.encodePng(original));
    expect(bytes.length, lessThanOrEqualTo(maxMealPhotoBytes));
    expect(bytes.take(2), [255, 216]);
    final decoded = img.decodeJpg(bytes)!;
    expect(decoded.width, 1600);
    expect(decoded.height, 800);
  });
  test('invalid image bytes cannot be compressed or sent', () {
    expect(
      () => compressMealPhoto(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<ApiException>()),
    );
  });
  test('portion edits always scale from original serving', () {
    final item = MealItem.fromFood(Food.fromJson(foodJson));
    final edited = item.withGrams(200).withGrams(150);
    expect(edited.macros.kcal, 195);
    expect(edited.toJson()['portionGrams'], 150);
    expect(edited.toJson().containsKey('grams'), isFalse);
  });
  test('today record parses meals, remaining and suggestion without invented goals', () {
    final today = NutritionToday.fromJson(todayJson);
    expect(today.localDate, '2026-10-04');
    expect(today.target!.waterMl, 2000);
    expect(today.meals.single.names, ['Cơm trắng']);
    expect(today.suggestion!.foods.single.nameVi, 'Cơm trắng');
    expect(
      NutritionToday.fromJson({...todayJson, 'target': null, 'remaining': null})
          .target,
      isNull,
    );
  });
  test('recognition matched and unmatched nullable fields', () {
    final result = Recognition.fromJson({
      'recognitionId': '000000000000000000000002',
      'cached': true,
      'items': [
        {
          'name': 'rice',
          'nameVi': 'Cơm trắng',
          'foodId': '000000000000000000000001',
          'portionGrams': 200,
          'kcal': 260,
          'proteinG': 5.4,
          'carbsG': 56,
          'fatG': .6,
          'kcalMin': 221,
          'kcalMax': 299,
          'matched': true,
          'confidence': .9,
          'ingredients': [],
        },
        {
          'name': 'Unknown',
          'nameVi': null,
          'foodId': null,
          'portionGrams': 100,
          'kcal': null,
          'proteinG': null,
          'carbsG': null,
          'fatG': null,
          'matched': false,
          'confidence': .4,
          'ingredients': [],
        },
      ],
    });
    expect(result.cached, isTrue);
    expect(result.items.first.withGrams(100).macros.kcal, 130);
    expect(result.items.last.valid, isFalse);
    expect(result.items.last.name, 'Unknown');
  });
  test('recognition estimated item is usable without foodId', () {
    final item = MealItem.fromRecognition({
      'name': 'Strawberry tea',
      'nameVi': 'Trà dâu kem cheese',
      'foodId': null,
      'portionGrams': 500,
      'kcal': 375,
      'proteinG': 6,
      'carbsG': 60,
      'fatG': 12.5,
      'kcalMin': 281,
      'kcalMax': 469,
      'matched': false,
      'estimated': true,
      'confidence': .8,
      'ingredients': [],
    });
    expect(item.matched, isFalse);
    expect(item.estimated, isTrue);
    expect(item.valid, isTrue);
    expect(item.withGrams(250).macros.kcal, 187.5);
    expect(item.toJson()['foodId'], isNull);
    expect(item.toJson()['kcal'], 375);
  });
  test('API paths, query, auth, body and Java response contracts', () async {
    final client = ApiClient(
      baseUrl: 'http://test.invalid',
      tokenProvider: () async => 'test-token',
    );
    final requests = <RequestOptions>[];
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          final dynamic body = switch (request.path) {
            '/foods/search' => [foodJson],
            '/water' => {
              'localDate': '2026-10-04',
              'waterMl': 500,
              'targetMl': 2000,
            },
            '/meals/recognize' => {
              'recognitionId': '000000000000000000000002',
              'cached': false,
              'items': [],
            },
            _ => todayJson,
          };
          handler.resolve(
            Response(requestOptions: request, statusCode: 200, data: body),
          );
        },
      ),
    );
    final repo = ApiNutritionRepository(client);
    await repo.today();
    final foods = await repo.search('com trang');
    await repo.recognize(
      MealPhoto(Uint8List.fromList([97, 98, 99]), 'image/jpeg'),
    );
    await repo.saveMeal(
      MealRequest(
        meal: 'dinner',
        method: 'search',
        items: [MealItem.fromFood(foods.single)],
      ),
    );
    final water = await repo.addWater(250);
    expect(requests.map((e) => e.path), [
      '/nutrition/today',
      '/foods/search',
      '/meals/recognize',
      '/meals',
      '/water',
    ]);
    expect(requests[1].queryParameters, {'q': 'com trang'});
    expect(
      requests[2].data.keys,
      unorderedEquals(['imageBase64', 'mediaType', 'sha256']),
    );
    expect(requests[3].data['items'][0]['portionGrams'], 100);
    expect(requests[3].data.containsKey('userId'), isFalse);
    expect(requests.last.data, {'ml': 250});
    expect(water.targetMl, 2000);
    expect(
      requests.every((r) => r.headers['Authorization'] == 'Bearer test-token'),
      isTrue,
    );
    client.dio.close();
  });
}

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:longevity_plate/app/app_services.dart';
import 'package:longevity_plate/core/dates.dart';
import 'package:longevity_plate/models/models.dart';
import 'package:longevity_plate/services/app_failure.dart';
import 'package:longevity_plate/services/device_meal_photo_service.dart';
import 'package:longevity_plate/services/fake_meal_photo_service.dart';
import 'package:longevity_plate/services/fake_services.dart';
import 'package:longevity_plate/services/meal_photo_service.dart';
import 'package:longevity_plate/services/repositories.dart';
import 'package:longevity_plate/services/service_interfaces.dart';
import 'package:longevity_plate/viewmodels/add_meal_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Picker implements MealPhotoPicker {
  XFile? image;
  XFile? lost;
  int recoverCalls = 0;
  final sources = <MealPhotoSource>[];
  @override
  Future<XFile?> pick(MealPhotoSource source) async {
    sources.add(source);
    return image;
  }

  @override
  Future<XFile?> recover() async {
    recoverCalls++;
    return lost;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late SharedPreferences prefs;
  late _Picker picker;
  late DeviceMealPhotoService photos;
  String? activeUid;
  late Uint8List fixture;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('longevity_meal_photo_test_');
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    activeUid = 'user-A';
    picker = _Picker();
    fixture = img.encodePng(img.Image(width: 48, height: 32));
    final input = File('${root.path}/picker.png');
    await input.writeAsBytes(fixture);
    picker.image = XFile(input.path);
    photos = DeviceMealPhotoService(
      prefs: prefs,
      currentUid: () => activeUid,
      picker: picker,
      documentsDirectory: () async => Directory('${root.path}/documents'),
    );
  });
  tearDown(() async {
    // Only this freshly created test directory is removed.
    if (root.path.startsWith(Directory.systemTemp.path) &&
        root.path.contains('longevity_meal_photo_test_')) {
      await root.delete(recursive: true);
    }
  });

  for (final source in MealPhotoSource.values) {
    test(
      'native adapter ${source.name}: validates and makes an owned durable JPEG',
      () async {
        final draft = await photos.pick('user-A', source);
        expect(picker.sources, [source]);
        expect(draft, startsWith('meal_photos/'));
        expect(draft, isNot(contains(root.path)));
        final saved = await photos.persist('user-A', draft!, 'meal-1');
        await photos.remove('user-A', draft);
        await File(picker.image!.path).delete();
        final restarted = DeviceMealPhotoService(
          prefs: prefs,
          currentUid: () => activeUid,
          picker: _Picker(),
          documentsDirectory: () async => Directory('${root.path}/documents'),
        );
        final bytes = await restarted.read('user-A', saved);
        expect(bytes!.take(2), [0xff, 0xd8]);
        final decoded = img.decodeJpg(bytes)!;
        expect(decoded.width, 48);
        expect(decoded.height, 32);
        expect(await restarted.read('user-A', draft), isNull);
      },
    );
  }

  test('resizes to 1600px before JPEG encoding', () async {
    final large = img.encodePng(img.Image(width: 2400, height: 1200));
    final result = img.decodeJpg(
      await DeviceMealPhotoService.normalizePhoto(large),
    )!;
    expect(result.width, 1600);
    expect(result.height, 800);
  });

  test('EXIF portrait orientation is normalized rather than lost', () async {
    final original = img.Image(width: 60, height: 30);
    original.exif.imageIfd.orientation = 6;
    final result = img.decodeJpg(
      await DeviceMealPhotoService.normalizePhoto(img.encodeJpg(original)),
    )!;
    expect(result.width, 30);
    expect(result.height, 60);
  });

  test('invalid image and oversized inputs fail safely', () async {
    await expectLater(
      DeviceMealPhotoService.normalizePhoto(Uint8List.fromList([1, 2, 3])),
      throwsA(
        isA<AppFailure>().having((e) => e.code, 'code', 'invalid_meal_photo'),
      ),
    );
    await expectLater(
      DeviceMealPhotoService.normalizePhoto(
        Uint8List(DeviceMealPhotoService.maxInputBytes + 1),
      ),
      throwsA(
        isA<AppFailure>().having((e) => e.code, 'code', 'photo_too_large'),
      ),
    );
  });

  test('cancelled camera/gallery does not create files', () async {
    picker.image = null;
    expect(await photos.pick('user-A', MealPhotoSource.camera), isNull);
    expect(await photos.pick('user-A', MealPhotoSource.gallery), isNull);
    expect(await Directory('${root.path}/documents').exists(), isFalse);
  });

  test('account B cannot read/delete A files; A can sign back in', () async {
    final ref = (await photos.pick('user-A', MealPhotoSource.gallery))!;
    activeUid = 'user-B';
    await expectLater(photos.read('user-A', ref), throwsA(isA<AppFailure>()));
    await expectLater(photos.read('user-B', ref), throwsA(isA<AppFailure>()));
    await expectLater(photos.remove('user-B', ref), throwsA(isA<AppFailure>()));
    activeUid = 'user-A';
    expect(await photos.read('user-A', ref), isNotNull);
  });

  test('malformed absolute/traversal references are refused', () async {
    for (final ref in [
      '/somewhere/private.jpg',
      '../private.jpg',
      'meal_photos/${DeviceMealPhotoService.ownerKey('user-A')}/draft/../../private.jpg',
    ]) {
      await expectLater(photos.read('user-A', ref), throwsA(isA<AppFailure>()));
    }
  });

  test(
    'lost Android result can only be recovered by the original UID',
    () async {
      await prefs.setString(
        'meal_photo.pending_owner',
        DeviceMealPhotoService.ownerKey('user-A'),
      );
      picker.lost = picker.image;
      activeUid = 'user-B';
      expect(await photos.recover('user-B'), isNull);
      expect(picker.recoverCalls, 0);
      activeUid = 'user-A';
      final recovered = await photos.recover('user-A');
      expect(recovered, isNotNull);
      expect(await photos.read('user-A', recovered!), isNotNull);
      expect(picker.recoverCalls, 1);
    },
  );

  test('old records without imagePath still deserialize unchanged', () {
    final legacy = {
      'id': 'old-1',
      'date': '2026-11-11',
      'type': 'lunch',
      'description': 'Bữa cũ',
      'createdAt': '2026-11-11T12:00:00',
    };
    final meal = MealEntry.fromJson(legacy);
    expect(meal.imagePath, isNull);
    expect(meal.description, 'Bữa cũ');
    expect(meal.createdAt, DateTime.parse(legacy['createdAt']!));
    expect(meal.toJson(), {
      ...legacy,
      'createdAt': DateTime.parse(legacy['createdAt']!).toIso8601String(),
    });
  });

  test('repository round-trips a photo through preferences and deletes it with the meal', () async {
    final repo = MealRepository(prefs, FaultInjector(), photos: photos);
    final draft = await photos.pick('user-A', MealPhotoSource.gallery);
    final entry = await repo.add(
      'user-A',
      date: dateKey(today()),
      type: MealType.lunch,
      description: 'Cơm rau',
      photoDraft: draft,
      id: 'owned-meal',
    );
    final restarted = MealRepository(
      await SharedPreferences.getInstance(),
      FaultInjector(),
      photos: photos,
    );
    final restored = (await restarted.forDate(
      'user-A',
      dateKey(today()),
    )).single;
    expect(restored.imagePath, entry.imagePath);
    expect(await photos.read('user-A', restored.imagePath!), isNotNull);
    expect(await photos.read('user-A', draft!), isNull);
    expect(await restarted.forDate('user-B', dateKey(today())), isEmpty);
    await restarted.delete('user-A', entry.id);
    expect(await photos.read('user-A', entry.imagePath!), isNull);
  });

  Future<(AppServices, FakeMealPhotoService, AddMealViewModel)>
  createVm() async {
    final memory = FakeMealPhotoService(currentUid: () => 'demo-user');
    final services = AppServices.fake(
      prefs,
      auth: FakeAuthService(initialUser: const AppUser(uid: 'demo-user')),
      mealPhotos: memory,
    );
    final vm = AddMealViewModel(services, 'demo-user');
    await Future<void>.delayed(Duration.zero);
    vm.setType(MealType.lunch);
    vm.setDescription('Cơm rau');
    return (services, memory, vm);
  }

  test(
    'photo is optional; save remains idempotent under repeated taps',
    () async {
      final (services, _, vm) = await createVm();
      final results = await Future.wait([vm.submit(), vm.submit()]);
      expect(results.where((saved) => saved), hasLength(1));
      expect(
        services.meals.inRange('demo-user', today(), today()).single.imagePath,
        isNull,
      );
      vm.dispose();
    },
  );

  test('failed save keeps selected photo and fields; retry creates one durable entry', () async {
    final (services, memory, vm) = await createVm();
    memory.nextImage = fixture;
    await vm.pickPhoto(MealPhotoSource.gallery);
    final draft = vm.photoReference;
    services.faults.set(FaultPoint.saveMeal, true);
    expect(await vm.submit(), isFalse);
    expect(vm.description, 'Cơm rau');
    expect(vm.photoReference, draft);
    expect(memory.files.keys, [draft]);
    expect(await vm.submit(), isTrue);
    final entries = services.meals.inRange('demo-user', today(), today());
    expect(entries, hasLength(1));
    expect(memory.files.keys, [entries.single.imagePath]);
    expect(await vm.submit(), isFalse);
    vm.dispose();
    expect(memory.files, hasLength(1));
  });

  test(
    'replace/remove/cancel clean up draft photos without changing text',
    () async {
      final (_, memory, vm) = await createVm();
      memory.nextImage = fixture;
      await vm.pickPhoto(MealPhotoSource.camera);
      final first = vm.photoReference;
      await vm.pickPhoto(MealPhotoSource.gallery); // cancel
      expect(vm.photoReference, first);
      memory.nextImage = fixture;
      await vm.pickPhoto(MealPhotoSource.gallery);
      expect(vm.photoReference, isNot(first));
      expect(memory.files, hasLength(1));
      expect(vm.description, 'Cơm rau');
      await vm.removePhoto();
      expect(vm.photoReference, isNull);
      expect(memory.files, isEmpty);
      vm.dispose();
    },
  );

  test('discarding an unsaved photo removes its file', () async {
    final (_, memory, vm) = await createVm();
    memory.nextImage = fixture;
    await vm.pickPhoto(MealPhotoSource.camera);
    expect(vm.isDirty, isTrue);
    await vm.discard();
    expect(memory.files, isEmpty);
    expect(vm.isDirty, isFalse);
    vm.dispose();
  });

  test('camera failure shows a useful error and preserves the draft', () async {
    final (_, memory, vm) = await createVm();
    memory.nextError = const AppFailure('no_available_camera');
    await vm.pickPhoto(MealPhotoSource.camera);
    expect(vm.photoMessage, contains('Không mở được camera'));
    expect(vm.description, 'Cơm rau');
    expect(vm.busy, isFalse);
    vm.dispose();
  });
}

import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Longest side and JPEG quality for uploaded photos: plan.md Phase 10's
/// "photo cleanup on upload". A phone photo is 3–8 MB; this keeps it near
/// 200–400 KB, sharp enough for a listing and quick on island mobile data.
const kUploadMaxSide = 1600.0;
const kUploadQuality = 80;

/// Picks a photo from the phone and uploads it to the business's folder.
///
/// Storage RLS only lets someone who administers the business write to
/// `media/business/<id>/`, so a client cannot upload into another business.
class PhotoUploader {
  PhotoUploader({ImagePicker? picker, this._client})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  final SupabaseClient? _client;

  SupabaseClient get _db {
    final client = _client;
    if (client != null) return client;
    if (!AppConfig.supabaseConfigured) throw const BackendNotConfigured();
    return Supabase.instance.client;
  }

  /// Returns the public URL of the uploaded photo, or null if the owner
  /// cancelled.
  Future<String?> pickAndUpload(
    String businessId, {
    ImageSource source = ImageSource.gallery,
  }) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: kUploadMaxSide,
      maxHeight: kUploadMaxSide,
      imageQuality: kUploadQuality,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final path =
        'business/$businessId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _db.storage
        .from('media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    return _db.storage.from('media').getPublicUrl(path);
  }
}

final photoUploaderProvider = Provider<PhotoUploader>((ref) => PhotoUploader());

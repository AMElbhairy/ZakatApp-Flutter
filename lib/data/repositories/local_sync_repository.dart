import '../local/daos/sync_metadata_dao.dart';

class LocalSyncRepository {
  factory LocalSyncRepository({required SyncMetadataDao syncMetadataDao}) {
    return LocalSyncRepository._(syncMetadataDao);
  }

  LocalSyncRepository._(this._syncMetadataDao);

  final SyncMetadataDao _syncMetadataDao;

  Future<String?> getValue(String key) => _syncMetadataDao.getValue(key);

  Future<void> setValue(String key, String value) {
    return _syncMetadataDao.setValue(key, value);
  }

  Future<String?> getCursor(String collection) {
    return _syncMetadataDao.getCursor(collection);
  }

  Future<void> setCursor(String collection, String value) {
    return _syncMetadataDao.setCursor(collection, value);
  }

  Future<String?> getDeletedCursor(String collection) {
    return _syncMetadataDao.getDeletedCursor(collection);
  }

  Future<void> setDeletedCursor(String collection, String value) {
    return _syncMetadataDao.setDeletedCursor(collection, value);
  }

  Future<String?> getLastSyncSuccessAt() {
    return _syncMetadataDao.getValue(lastSyncSuccessAtKey);
  }

  Future<void> setLastSyncSuccessAt(String value) {
    return _syncMetadataDao.setValue(lastSyncSuccessAtKey, value);
  }
}

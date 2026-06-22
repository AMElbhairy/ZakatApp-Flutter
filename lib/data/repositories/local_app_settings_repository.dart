import '../local/daos/app_settings_dao.dart';

class LocalAppSettingsRepository {
  LocalAppSettingsRepository({required this._appSettingsDao});

  final AppSettingsDao _appSettingsDao;

  Future<String?> getRaw(String key) => _appSettingsDao.getRaw(key);

  Future<void> setRaw(String key, String valueJson) =>
      _appSettingsDao.setRaw(key, valueJson);

  Future<T?> getJson<T>(String key) => _appSettingsDao.getJson<T>(key);

  Future<void> setJson(String key, Object value) =>
      _appSettingsDao.setJson(key, value);

  Future<Map<String, dynamic>> getAllSettings() =>
      _appSettingsDao.getAllSettings();

  Future<void> importSettings(Map<String, dynamic> values) =>
      _appSettingsDao.importSettings(values);
}

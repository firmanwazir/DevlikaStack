import 'package:flutter_test/flutter_test.dart';
import 'package:server_app/services/version_checker_service.dart';

void main() {
  group('Live Upstream PHP Version Detection Tests', () {
    test('checkPhp queries official php.net feed and discovers live versions', () async {
      final checker = VersionCheckerService.instance;
      final updates = await checker.checkPhp(checkOnline: true);

      expect(updates, isNotEmpty);

      // Verify that major series like 8.2 and 8.3 exist
      final versions = updates.map((u) => u.versionKey).toList();
      expect(versions, contains('8.2'));
      expect(versions, contains('8.3'));

      // Check that at least one update has live upstream version populated
      final p82 = updates.firstWhere((u) => u.versionKey == '8.2');
      expect(p82.latestVersion, isNotEmpty);
      expect(p82.latestVersion.startsWith('8.2'), isTrue);
    });
  });
}

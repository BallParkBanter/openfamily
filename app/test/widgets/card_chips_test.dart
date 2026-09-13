import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/models/member_place.dart';
import 'package:openfamily/widgets/card_chips.dart';

void main() {
  test('stat chip wording follows app.js statusText (J:79-85) and the design list', () {
    expect(statChipText(const MemberPlace(atHome: true), driving: false), '🏠 Home');
    expect(statChipText(const MemberPlace(placeName: 'Kroger', homeDistanceM: 4.2 * 1609.344), driving: false),
        '📍 Kroger · 4.2 mi');
    expect(statChipText(const MemberPlace(homeDistanceM: 4.5 * 1609.344), driving: false), '4.5 mi away');
    expect(statChipText(const MemberPlace(placeName: 'Loganville Hwy'), driving: true),
        '🚗 Driving near Loganville Hwy');
    expect(statChipText(const MemberPlace(), driving: true), '🚗 Driving');
    expect(statChipText(const MemberPlace(), driving: false), isNull);
    expect(statChipText(null, driving: true), '🚗 Driving');
    expect(statChipText(null, driving: false), isNull);
  });
  test('detail chips: county with icon, street, since; city separate (J:285-289, design list)', () {
    final p = MemberPlace(county: 'Walton County', street: 'Twin Lakes Drive', city: 'Dacula', since: DateTime(2026, 9, 13, 11, 12));
    expect(detailChipTexts(p, driving: false), ['🌆 Dacula', '🏛️ Walton County', 'Twin Lakes Drive', 'since 11:12 am']);
    expect(detailChipTexts(p, driving: true), ['🌆 Dacula', '🏛️ Walton County', 'since 11:12 am']); // J:287 no street while driving
    expect(detailChipTexts(const MemberPlace(), driving: false), isEmpty);
    expect(detailChipTexts(null, driving: false), isEmpty);
  });
}

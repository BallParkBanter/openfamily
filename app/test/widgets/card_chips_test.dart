import 'package:flutter_test/flutter_test.dart';
import 'package:openfamily/models/member_place.dart';
import 'package:openfamily/widgets/card_chips.dart';

final DateTime now = DateTime(2026, 9, 13, 12, 0);

void main() {
  test('stat chip wording follows app.js statusText (J:79-85) and the design list; miles via place_text milesText (H:79)', () {
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
  test('detail chips: county with icon, street, since; city separate (J:285-289, design list); since via place_text sinceText (H:75-77)', () {
    final p = MemberPlace(county: 'Walton County', street: 'Twin Lakes Drive', city: 'Dacula', since: DateTime(2026, 9, 13, 11, 12));
    expect(detailChipTexts(p, driving: false, now: now), ['🌆 Dacula', '🏛️ Walton County', 'Twin Lakes Drive', 'since 11:12am']);
    expect(detailChipTexts(p, driving: true, now: now), ['🌆 Dacula', '🏛️ Walton County', 'since 11:12am']); // J:287 no street while driving
    expect(detailChipTexts(const MemberPlace(), driving: false, now: now), isEmpty);
    expect(detailChipTexts(null, driving: false, now: now), isEmpty);
  });
  test('since chip shows local wall-clock time for a UTC instant (MemberPlace.since is UTC); a day or more reads "Nd ago"', () {
    final DateTime utc = DateTime.utc(2026, 9, 13, 15, 12);
    expect(detailChipTexts(MemberPlace(since: utc), driving: false, now: utc.toLocal().add(const Duration(hours: 1))),
        detailChipTexts(MemberPlace(since: utc.toLocal()), driving: false, now: utc.toLocal().add(const Duration(hours: 1))));   // holds in any TZ
    expect(detailChipTexts(MemberPlace(since: DateTime(2026, 9, 13, 0, 5)), driving: false, now: now), ['since 12:05am']);
    expect(detailChipTexts(MemberPlace(since: DateTime(2026, 9, 10, 11, 0)), driving: false, now: now), ['since 3d ago']);
  });
}

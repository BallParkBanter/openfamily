package handlers

import (
	"encoding/json"
	"strings"
	"testing"
	"time"

	"github.com/wheresfrank/openfamily/backend/internal/models"
)

// bray: the charging flag rides alongside battery_pct everywhere a member's
// latest position is described. These tests pin the JSON contract the Flutter
// Member model (app/lib/models/member.dart) and the relay on
// BrayNextcloudServer (family-viewer2/relays.py) depend on - no database.

func boolp(b bool) *bool { return &b }

// TestBatchPointDecodesCharging: the ingest body (single and batch share the
// same field set) accepts an optional boolean "charging" and leaves it nil
// when absent, so an old client that never sends it stores NULL, not false.
func TestBatchPointDecodesCharging(t *testing.T) {
	var with, without batchPoint
	if err := json.NewDecoder(strings.NewReader(
		`{"device_id":"d1","lat":33.9,"lon":-84.4,"battery_pct":84,"charging":true}`)).Decode(&with); err != nil {
		t.Fatal(err)
	}
	if with.Charging == nil || !*with.Charging {
		t.Fatalf("charging = %v, want true", with.Charging)
	}
	if with.BatteryPct == nil || *with.BatteryPct != 84 {
		t.Fatalf("battery_pct = %v, want 84 (existing field must survive)", with.BatteryPct)
	}
	if err := json.NewDecoder(strings.NewReader(
		`{"device_id":"d1","lat":33.9,"lon":-84.4}`)).Decode(&without); err != nil {
		t.Fatal(err)
	}
	if without.Charging != nil {
		t.Fatalf("charging = %v, want nil when the client did not send it", *without.Charging)
	}
}

// TestMemberJSONCarriesCharging: the member payload (GET /family/members,
// admin lists) emits "charging" as a JSON bool next to battery_pct, and omits
// it when unknown - the same omitempty behaviour as battery_pct.
func TestMemberJSONCarriesCharging(t *testing.T) {
	pct := 84.0
	m := models.MemberWithLocation{BatteryPct: &pct, Charging: boolp(true)}
	out, err := json.Marshal(m)
	if err != nil {
		t.Fatal(err)
	}
	var got map[string]any
	if err := json.Unmarshal(out, &got); err != nil {
		t.Fatal(err)
	}
	if got["charging"] != true {
		t.Fatalf("charging = %v (%T), want true", got["charging"], got["charging"])
	}
	if got["battery_pct"] != 84.0 {
		t.Fatalf("battery_pct = %v, want 84", got["battery_pct"])
	}
	out, _ = json.Marshal(models.MemberWithLocation{BatteryPct: &pct})
	if strings.Contains(string(out), "charging") {
		t.Fatalf("unknown charging must be omitted, got %s", out)
	}
	out, _ = json.Marshal(models.MemberWithLocation{Charging: boolp(false)})
	if !strings.Contains(string(out), `"charging":false`) {
		t.Fatalf("explicit false must be emitted (unplugged is a fact), got %s", out)
	}
}

// TestWsFramesCarryCharging: the members snapshot, live location and presence
// frames all carry the flag, so the tablet can show the bolt without a reload
// and drop it when the phone is unplugged while stationary (presence path).
func TestWsFramesCarryCharging(t *testing.T) {
	now := time.Date(2026, 9, 13, 12, 0, 0, 0, time.UTC)
	cases := map[string]any{
		"member":   wsMember{ID: "u1", Charging: boolp(true)},
		"location": wsLocation{Type: "location", UserID: "u1", TS: now, LastSeenAt: now, Charging: boolp(true)},
		"presence": wsPresence{Type: "presence", UserID: "u1", TS: now, Charging: boolp(true)},
	}
	for name, v := range cases {
		out, err := json.Marshal(v)
		if err != nil {
			t.Fatal(err)
		}
		if !strings.Contains(string(out), `"charging":true`) {
			t.Fatalf("%s frame missing charging: %s", name, out)
		}
	}
	// The snapshot and location frames are not omitempty (they mirror
	// battery_pct: null means unknown); presence is omitempty like its
	// battery_pct.
	out, _ := json.Marshal(wsMember{ID: "u1"})
	if !strings.Contains(string(out), `"charging":null`) {
		t.Fatalf("member snapshot should emit null for unknown, got %s", out)
	}
	out, _ = json.Marshal(wsPresence{Type: "presence", UserID: "u1", TS: now})
	if strings.Contains(string(out), "charging") {
		t.Fatalf("presence should omit unknown charging, got %s", out)
	}
}

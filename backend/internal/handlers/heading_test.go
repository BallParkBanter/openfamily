package handlers

import (
	"encoding/json"
	"strings"
	"testing"
	"time"

	"github.com/wheresfrank/openfamily/backend/internal/models"
)

// bray piece 5: the direction beam needs the latest heading on every payload
// that describes a member's position (the cone report: heading_deg was stored
// per fix in `locations` only). Same contract as `charging` (charging_test.go):
// the Flutter Member model reads "heading_deg" from the members JSON and the
// live location frame.

func floatp(f float64) *float64 { return &f }

// TestMemberJSONCarriesHeading: GET /family/members (and the admin lists)
// emit "heading_deg" next to speed_mps; omitted when unknown.
func TestMemberJSONCarriesHeading(t *testing.T) {
	m := models.MemberWithLocation{SpeedMPS: floatp(20), HeadingDeg: floatp(275.5)}
	out, err := json.Marshal(m)
	if err != nil {
		t.Fatal(err)
	}
	var got map[string]any
	if err := json.Unmarshal(out, &got); err != nil {
		t.Fatal(err)
	}
	if got["heading_deg"] != 275.5 {
		t.Fatalf("heading_deg = %v (%T), want 275.5", got["heading_deg"], got["heading_deg"])
	}
	out, _ = json.Marshal(models.MemberWithLocation{SpeedMPS: floatp(20)})
	if strings.Contains(string(out), "heading_deg") {
		t.Fatalf("unknown heading must be omitted, got %s", out)
	}
}

// TestWsFramesCarryHeading: the members snapshot and the live location frame
// carry it (null when unknown, mirroring speed_mps); presence frames never do
// (a heartbeat has no fix).
func TestWsFramesCarryHeading(t *testing.T) {
	now := time.Date(2026, 9, 15, 12, 0, 0, 0, time.UTC)
	cases := map[string]any{
		"member":   wsMember{ID: "u1", HeadingDeg: floatp(90)},
		"location": wsLocation{Type: "location", UserID: "u1", TS: now, LastSeenAt: now, HeadingDeg: floatp(90)},
	}
	for name, v := range cases {
		out, err := json.Marshal(v)
		if err != nil {
			t.Fatal(err)
		}
		if !strings.Contains(string(out), `"heading_deg":90`) {
			t.Fatalf("%s frame missing heading_deg: %s", name, out)
		}
	}
	out, _ := json.Marshal(wsMember{ID: "u1"})
	if !strings.Contains(string(out), `"heading_deg":null`) {
		t.Fatalf("member snapshot should emit null for unknown, got %s", out)
	}
	out, _ = json.Marshal(wsLocation{Type: "location", UserID: "u1", TS: now, LastSeenAt: now})
	if !strings.Contains(string(out), `"heading_deg":null`) {
		t.Fatalf("location frame should emit null for unknown, got %s", out)
	}
	out, _ = json.Marshal(wsPresence{Type: "presence", UserID: "u1", TS: now})
	if strings.Contains(string(out), "heading_deg") {
		t.Fatalf("presence must not carry a heading, got %s", out)
	}
}

// TestMemberPositionUpsertsCarryHeading: both ingest paths write heading_deg
// into member_positions. The SQL is inline in the handlers, so the guard is on
// the statement text itself (no database in unit tests).
func TestMemberPositionUpsertsCarryHeading(t *testing.T) {
	for name, sql := range map[string]string{"single": memberPositionUpsertSQL, "batch": memberPositionUpsertSQL} {
		if !strings.Contains(sql, "heading_deg") || !strings.Contains(sql, "heading_deg = EXCLUDED.heading_deg") {
			t.Fatalf("%s upsert does not carry heading_deg:\n%s", name, sql)
		}
	}
}

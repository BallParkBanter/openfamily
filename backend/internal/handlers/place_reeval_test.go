package handlers

// 5b (2026-09-16): a place create / update / delete re-checks every member's
// last fix at once. No database in these tests: the querier is faked and the
// statement's load-bearing clauses are asserted by text.

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
)

// fakeRows yields one text column per row; every other pgx.Rows method
// panics (the embedded interface is nil).
type fakeRows struct {
	pgx.Rows
	ids []string
	i   int
}

func (r *fakeRows) Next() bool             { r.i++; return r.i <= len(r.ids) }
func (r *fakeRows) Scan(dest ...any) error { *(dest[0].(*string)) = r.ids[r.i-1]; return nil }
func (r *fakeRows) Close()                 {}
func (r *fakeRows) Err() error             { return nil }

type fakeQuerier struct {
	sql  string
	args []any
	ids  []string
	err  error
}

func (q *fakeQuerier) Query(_ context.Context, sql string, args ...any) (pgx.Rows, error) {
	q.sql, q.args = sql, args
	if q.err != nil {
		return nil, q.err
	}
	return &fakeRows{ids: q.ids}, nil
}

func TestReevaluateMemberPlacesReturnsTheChangedMembers(t *testing.T) {
	now := time.Date(2026, 9, 16, 13, 25, 0, 0, time.UTC)
	q := &fakeQuerier{ids: []string{"heidi", "charlie"}}
	got, err := reevaluateMemberPlaces(context.Background(), q, "fam-1", now)
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 2 || got[0] != "heidi" || got[1] != "charlie" {
		t.Fatalf("changed members = %v", got)
	}
	if len(q.args) != 2 || q.args[0] != "fam-1" || !q.args[1].(time.Time).Equal(now) {
		t.Fatalf("args = %v", q.args)
	}
	for _, want := range []string{
		"ST_DWithin(p.geom::geography, ST_SetSRID(ST_MakePoint(mp.lon, mp.lat), 4326)::geography, p.radius_meters)",
		"ORDER BY p.radius_meters ASC",                                    // the smallest place wins, as on ingest (updateMemberPlace) and in the app (placeContaining)
		"u.family_id = $1",                                                // the whole family, nobody else
		"mp.place_id IS DISTINCT FROM here.place_id",                      // only rows whose answer changed
		"CASE WHEN here.place_id IS NULL THEN mp.place_since ELSE $2 END", // since = now on entering; kept when a place goes away from under them
		"RETURNING mp.user_id",
	} {
		if !strings.Contains(q.sql, want) {
			t.Errorf("SQL lacks %q:\n%s", want, q.sql)
		}
	}
}

func TestReevaluateMemberPlacesPropagatesTheQueryError(t *testing.T) {
	q := &fakeQuerier{err: errors.New("boom")}
	if _, err := reevaluateMemberPlaces(context.Background(), q, "fam-1", time.Now()); err == nil {
		t.Fatal("expected the query error")
	}
}

func TestMembersAtPlaceListsTheRowsAssignedToThePlace(t *testing.T) {
	q := &fakeQuerier{ids: []string{"heidi"}}
	got, err := membersAtPlace(context.Background(), q, "place-9")
	if err != nil || len(got) != 1 || got[0] != "heidi" {
		t.Fatalf("got %v err %v", got, err)
	}
	if !strings.Contains(q.sql, "WHERE place_id = $1") || q.args[0] != "place-9" {
		t.Fatalf("sql %q args %v", q.sql, q.args)
	}
}

func TestUnionIDsKeepsOrderAndDropsRepeats(t *testing.T) {
	got := unionIDs([]string{"a", "b"}, []string{"b", "c", "a"}, nil)
	if len(got) != 3 || got[0] != "a" || got[1] != "b" || got[2] != "c" {
		t.Fatalf("got %v", got)
	}
	if len(unionIDs()) != 0 {
		t.Fatal("an empty union must be empty")
	}
}

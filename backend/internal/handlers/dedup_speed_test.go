package handlers

import "testing"

func f64(v float64) *float64 { return &v }

func TestSpeedUnchanged(t *testing.T) {
	cases := []struct {
		name           string
		stored, report *float64
		want           bool
	}{
		{"nil/nil - never reported a speed on either side", nil, nil, true},
		{"nil/0 - a speed appeared where there was none", nil, f64(0), false},
		{"0/0 - both stationary", f64(0), f64(0), true},
		{"25/0 - a stop: highway speed to stationary is new information", f64(25), f64(0), false},
		{"25/24.7 - within noise (delta 0.3 < 0.5)", f64(25), f64(24.7), true},
		{"25/24.4 - outside noise (delta 0.6 >= 0.5)", f64(25), f64(24.4), false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got := speedUnchanged(c.stored, c.report)
			if got != c.want {
				t.Fatalf("speedUnchanged(%v, %v) = %v, want %v", c.stored, c.report, got, c.want)
			}
		})
	}
}

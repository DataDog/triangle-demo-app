package models

type TowerDetection struct {
	ID      string  `json:"id"`
	X       int     `json:"x"`
	Y       int     `json:"y"`
	HeardAt float64    `json:"heard_at"`
}

type SignalBundle struct {
	SignalTimestamp int64            `json:"signal_timestamp"`
	Towers          []TowerDetection `json:"towers"`
}

type Detection struct {
	X         float64 `json:"x"`
	Y         float64 `json:"y"`
	Timestamp float64   `json:"timestamp"`
}

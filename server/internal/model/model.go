package model

import "time"

type User struct {
	ID           int64     `gorm:"primaryKey" json:"id"`
	Username     string    `gorm:"size:64;uniqueIndex" json:"username"`
	PasswordHash string    `gorm:"size:255" json:"-"`
	CreatedAt    time.Time `json:"created_at"`
}

type SipAccount struct {
	ID          int64  `gorm:"primaryKey" json:"id"`
	UserID      int64  `gorm:"index" json:"user_id"`
	Extension   string `gorm:"size:32;uniqueIndex" json:"extension"`
	SipPassword string `gorm:"size:64" json:"-"`
	Enabled     bool   `gorm:"default:true" json:"enabled"`
}

type CallRecord struct {
	ID           int64     `gorm:"primaryKey" json:"id"`
	OwnerUserID  int64     `gorm:"index:idx_owner_time,priority:1" json:"-"`
	RemoteNumber string    `gorm:"size:64" json:"remote_number"`
	Direction    string    `gorm:"size:8" json:"direction"`    // in|out|missed
	Disposition  string    `gorm:"size:16" json:"disposition"` // answered|no_answer|busy|failed
	StartedAt    time.Time `gorm:"index:idx_owner_time,priority:2" json:"started_at"`
	DurationSec  int       `json:"duration_sec"`
	CreatedAt    time.Time `json:"created_at"`
}

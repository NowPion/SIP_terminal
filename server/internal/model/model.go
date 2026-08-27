package model

import (
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/schema"
)

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
	Direction    string    `gorm:"size:8" json:"direction"`                           // in|out|missed
	Disposition  string    `gorm:"size:16" json:"disposition"`                        // answered|no_answer|busy|failed
	StartedAt    time.Time `gorm:"index:idx_owner_time,priority:2" json:"started_at"` // 毫秒精度（见 GormDBDataType），与游标 UnixMilli 对齐
	DurationSec  int       `json:"duration_sec"`
	CreatedAt    time.Time `json:"created_at"`
}

// GormDBDataType 按方言选择 StartedAt 列类型：
// MySQL 用 DATETIME(3)=毫秒精度；SQLite（glebarez 驱动）只对无精度后缀的
// datetime 做自动 time.Time 扫描，带 (3) 会退化为 string Scan 失败，
// 故用普通 datetime，精度由写入方截断到毫秒保证。
func (CallRecord) GormDBDataType(db *gorm.DB, _ *schema.Field) string {
	if db != nil && db.Dialector != nil && db.Dialector.Name() == "mysql" {
		return "DATETIME(3)"
	}
	return "datetime"
}

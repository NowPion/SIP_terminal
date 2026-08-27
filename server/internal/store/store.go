package store

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"strconv"
	"sync"

	"github.com/glebarez/sqlite"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"

	"github.com/nie/sip-terminal/server/internal/model"
)

type Store struct {
	DB *gorm.DB

	mu sync.Mutex
}

// Open 连接生产 MySQL。
func Open(dsn string) (*Store, error) {
	db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{})
	return finish(db, err)
}

// OpenSQLite 仅用于单元测试（纯 Go 驱动，Windows 免 cgo）。
func OpenSQLite(path string) (*Store, error) {
	db, err := gorm.Open(sqlite.Open(path), &gorm.Config{})
	return finish(db, err)
}

func finish(db *gorm.DB, err error) (*Store, error) {
	if err != nil {
		return nil, err
	}
	if err := db.AutoMigrate(&model.User{}, &model.SipAccount{}, &model.CallRecord{}); err != nil {
		return nil, err
	}
	return &Store{DB: db}, nil
}

// Close 关闭底层连接池。测试中必须在 t.TempDir 清理前调用，否则 Windows 下文件被占用无法删除。
func (s *Store) Close() error {
	sqlDB, err := s.DB.DB()
	if err != nil {
		return err
	}
	return sqlDB.Close()
}

// AllocateExtension 从1001起找最小未占用分机号（数据量小，内存计算跨方言可移植）。
// 加锁串行化“查-算”窗口，避免并发调用返回同一个分机号。
func (s *Store) AllocateExtension(ctx context.Context) (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	var exts []string
	if err := s.DB.WithContext(ctx).Model(&model.SipAccount{}).Pluck("extension", &exts).Error; err != nil {
		return "", err
	}
	used := make(map[string]bool, len(exts))
	for _, e := range exts {
		used[e] = true
	}
	for i := 1001; ; i++ {
		k := strconv.Itoa(i)
		if !used[k] {
			return k, nil
		}
	}
}

// RandomSecret 生成长度 n 的URL安全随机字符串。
func RandomSecret(n int) (string, error) {
	if n <= 0 {
		return "", errors.New("RandomSecret: n must be positive")
	}
	b := make([]byte, n*2)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(b)[:n], nil
}

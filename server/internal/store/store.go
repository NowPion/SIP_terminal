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
	db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{TranslateError: true})
	return finish(db, err)
}

// OpenSQLite 仅用于单元测试（纯 Go 驱动，Windows 免 cgo）。
func OpenSQLite(path string) (*Store, error) {
	db, err := gorm.Open(sqlite.Open(path), &gorm.Config{TranslateError: true})
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

// RegisterUser 原子创建用户+SIP账号：进程内互斥串行化分机分配，
// 事务保证部分失败全部回滚。多实例部署时由 extension 唯一索引兜底。
func (s *Store) RegisterUser(ctx context.Context, username, passwordHash string) (*model.User, *model.SipAccount, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	u := &model.User{Username: username, PasswordHash: passwordHash}
	var acc *model.SipAccount
	err := s.DB.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(u).Error; err != nil {
			return err
		}
		ext, e := allocateInTx(ctx, tx)
		if e != nil {
			return e
		}
		pass, e := RandomSecret(20)
		if e != nil {
			return e
		}
		acc = &model.SipAccount{UserID: u.ID, Extension: ext, SipPassword: pass, Enabled: true}
		return tx.Create(acc).Error
	})
	if err != nil {
		return nil, nil, err
	}
	return u, acc, nil
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
	return allocateInTx(ctx, s.DB.WithContext(ctx))
}

func allocateInTx(ctx context.Context, tx *gorm.DB) (string, error) {
	var exts []string
	if err := tx.Model(&model.SipAccount{}).Pluck("extension", &exts).Error; err != nil {
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

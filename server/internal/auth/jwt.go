package auth

import (
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	jwt "github.com/golang-jwt/jwt/v5"
)

type Claims struct {
	UserID   int64  `json:"uid"`
	Username string `json:"uname"`
	jwt.RegisteredClaims
}

const (
	ctxUID   = "uid"
	ctxUname = "uname"
)

// UID / Uname 从 Require 注入的上下文取值。
func UID(c *gin.Context) int64    { return c.GetInt64(ctxUID) }
func Uname(c *gin.Context) string { return c.GetString(ctxUname) }

func MakeToken(secret string, userID int64, username string, ttl time.Duration) (string, error) {
	if secret == "" {
		return "", jwt.ErrInvalidKey
	}
	c := Claims{
		UserID: userID, Username: username,
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    "sip-terminal",
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(ttl)),
		},
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, c).SignedString([]byte(secret))
}

func ParseToken(secret, raw string) (int64, string, error) {
	if secret == "" {
		return 0, "", jwt.ErrInvalidKey
	}
	var c Claims
	_, err := jwt.ParseWithClaims(raw, &c, func(t *jwt.Token) (interface{}, error) {
		if t.Method.Alg() != jwt.SigningMethodHS256.Alg() {
			return nil, jwt.ErrSignatureInvalid
		}
		return []byte(secret), nil
	})
	if err != nil {
		return 0, "", err
	}
	return c.UserID, c.Username, nil
}

// Require 校验 Authorization: Bearer <token>，注入 uid/uname 到 gin.Context。
func Require(secret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		raw := strings.TrimSpace(strings.TrimPrefix(c.GetHeader("Authorization"), "Bearer "))
		uid, uname, err := ParseToken(secret, raw)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
			return
		}
		c.Set(ctxUID, uid)
		c.Set(ctxUname, uname)
		c.Next()
	}
}

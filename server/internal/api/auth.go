package api

import (
	"errors"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	"github.com/nie/sip-terminal/server/internal/auth"
	"github.com/nie/sip-terminal/server/internal/model"
)

const tokenTTL = 30 * 24 * time.Hour // 第一版：长效token，不做refresh

type credReq struct {
	Username string `json:"username" binding:"required,min=3,max=32"`
	Password string `json:"password" binding:"required,min=6,max=64"`
}

type sipAccountDTO struct {
	Extension string `json:"extension"`
	Password  string `json:"password"`
}

func (h *Handler) Register(c *gin.Context) {
	var req credReq
	if c.ShouldBindJSON(&req) != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "用户名3-32位，密码至少6位"})
		return
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "hash"})
		return
	}
	u, acc, err := h.ST.RegisterUser(c.Request.Context(), req.Username, string(hash))
	if err != nil {
		if errors.Is(err, gorm.ErrDuplicatedKey) {
			c.JSON(http.StatusConflict, gin.H{"error": "用户名已存在"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "register"})
		return
	}
	token, err := auth.MakeToken(h.Secret, u.ID, u.Username, tokenTTL)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "token"})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"token":       token,
		"sip_account": sipAccountDTO{Extension: acc.Extension, Password: acc.SipPassword},
	})
}

func (h *Handler) Login(c *gin.Context) {
	var req credReq
	if c.ShouldBindJSON(&req) != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "用户名3-32位，密码至少6位"})
		return
	}
	var u model.User
	if err := h.ST.DB.Where("username = ?", req.Username).First(&u).Error; err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "用户名或密码错误"})
		return
	}
	if bcrypt.CompareHashAndPassword([]byte(u.PasswordHash), []byte(req.Password)) != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "用户名或密码错误"})
		return
	}
	token, err := auth.MakeToken(h.Secret, u.ID, u.Username, tokenTTL)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "token"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"token": token})
}

func (h *Handler) MeSipAccount(c *gin.Context) {
	var acc model.SipAccount
	err := h.ST.DB.Where("user_id = ? AND enabled = ?", auth.UID(c), true).First(&acc).Error
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "无可用SIP账号"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"extension": acc.Extension, "password": acc.SipPassword})
}

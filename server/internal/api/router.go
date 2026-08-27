package api

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/nie/sip-terminal/server/internal/auth"
	"github.com/nie/sip-terminal/server/internal/store"
)

// New 组装全部路由。Task4 将在 authed 分组追加 calls 三条路由；
// Task5 将在 api 分组追加 fsw/directory。挂载点见注释。
func New(st *store.Store, jwtSecret string) *gin.Engine {
	h := &Handler{ST: st, Secret: jwtSecret}

	r := gin.Default()
	api := r.Group("/api/v1")
	{
		api.POST("/auth/register", h.Register)
		api.POST("/auth/login", h.Login)
		authed := api.Group("", auth.Require(jwtSecret))
		authed.GET("/me/sip-account", h.MeSipAccount)
		// Task4 追加点：
		// authed.POST("/calls", h.CreateCall)
		// authed.GET("/calls", h.ListCalls)
		// authed.DELETE("/calls/:id", h.DeleteCall)
	}
	r.GET("/healthz", func(c *gin.Context) { c.JSON(http.StatusOK, gin.H{"ok": true}) })
	return r
}

type Handler struct {
	ST     *store.Store
	Secret string
}

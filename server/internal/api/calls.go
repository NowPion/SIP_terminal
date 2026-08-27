package api

import (
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/nie/sip-terminal/server/internal/auth"
	"github.com/nie/sip-terminal/server/internal/model"
)

var validDirection = map[string]bool{"in": true, "out": true, "missed": true}
var validDisposition = map[string]bool{"answered": true, "no_answer": true, "busy": true, "failed": true}

type createCallReq struct {
	Direction    string    `json:"direction" binding:"required"`
	Disposition  string    `json:"disposition" binding:"required"`
	RemoteNumber string    `json:"remote_number" binding:"required,max=64"`
	DurationSec  int       `json:"duration_sec"`
	StartedAt    time.Time `json:"started_at"`
}

type callCursor struct {
	Time int64 `json:"time"` // 最后一条 StartedAt 的 UnixMilli
	ID   int64 `json:"id"`
}

type listCallResp struct {
	Items      []model.CallRecord `json:"items"`
	NextCursor *callCursor        `json:"next_cursor"`
}

func (h *Handler) CreateCall(c *gin.Context) {
	var req createCallReq
	if c.ShouldBindJSON(&req) != nil ||
		!validDirection[req.Direction] || !validDisposition[req.Disposition] {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数非法：direction/disposition/remote_number"})
		return
	}
	if req.StartedAt.IsZero() {
		req.StartedAt = time.Now().UTC()
	}
	// 统一截断到毫秒：与 SQLite datetime 存储及游标 UnixMilli 对齐，避免亚毫秒残留破坏 before_id 边界。
	req.StartedAt = req.StartedAt.Truncate(time.Millisecond)
	rec := model.CallRecord{
		OwnerUserID:  auth.UID(c),
		Direction:    req.Direction,
		Disposition:  req.Disposition,
		RemoteNumber: req.RemoteNumber,
		DurationSec:  req.DurationSec,
		StartedAt:    req.StartedAt.UTC(),
	}
	if err := h.ST.DB.Create(&rec).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "save"})
		return
	}
	c.JSON(http.StatusOK, rec)
}

func (h *Handler) ListCalls(c *gin.Context) {
	limit := 20
	if q := c.Query("limit"); q != "" {
		if n, err := strconv.Atoi(q); err == nil && n > 0 && n <= 50 {
			limit = n
		}
	}
	db := h.ST.DB.Where("owner_user_id = ?", auth.UID(c))
	bt, bid := c.Query("before_time"), c.Query("before_id")
	if bt != "" || bid != "" {
		tm, err1 := time.Parse(time.RFC3339Nano, bt)
		id, err2 := strconv.ParseInt(bid, 10, 64)
		if err1 != nil || err2 != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "非法游标参数"})
			return
		}
		db = db.Where("(started_at < ? OR (started_at = ? AND id < ?))", tm.UTC(), tm.UTC(), id)
	}
	var items = make([]model.CallRecord, 0, limit)
	if err := db.Order("started_at DESC, id DESC").Limit(limit).Find(&items).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "query"})
		return
	}
	resp := listCallResp{Items: items}
	if len(items) == limit { // 满页才给游标（客户端以此判断还有下一页）
		last := items[len(items)-1]
		resp.NextCursor = &callCursor{Time: last.StartedAt.UnixMilli(), ID: last.ID}
	}
	c.JSON(http.StatusOK, resp)
}

func (h *Handler) DeleteCall(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "非法ID"})
		return
	}
	res := h.ST.DB.Where("id = ? AND owner_user_id = ?", id, auth.UID(c)).Delete(&model.CallRecord{})
	if res.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "delete"})
		return
	}
	if res.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "记录不存在"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"deleted": id})
}

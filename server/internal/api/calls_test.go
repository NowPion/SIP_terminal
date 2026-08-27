package api

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/nie/sip-terminal/server/internal/model"
)

// 注册第 n 个用户即 uid=n（自增ID从1开始，与全局注册顺序一致）。
func mustRegister(t *testing.T, r http.Handler, name string) string {
	t.Helper()
	rec := postJSON(r, "/api/v1/auth/register", map[string]string{"username": name, "password": "secret6"})
	if rec.Code != http.StatusOK {
		t.Fatalf("register %s: %d %s", name, rec.Code, rec.Body.String())
	}
	var out struct {
		Token string `json:"token"`
	}
	json.Unmarshal(rec.Body.Bytes(), &out)
	return out.Token
}

func getWithToken(r http.Handler, path, token string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(http.MethodGet, path, nil)
	req.Header.Set("Authorization", "Bearer "+token)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)
	return rec
}

func deleteWithToken(r http.Handler, path, token string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(http.MethodDelete, path, nil)
	req.Header.Set("Authorization", "Bearer "+token)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)
	return rec
}

// postJSONWithToken 与 postJSON 相同，但附带 Bearer 认证头。
func postJSONWithToken(r http.Handler, path string, body any, token string) *httptest.ResponseRecorder {
	b, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, path, bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)
	return rec
}

func TestCreateCallValidatesEnumAndAuth(t *testing.T) {
	r, _ := newTestRouter(t)
	token := mustRegister(t, r, "calla")

	bad := postJSONWithToken(r, "/api/v1/calls", map[string]any{
		"direction": "sideways", "disposition": "answered", "remote_number": "1002",
	}, token)
	if bad.Code != http.StatusBadRequest {
		t.Fatalf("invalid direction want 400 got %d", bad.Code)
	}

	if noauth := postJSON(r, "/api/v1/calls", map[string]any{
		"direction": "out", "disposition": "answered", "remote_number": "1002",
	}); noauth.Code != http.StatusUnauthorized {
		t.Fatalf("no token want 401 got %d", noauth.Code)
	}
}

func TestCreateCallOkShape(t *testing.T) {
	r, st := newTestRouter(t)
	token := mustRegister(t, r, "callz")
	body := map[string]any{
		"direction":     "out",
		"disposition":   "answered",
		"remote_number": "1002",
		"duration_sec":  63,
		"started_at":    time.Now().UTC().Format(time.RFC3339Nano),
	}
	b, _ := json.Marshal(body)
	rq := httptest.NewRequest(http.MethodPost, "/api/v1/calls", bytes.NewReader(b))
	rq.Header.Set("Content-Type", "application/json")
	rq.Header.Set("Authorization", "Bearer "+token)
	rr := httptest.NewRecorder()
	r.ServeHTTP(rr, rq)
	if rr.Code != http.StatusOK {
		t.Fatalf("%d %s", rr.Code, rr.Body.String())
	}
	var got model.CallRecord
	json.Unmarshal(rr.Body.Bytes(), &got)
	if got.ID == 0 || got.RemoteNumber != "1002" || got.DurationSec != 63 {
		t.Fatalf("echoed record wrong: %+v", got)
	}
	var saved model.CallRecord
	if err := st.DB.First(&saved, got.ID).Error; err != nil {
		t.Fatal(err)
	}
	if saved.OwnerUserID != 1 || saved.Direction != "out" || saved.Disposition != "answered" {
		t.Fatalf("saved record wrong: %+v", saved)
	}
	var count int64
	st.DB.Model(&model.CallRecord{}).Count(&count)
	if count != 1 {
		t.Fatalf("db count want 1 got %d", count)
	}
}

func TestCreateAndListCallsCursorPagination(t *testing.T) {
	r, st := newTestRouter(t)
	token := mustRegister(t, r, "callb")

	now := time.Now().UTC().Truncate(time.Second)
	for i := 0; i < 25; i++ {
		st.DB.Create(&model.CallRecord{
			OwnerUserID: 1, Direction: "out", Disposition: "answered",
			RemoteNumber: fmt.Sprintf("10%02d", i),
			StartedAt:    now.Add(-time.Duration(i) * time.Minute), DurationSec: i,
		})
	}

	pageType := struct {
		Items  []model.CallRecord `json:"items"`
		Cursor *struct {
			Time int64 `json:"time"`
			ID   int64 `json:"id"`
		} `json:"next_cursor"`
	}{}

	p1 := getWithToken(r, "/api/v1/calls", token)
	if p1.Code != http.StatusOK {
		t.Fatalf("%d %s", p1.Code, p1.Body.String())
	}
	json.Unmarshal(p1.Body.Bytes(), &pageType)
	if len(pageType.Items) != 20 {
		t.Fatalf("page1 want 20 got %d", len(pageType.Items))
	}
	if pageType.Cursor == nil || pageType.Cursor.ID == 0 {
		t.Fatal("page1 should carry next_cursor")
	}

	url2 := fmt.Sprintf("/api/v1/calls?before_time=%s&before_id=%d",
		time.UnixMilli(pageType.Cursor.Time).UTC().Format(time.RFC3339Nano), pageType.Cursor.ID)
	p2 := getWithToken(r, url2, token)
	var page2 struct {
		Items  []model.CallRecord `json:"items"`
		Cursor *struct{}          `json:"next_cursor"`
	}
	json.Unmarshal(p2.Body.Bytes(), &page2)
	if len(page2.Items) != 5 {
		t.Fatalf("page2 want 5 got %d", len(page2.Items))
	}
	newestOfP2 := page2.Items[0]
	oldestOfP1 := pageType.Items[len(pageType.Items)-1]
	if !newestOfP2.StartedAt.Before(oldestOfP1.StartedAt) &&
		newestOfP2.StartedAt.Equal(oldestOfP1.StartedAt) && newestOfP2.ID >= oldestOfP1.ID {
		t.Fatal("page2 overlaps page1 boundary")
	}
}

func TestDeleteOnlyOwnRecord(t *testing.T) {
	r, st := newTestRouter(t)
	tokenDave := mustRegister(t, r, "dave") // uid=1
	tokenEve := mustRegister(t, r, "eve")   // uid=2

	st.DB.Create(&model.CallRecord{OwnerUserID: 1, Direction: "in", Disposition: "missed",
		RemoteNumber: "1002", StartedAt: time.Now()})

	if c := deleteWithToken(r, "/api/v1/calls/999", tokenDave).Code; c != http.StatusNotFound {
		t.Fatalf("unknown id want 404 got %d", c)
	}
	if c := deleteWithToken(r, "/api/v1/calls/abc", tokenDave).Code; c != http.StatusBadRequest {
		t.Fatalf("non-numeric id want 400 got %d", c)
	}
	if c := deleteWithToken(r, "/api/v1/calls/1", tokenEve).Code; c != http.StatusNotFound {
		t.Fatalf("cross-user delete want 404 got %d", c)
	}
	if c := deleteWithToken(r, "/api/v1/calls/1", tokenDave).Code; c != http.StatusOK {
		t.Fatalf("own delete want 200 got %d", c)
	}
}

package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

type registerRespBody struct {
	Token      string `json:"token"`
	SipAccount struct {
		Extension string `json:"extension"`
	} `json:"sip_account"`
}

func TestRegisterCreatesUserAndSipAccount(t *testing.T) {
	r, _ := newTestRouter(t)
	rec := postJSON(r, "/api/v1/auth/register", map[string]string{"username": "alice", "password": "secret6"})
	if rec.Code != http.StatusOK {
		t.Fatalf("%d %s", rec.Code, rec.Body.String())
	}
	var out registerRespBody
	json.Unmarshal(rec.Body.Bytes(), &out)
	if out.Token == "" || out.SipAccount.Extension != "1001" {
		t.Fatalf("token=%q ext=%q", out.Token, out.SipAccount.Extension)
	}

	if dup := postJSON(r, "/api/v1/auth/register", map[string]string{"username": "alice", "password": "secret6"}); dup.Code != http.StatusConflict {
		t.Fatalf("dup username want 409 got %d", dup.Code)
	}

	if bad := postJSON(r, "/api/v1/auth/register", map[string]string{"username": "ab", "password": "secret6"}); bad.Code != http.StatusBadRequest {
		t.Fatalf("short username want 400 got %d", bad.Code)
	}
}

func TestLoginOkAndWrongPassword401(t *testing.T) {
	r, _ := newTestRouter(t)
	postJSON(r, "/api/v1/auth/register", map[string]string{"username": "bob", "password": "secret6"})

	ok := postJSON(r, "/api/v1/auth/login", map[string]string{"username": "bob", "password": "secret6"})
	if ok.Code != http.StatusOK {
		t.Fatalf("login want 200 got %d %s", ok.Code, ok.Body.String())
	}

	bad := postJSON(r, "/api/v1/auth/login", map[string]string{"username": "bob", "password": "wrong!!"})
	if bad.Code != http.StatusUnauthorized {
		t.Fatalf("wrong pass want 401 got %d", bad.Code)
	}
}

func TestMeSipAccountFlow(t *testing.T) {
	r, _ := newTestRouter(t)
	reg := postJSON(r, "/api/v1/auth/register", map[string]string{"username": "carl", "password": "secret6"})
	var out registerRespBody
	json.Unmarshal(reg.Body.Bytes(), &out)

	unauth := httptest.NewRecorder()
	r.ServeHTTP(unauth, httptest.NewRequest(http.MethodGet, "/api/v1/me/sip-account", nil))
	if unauth.Code != http.StatusUnauthorized {
		t.Fatalf("no token want 401 got %d", unauth.Code)
	}

	authed := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/me/sip-account", nil)
	req.Header.Set("Authorization", "Bearer "+out.Token)
	r.ServeHTTP(authed, req)
	if authed.Code != http.StatusOK {
		t.Fatalf("%d %s", authed.Code, authed.Body.String())
	}
	var acc struct {
		Extension string `json:"extension"`
		Password  string `json:"password"`
	}
	json.Unmarshal(authed.Body.Bytes(), &acc)
	if acc.Extension != "1001" || acc.Password == "" {
		t.Fatalf("ext=%q pass=%q", acc.Extension, acc.Password)
	}
}

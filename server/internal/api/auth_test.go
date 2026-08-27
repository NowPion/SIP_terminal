package api

import (
	"encoding/json"
	"fmt"
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

func TestSecondRegisterGetsNextExtension(t *testing.T) {
	r, _ := newTestRouter(t)
	first := postJSON(r, "/api/v1/auth/register", map[string]string{"username": "u01", "password": "secret6"})
	second := postJSON(r, "/api/v1/auth/register", map[string]string{"username": "u02", "password": "secret6"})
	if first.Code != http.StatusOK || second.Code != http.StatusOK {
		t.Fatalf("%d %d", first.Code, second.Code)
	}
	var out registerRespBody
	json.Unmarshal(second.Body.Bytes(), &out)
	if out.SipAccount.Extension != "1002" {
		t.Fatalf("want 1002 got %q", out.SipAccount.Extension)
	}
}

func TestLoginUnknownUser401(t *testing.T) {
	r, _ := newTestRouter(t)
	rec := postJSON(r, "/api/v1/auth/login", map[string]string{"username": "ghost", "password": "secret6"})
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("want 401 got %d", rec.Code)
	}
}

func TestConcurrentRegistersAllDistinctExtensions(t *testing.T) {
	r, _ := newTestRouter(t)
	const n = 10
	type result struct {
		code int
		ext  string
	}
	ch := make(chan result, n)
	for i := 0; i < n; i++ {
		name := fmt.Sprintf("cc%02d", i)
		go func() {
			rec := postJSON(r, "/api/v1/auth/register", map[string]string{"username": name, "password": "secret6"})
			res := result{code: rec.Code}
			var out registerRespBody
			json.Unmarshal(rec.Body.Bytes(), &out)
			res.ext = out.SipAccount.Extension
			ch <- res
		}()
	}
	exts := map[string]bool{}
	fiveXX := 0
	for i := 0; i < n; i++ {
		res := <-ch
		if res.code >= 500 {
			fiveXX++
		}
		exts[res.ext] = true
	}
	if fiveXX > 0 {
		t.Fatalf("got %d 5xx under concurrency", fiveXX)
	}
	if len(exts) != n {
		t.Fatalf("want %d distinct extensions got %d", n, len(exts))
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

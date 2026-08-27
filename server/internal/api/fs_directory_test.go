package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"

	"github.com/nie/sip-terminal/server/internal/model"
)

func fsDirectoryPost(r http.Handler, form url.Values) *httptest.ResponseRecorder {
	req := httptest.NewRequest(http.MethodPost, "/api/v1/fsw/directory", strings.NewReader(form.Encode()))
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)
	return rec
}

func directoryForm(user string) url.Values {
	return url.Values{
		"section":   {"directory"},
		"tag":       {"domain"},
		"key_name":  {"id"},
		"key_value": {user},
		"user":      {user},
		"domain":    {"fs.local"},
		"action":    {"sip_auth"},
	}
}

func TestDirectoryReturnsUserXMLForKnownExt(t *testing.T) {
	r, _ := newTestRouter(t)
	reg := postJSON(r, "/api/v1/auth/register", map[string]string{"username": "fred01", "password": "secret6"})
	if reg.Code != http.StatusOK {
		t.Fatalf("register seed failed: %d %s", reg.Code, reg.Body.String())
	}
	var seeded struct {
		SipAccount struct {
			Extension string `json:"extension"`
			Password  string `json:"password"`
		} `json:"sip_account"`
	}
	if err := json.Unmarshal(reg.Body.Bytes(), &seeded); err != nil {
		t.Fatal(err)
	}

	rec := fsDirectoryPost(r, directoryForm(seeded.SipAccount.Extension))
	body := rec.Body.String()
	if rec.Code != http.StatusOK {
		t.Fatalf("FS always gets 200 got %d", rec.Code)
	}
	for _, want := range []string{
		`<section name="directory"`,
		`<user id="` + seeded.SipAccount.Extension + `">`,
		`<param name="password" value="` + seeded.SipAccount.Password + `"/>`,
		`<variable name="user_context" value="default"/>`,
		`domain name="fs.local"`,
	} {
		if !strings.Contains(body, want) {
			t.Fatalf("missing %q in:\n%s", want, body)
		}
	}
}

func TestDirectoryNotFoundXML(t *testing.T) {
	r, _ := newTestRouter(t)
	rec := fsDirectoryPost(r, directoryForm("9999"))
	if rec.Code != http.StatusOK {
		t.Fatalf("want 200 got %d", rec.Code)
	}
	if ct := rec.Header().Get("Content-Type"); !strings.HasPrefix(ct, "text/xml") {
		t.Fatalf("content-type %q", ct)
	}
	body := rec.Body.String()
	for _, want := range []string{`<result status="not found"/>`, `<document type="freeswitch/xml">`} {
		if !strings.Contains(body, want) {
			t.Fatalf("missing %q in %s", want, body)
		}
	}
}

func TestDirectoryDisabledAccountNotFound(t *testing.T) {
	r, st := newTestRouter(t)
	postJSON(r, "/api/v1/auth/register", map[string]string{"username": "gone01", "password": "secret6"})
	st.DB.Model(&model.SipAccount{}).Where("1=1").Update("enabled", false)

	rec := fsDirectoryPost(r, directoryForm("1001"))
	if !strings.Contains(rec.Body.String(), `<result status="not found"/>`) {
		t.Fatalf("disabled account must be not-found, got %s", rec.Body.String())
	}
}

func TestDirectoryFallsBackToUserField(t *testing.T) {
	r, _ := newTestRouter(t)
	reg := postJSON(r, "/api/v1/auth/register", map[string]string{"username": "fbak01", "password": "secret6"})
	if reg.Code != http.StatusOK {
		t.Fatal("seed register failed")
	}
	form := directoryForm("") // key_value empty
	form.Set("user", "1001")
	if !strings.Contains(fsDirectoryPost(r, form).Body.String(), `<user id="1001">`) {
		t.Fatal("expected lookup via user field fallback")
	}
}

func TestDirectoryEmptyUserReturnsNotFound(t *testing.T) {
	r, _ := newTestRouter(t)
	rec := fsDirectoryPost(r, url.Values{"section": {"directory"}})
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), `<result status="not found"/>`) {
		t.Fatalf("want 200 not-found got %d %s", rec.Code, rec.Body.String())
	}
}

func TestDirectoryMaliciousDomainIsEscaped(t *testing.T) {
	r, _ := newTestRouter(t)
	postJSON(r, "/api/v1/auth/register", map[string]string{"username": "esc01", "password": "secret6"})
	form := directoryForm("1001")
	form.Set("domain", `fs.local"></domain><user id="9999"><params><param name="password" value="x`)
	body := fsDirectoryPost(r, form).Body.String()
	if strings.Contains(body, `<user id="9999">`) || !strings.Contains(body, "&lt;/domain&gt;") {
		t.Fatalf("injection payload not neutralized:\n%s", body)
	}
}

// 回归：internal profile 配了 force-register-domain，FS auth 查询里
// key_value=domain、user=分机；若按 key_value 查库会 not-found 并落入
// 静态目录的 pointer 占位用户（403 Can't register a pointer）。
func TestDirectoryAuthLookupPrefersUserFieldOverDomainKeyValue(t *testing.T) {
	r, _ := newTestRouter(t)
	reg := postJSON(r, "/api/v1/auth/register", map[string]string{"username": "frd02", "password": "secret6"})
	var seeded struct {
		SipAccount struct {
			Extension string `json:"extension"`
		} `json:"sip_account"`
	}
	if err := json.Unmarshal(reg.Body.Bytes(), &seeded); err != nil {
		t.Fatal(err)
	}

	form := url.Values{
		"section":   {"directory"},
		"tag_name":  {"domain"},
		"key_name":  {"name"},
		"key_value": {"172.20.0.3"}, // force-register-domain 的取值，不是分机
		"user":      {seeded.SipAccount.Extension},
		"domain":    {"172.20.0.3"},
		"action":    {"sip_auth"},
	}
	body := fsDirectoryPost(r, form).Body.String()
	if !strings.Contains(body, `<user id="`+seeded.SipAccount.Extension+`">`) {
		t.Fatalf("auth lookup must resolve user field, got:\n%s", body)
	}
	if !strings.Contains(body, `domain name="172.20.0.3"`) {
		t.Fatalf("user must be wrapped in the requested domain:\n%s", body)
	}
}

// 纯 domain 查询（无 user 字段）：回最小骨架接管该 domain，
// 防止 FS 落入静态目录匹配 pointer 占位用户。
func TestDirectoryDomainOnlyLookupReturnsSkeleton(t *testing.T) {
	r, _ := newTestRouter(t)
	form := url.Values{
		"section":   {"directory"},
		"tag_name":  {"domain"},
		"key_name":  {"name"},
		"key_value": {"172.20.0.3"},
		"domain":    {"172.20.0.3"},
	}
	body := fsDirectoryPost(r, form).Body.String()
	if !strings.Contains(body, `<domain name="172.20.0.3">`) || strings.Contains(body, "<user ") {
		t.Fatalf("want empty domain skeleton, got:\n%s", body)
	}
}

package api

import (
	"crypto/md5"
	"encoding/hex"
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
		`<param name="a1-hash" value="`,
		`<variable name="user_context" value="default"/>`,
		`domain name="fs.local"`,
	} {
		if !strings.Contains(body, want) {
			t.Fatalf("missing %q in:\n%s", want, body)
		}
	}
	sum := md5.Sum([]byte(seeded.SipAccount.Extension + ":fs.local:" + seeded.SipAccount.Password))
	wantHash := hex.EncodeToString(sum[:])
	if !strings.Contains(body, `value="`+wantHash+`"`) {
		t.Fatalf("a1-hash mismatch for ext %s domain fs.local:\n%s", seeded.SipAccount.Extension, body)
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

package auth

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
)

func TestTokenRoundTrip(t *testing.T) {
	token, err := MakeToken("s3cret", 42, "alice", time.Minute)
	if err != nil {
		t.Fatal(err)
	}
	uid, uname, err := ParseToken("s3cret", token)
	if err != nil || uid != 42 || uname != "alice" {
		t.Fatalf("uid=%d name=%s err=%v", uid, uname, err)
	}
	if _, _, err := ParseToken("wrong-key", token); err == nil {
		t.Fatal("wrong secret should fail")
	}
	if _, _, err := ParseToken("", token); err == nil {
		t.Fatal("empty secret must be rejected")
	}
	if _, err := MakeToken("", 1, "x", time.Minute); err == nil {
		t.Fatal("MakeToken empty secret must fail")
	}

	expired, _ := MakeToken("s3cret", 42, "alice", -time.Minute)
	if _, _, err := ParseToken("s3cret", expired); err == nil {
		t.Fatal("expired should fail")
	}
}

func TestRequireMiddleware(t *testing.T) {
	gin.SetMode(gin.TestMode)
	token, err := MakeToken("s3cret", 7, "bob", time.Minute)
	if err != nil {
		t.Fatal(err)
	}

	router := gin.New()
	router.GET("/me", Require("s3cret"), func(c *gin.Context) {
		c.String(http.StatusOK, "%d:%s", c.GetInt64("uid"), c.GetString("uname"))
	})

	ok := httptest.NewRecorder()
	reqOK := httptest.NewRequest("GET", "/me", nil)
	reqOK.Header.Set("Authorization", "Bearer "+token)
	router.ServeHTTP(ok, reqOK)
	if ok.Code != http.StatusOK || ok.Body.String() != "7:bob" {
		t.Fatalf("valid want 200 got %d %q", ok.Code, ok.Body.String())
	}

	no := httptest.NewRecorder()
	router.ServeHTTP(no, httptest.NewRequest("GET", "/me", nil))
	if no.Code != http.StatusUnauthorized {
		t.Fatalf("missing header want 401 got %d", no.Code)
	}

	garbage := httptest.NewRecorder()
	reqBad := httptest.NewRequest("GET", "/me", nil)
	reqBad.Header.Set("Authorization", "Bearer not-a-jwt")
	router.ServeHTTP(garbage, reqBad)
	if garbage.Code != http.StatusUnauthorized {
		t.Fatalf("garbage token want 401 got %d", garbage.Code)
	}
}

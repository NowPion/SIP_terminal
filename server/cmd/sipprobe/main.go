// Command sipprobe registers a SIP extension over UDP with digest
// authentication, proving the chain FreeSWITCH -> mod_xml_curl -> go-api
// -> MySQL. It exits 0 on a final 200 OK, 1 otherwise.
package main

import (
	"crypto/md5"
	"crypto/rand"
	"encoding/hex"
	"flag"
	"fmt"
	"net"
	"os"
	"regexp"
	"strings"
	"time"
)

var paramRe = regexp.MustCompile(`(\w+)=(?:"([^"]*)"|([^\s",]+))`)

func md5hex(s string) string {
	sum := md5.Sum([]byte(s))
	return hex.EncodeToString(sum[:])
}

func randHex(n int) string {
	b := make([]byte, n)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

// parseAuthParams extracts key=value pairs from a WWW-Authenticate header.
func parseAuthParams(h string) map[string]string {
	m := map[string]string{}
	for _, g := range paramRe.FindAllStringSubmatch(h, -1) {
		v := g[2]
		if v == "" {
			v = g[3]
		}
		m[g[1]] = v
	}
	return m
}

func headerValue(msg, name string) string {
	for _, line := range strings.Split(msg, "\r\n") {
		if i := strings.Index(line, ":"); i > 0 && strings.EqualFold(strings.TrimSpace(line[:i]), name) {
			return strings.TrimSpace(line[i+1:])
		}
	}
	return ""
}

func statusLine(msg string) string {
	if i := strings.Index(msg, "\r\n"); i >= 0 {
		return msg[:i]
	}
	return msg
}

func buildRegister(domain, ext, laddr, callid, tag, branch string, cseq, expires int, auth string) string {
	uri := "sip:" + domain
	var b strings.Builder
	fmt.Fprintf(&b, "REGISTER %s SIP/2.0\r\n", uri)
	fmt.Fprintf(&b, "Via: SIP/2.0/UDP %s;branch=%s;rport\r\n", laddr, branch)
	fmt.Fprintf(&b, "From: <sip:%s@%s>;tag=%s\r\n", ext, domain, tag)
	fmt.Fprintf(&b, "To: <sip:%s@%s>\r\n", ext, domain)
	fmt.Fprintf(&b, "Call-ID: %s\r\n", callid)
	fmt.Fprintf(&b, "CSeq: %d REGISTER\r\n", cseq)
	fmt.Fprintf(&b, "Contact: <sip:%s@%s>\r\n", ext, laddr)
	fmt.Fprintf(&b, "Max-Forwards: 70\r\n")
	fmt.Fprintf(&b, "Expires: %d\r\n", expires)
	if auth != "" {
		fmt.Fprintf(&b, "Authorization: %s\r\n", auth)
	}
	fmt.Fprintf(&b, "Content-Length: 0\r\n\r\n")
	return b.String()
}

// transact sends msg and reads replies (3s timeout each, max 5 reads) until
// one matches callid.
func transact(conn *net.UDPConn, msg, callid string) (string, error) {
	if _, err := conn.Write([]byte(msg)); err != nil {
		return "", err
	}
	buf := make([]byte, 8192)
	for n := 0; n < 5; n++ {
		_ = conn.SetReadDeadline(time.Now().Add(3 * time.Second))
		rn, err := conn.Read(buf)
		if err != nil {
			continue
		}
		resp := string(buf[:rn])
		if strings.Contains(resp, callid) {
			return resp, nil
		}
	}
	return "", fmt.Errorf("no response matching Call-ID %s", callid)
}

// digestResponse implements RFC 2617 response with optional qop=auth.
func digestResponse(user, realm, pass, nonce, uri, qop, cnonce string) string {
	ha1 := md5hex(user + ":" + realm + ":" + pass)
	ha2 := md5hex("REGISTER:" + uri)
	if qop == "" {
		return md5hex(ha1 + ":" + nonce + ":" + ha2)
	}
	return md5hex(ha1 + ":" + nonce + ":00000001:" + cnonce + ":" + qop + ":" + ha2)
}

func fail(format string, a ...any) int {
	fmt.Fprintf(os.Stderr, format+"\n", a...)
	return 1
}

func run(server, ext, pass, domain string, expires int) int {
	raddr, err := net.ResolveUDPAddr("udp", server)
	if err != nil {
		return fail("resolve %s: %v", server, err)
	}
	conn, err := net.DialUDP("udp", nil, raddr)
	if err != nil {
		return fail("dial udp: %v", err)
	}
	defer conn.Close()
	laddr := conn.LocalAddr().String() // local ip:port, used in Via/Contact
	learnDomain := domain == "auto"
	if learnDomain {
		domain = raddr.IP.String() // placeholder until the 401 realm reveals the real domain
	}

	// Round 1: unauthenticated REGISTER to obtain the digest challenge.
	cid1 := randHex(8) + "@" + laddr
	msg := buildRegister(domain, ext, laddr, cid1, randHex(4), "z9hG4bK"+randHex(8), 1, expires, "")
	resp, err := transact(conn, msg, cid1)
	if err != nil {
		return fail("round1: %v", err)
	}
	line1 := statusLine(resp)
	fmt.Println("round1:", line1)
	if !strings.Contains(line1, " 401 ") {
		fmt.Println("FINAL:", line1)
		if strings.Contains(line1, " 200 ") {
			return 0
		}
		return 1
	}

	// Build the Authorization header from the challenge parameters.
	p := parseAuthParams(headerValue(resp, "WWW-Authenticate"))
	realm, nonce, qop := p["realm"], p["nonce"], p["qop"]
	if realm == "" || nonce == "" {
		return fail("round1: malformed challenge %q", headerValue(resp, "WWW-Authenticate"))
	}
	if learnDomain {
		domain = realm
	}
	uri := "sip:" + domain
	auth := fmt.Sprintf(`Digest username=%q, realm=%q, nonce=%q, uri=%q, algorithm=MD5`, ext, realm, nonce, uri)
	if qop != "" {
		cnonce := randHex(8)
		auth += fmt.Sprintf(`, response=%q, cnonce=%q, nc=00000001, qop=%s`,
			digestResponse(ext, realm, pass, nonce, uri, "auth", cnonce), cnonce, qop)
	} else {
		auth += fmt.Sprintf(`, response=%q`, digestResponse(ext, realm, pass, nonce, uri, "", ""))
	}
	if op := p["opaque"]; op != "" {
		auth += fmt.Sprintf(", opaque=%q", op)
	}

	// Round 2: authenticated REGISTER with a fresh Call-ID.
	cid2 := randHex(8) + "@" + laddr
	msg = buildRegister(domain, ext, laddr, cid2, randHex(4), "z9hG4bK"+randHex(8), 2, expires, auth)
	resp, err = transact(conn, msg, cid2)
	if err != nil {
		return fail("round2: %v", err)
	}
	line2 := statusLine(resp)
	fmt.Println("FINAL:", line2)
	if !strings.Contains(line2, " 200 ") {
		fmt.Println(resp)
		return 1
	}
	fmt.Printf("REGISTER OK: ext=%s domain=%s server=%s expires=%d\n", ext, domain, server, expires)
	return 0
}

func main() {
	server := flag.String("server", "127.0.0.1:5060", "SIP server host:port (UDP)")
	ext := flag.String("ext", "", "extension to register (required)")
	pass := flag.String("pass", "", "SIP password (required)")
	domain := flag.String("domain", "auto", `SIP domain, or "auto" to learn it from the 401 realm`)
	expires := flag.Int("expires", 300, "Expires value in seconds")
	flag.Parse()
	if *ext == "" || *pass == "" {
		flag.Usage()
		os.Exit(2)
	}
	os.Exit(run(*server, *ext, *pass, *domain, *expires))
}

package api

import (
	"bytes"
	"encoding/xml"
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/nie/sip-terminal/server/internal/model"
)

// mod_xml_curl 约定：任何情况回 HTTP 200，业务结果用 XML 表达。
// 响应含认证材料（明文 password），本路由只允许内网暴露，禁止公网代理。
//
// 为什么给明文 password 而不是 a1-hash：internal profile 配了
// force-register-domain=$${domain}（FS 容器 IP）+ challenge-realm=auto_from，
// 客户端实际使用的 realm 跟随其 REGISTER 的 From/To host（如 127.0.0.1），
// 而 a1-hash 只能按固定 domain 预算，realm 一变即失配；
// 明文 password 由 FS 按 MD5(user:realm:pass) 现算，对任意 realm 都成立。
//
// 为什么 key_value 不能优先：auth 查询里 key_value=domain（force-register-domain
// 的取值），真正的分机在 user 字段；若按 key_value 查库必然 not-found，
// FS 转而命中静态目录里的 type="pointer" 占位用户 → 403 "Can't register a pointer"。
const notFoundXML = `<document type="freeswitch/xml">
  <section name="result">
    <result status="not found"/>
  </section>
</document>`

const userXMLTpl = `<document type="freeswitch/xml">
  <section name="directory" description="Dynamic Directory">
    <domain name="%[1]s">
      <params>
        <param name="dial-string" value="{presence_id=${dialed_user}@${dialed_domain}}${sofia_contact(${dialed_user}@${dialed_domain})}"/>
      </params>
      <groups>
        <group name="default">
          <users>
            <user id="%[2]s">
              <params>
                <param name="password" value="%[3]s"/>
              </params>
              <variables>
                <variable name="accountcode" value="%[2]s"/>
                <variable name="user_context" value="default"/>
                <variable name="effective_caller_id_number" value="%[2]s"/>
              </variables>
            </user>
          </users>
        </group>
      </groups>
    </domain>
  </section>
</document>`

// domainXMLTpl 用于纯 domain 查询：由本接口接管该 domain，
// 避免查找落入静态目录（vanilla 目录内含 1000-1014 的 pointer 占位用户）。
const domainXMLTpl = `<document type="freeswitch/xml">
  <section name="directory" description="Dynamic Directory">
    <domain name="%[1]s">
      <params>
        <param name="dial-string" value="{presence_id=${dialed_user}@${dialed_domain}}${sofia_contact(${dialed_user}@${dialed_domain})}"/>
      </params>
      <groups>
        <group name="default">
          <users/>
        </group>
      </groups>
    </domain>
  </section>
</document>`

func xmlEsc(s string) string {
	var b bytes.Buffer
	xml.EscapeText(&b, []byte(s))
	return b.String()
}

func respondXML(c *gin.Context, body string) {
	c.Data(http.StatusOK, "text/xml; charset=utf-8", []byte(body))
}

func (h *Handler) FSWDirectory(c *gin.Context) {
	userField := c.PostForm("user")
	keyValue := c.PostForm("key_value")
	domain := c.PostForm("domain")
	if domain == "" {
		domain = keyValue
	}
	if domain == "" {
		domain = "fs.local"
	}

	// 分机候选：user 优先，key_value 兜底（部分查询路径把分机放在 key_value）。
	for _, ext := range []string{userField, keyValue} {
		if ext == "" {
			continue
		}
		var acc model.SipAccount
		if err := h.ST.DB.Where("extension = ? AND enabled = ?", ext, true).First(&acc).Error; err != nil {
			continue
		}
		// ext 为分配器生成的纯数字，domain 客户端可控故转义；password 为随机
		// base64（无 XML 特殊字符），渲染前仍统一转义以防字段被污染。
		xmlStr := fmt.Sprintf(userXMLTpl, xmlEsc(domain), xmlEsc(acc.Extension), xmlEsc(acc.SipPassword))
		respondXML(c, xmlStr)
		return
	}
	if userField == "" && keyValue != "" {
		respondXML(c, fmt.Sprintf(domainXMLTpl, xmlEsc(domain)))
		return
	}
	respondXML(c, notFoundXML)
}

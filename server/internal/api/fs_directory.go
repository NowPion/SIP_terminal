package api

import (
	"bytes"
	"crypto/md5"
	"encoding/hex"
	"encoding/xml"
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/nie/sip-terminal/server/internal/model"
)

// mod_xml_curl 约定：任何情况回 HTTP 200，业务结果用 XML 表达。
// 响应含认证材料（a1-hash），本路由只允许内网暴露，禁止公网代理。
// 渲染已做注入加固：所有客户端可控字段经 xmlEsc 转义后入模板，
// a1-hash 在原始三元组上重算，转义不影响认证数学。
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
                <param name="a1-hash" value="%[3]s"/>
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

// directoryHA1 计算 FreeSWITCH digest 凭据 HA1 = md5(extension:domain:password)。
func directoryHA1(ext, domain, pass string) string {
	sum := md5.Sum([]byte(ext + ":" + domain + ":" + pass))
	return hex.EncodeToString(sum[:])
}

func xmlEsc(s string) string {
	var b bytes.Buffer
	xml.EscapeText(&b, []byte(s))
	return b.String()
}

func respondXML(c *gin.Context, body string) {
	c.Data(http.StatusOK, "text/xml; charset=utf-8", []byte(body))
}

func (h *Handler) FSWDirectory(c *gin.Context) {
	user := c.PostForm("key_value")
	if user == "" {
		user = c.PostForm("user")
	}
	domain := c.PostForm("domain")
	if domain == "" {
		domain = "fs.local"
	}
	if user == "" {
		respondXML(c, notFoundXML)
		return
	}
	var acc model.SipAccount
	err := h.ST.DB.Where("extension = ? AND enabled = ?", user, true).First(&acc).Error
	if err != nil {
		respondXML(c, notFoundXML)
		return
	}
	// ext 为分配器生成的纯数字；domain 客户端可控故转义；
	// a1-hash 按原始三元组重算，转义不影响认证数学。
	xmlStr := fmt.Sprintf(userXMLTpl,
		xmlEsc(domain),
		xmlEsc(acc.Extension),
		directoryHA1(acc.Extension, domain, acc.SipPassword),
	)
	respondXML(c, xmlStr)
}

package main

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"html/template"
	"net/http"
	"net/url"
	"strings"
	"sync"
)

type Handler struct {
	db        *DB
	cfg       *Config
	templates *template.Template
	sessions  sync.Map
}

func NewHandler(db *DB, cfg *Config) *Handler {
	tmpl := template.Must(template.ParseGlob("templates/*.html"))
	return &Handler{
		db:        db,
		cfg:       cfg,
		templates: tmpl,
	}
}

func (h *Handler) SetupRoutes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/health", h.Health)
	mux.HandleFunc("/login", h.Login)
	mux.HandleFunc("/", h.Auth(h.Index))
	mux.HandleFunc("/doc/", h.Auth(h.Doc))
	mux.HandleFunc("/api/endpoint/", h.Auth(h.EndpointAPI))
	return mux
}

func (h *Handler) Health(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"status":"ok"}`))
}

func (h *Handler) Login(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if r.Method == http.MethodPost {
		password := r.FormValue("password")
		if password == h.cfg.Auth.Password {
			token := generateToken()
			h.sessions.Store(token, true)
			http.SetCookie(w, &http.Cookie{
				Name:  "session",
				Value: token,
				Path:  "/",
			})
			http.Redirect(w, r, "/", http.StatusFound)
			return
		}
		h.templates.ExecuteTemplate(w, "login.html", map[string]string{
			"Error": "密码错误",
		})
		return
	}
	h.templates.ExecuteTemplate(w, "login.html", nil)
}

func (h *Handler) Auth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		cookie, err := r.Cookie("session")
		if err != nil || !h.isValidSession(cookie.Value) {
			http.Redirect(w, r, "/login", http.StatusFound)
			return
		}
		next(w, r)
	}
}

func (h *Handler) isValidSession(token string) bool {
	_, ok := h.sessions.Load(token)
	return ok
}

func (h *Handler) Index(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" && r.URL.Path != "/index.html" {
		http.NotFound(w, r)
		return
	}

	projects, err := h.db.FetchProjects()
	if err != nil {
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	h.templates.ExecuteTemplate(w, "index.html", map[string]interface{}{
		"Projects": projects,
	})
}

func (h *Handler) Doc(w http.ResponseWriter, r *http.Request) {
	projectID := strings.TrimPrefix(r.URL.Path, "/doc/")
	if projectID == "" {
		http.NotFound(w, r)
		return
	}

	// 获取项目名称
	title := h.db.FetchProjectName(projectID)
	if title == "" {
		title = "API 文档"
	}

	// 获取项目下的接口列表
	endpoints, err := h.db.FetchEndpoints(projectID)
	if err != nil {
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	h.templates.ExecuteTemplate(w, "doc-detail.html", map[string]interface{}{
		"Title":      title,
		"ProjectID":  projectID,
		"Endpoints":  endpoints,
	})
}

// EndpointAPI 返回单个接口的 HTML 内容（AJAX）
func (h *Handler) EndpointAPI(w http.ResponseWriter, r *http.Request) {
	endpointID := strings.TrimPrefix(r.URL.Path, "/api/endpoint/")
	if endpointID == "" {
		http.Error(w, "missing id", http.StatusBadRequest)
		return
	}

	endpoint, err := h.db.FetchEndpoint(endpointID)
	if err != nil {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write([]byte(renderEndpointHTML(endpoint)))
}

func renderEndpointHTML(e *Endpoint) string {
	var b strings.Builder

	// 标题行：方法 + 名称
	b.WriteString(`<div class="ep-header">`)
	b.WriteString(`<span class="method-badge method-` + e.Method + `">` + e.Method + `</span>`)
	b.WriteString(`<h2>` + template.HTMLEscapeString(e.Name) + `</h2>`)
	b.WriteString(`</div>`)

	// URL
	b.WriteString(`<div class="ep-url"><code>` + template.HTMLEscapeString(e.URL) + `</code></div>`)

	// 描述
	if e.Description != "" {
		b.WriteString(`<div class="ep-desc"><p>` + template.HTMLEscapeString(e.Description) + `</p></div>`)
	}

	// 请求参数
	if e.QueryText != "" {
		b.WriteString(`<h3>请求参数</h3>`)
		params, _ := url.ParseQuery(e.QueryText)
		if len(params) > 0 {
			b.WriteString(`<div class="table-wrapper"><table>`)
			b.WriteString(`<tr><th>参数名</th><th>值</th></tr>`)
			for k, vals := range params {
				b.WriteString(`<tr><td><code>` + template.HTMLEscapeString(k) + `</code></td><td>` + template.HTMLEscapeString(strings.Join(vals, ", ")) + `</td></tr>`)
			}
			b.WriteString(`</table></div>`)
		} else {
			b.WriteString(`<pre><code>` + template.HTMLEscapeString(e.QueryText) + `</code></pre>`)
		}
	}

	// 请求头
	if e.HeadersText != "" {
		b.WriteString(`<h3>请求头</h3>`)
		hasHeaders := false
		for _, line := range strings.Split(e.HeadersText, "\n") {
			if strings.Contains(line, ":") {
				hasHeaders = true
				break
			}
		}
		if hasHeaders {
			b.WriteString(`<div class="table-wrapper"><table>`)
			b.WriteString(`<tr><th>名称</th><th>值</th></tr>`)
			for _, line := range strings.Split(strings.TrimSpace(e.HeadersText), "\n") {
				line = strings.TrimSpace(line)
				if line == "" {
					continue
				}
				parts := strings.SplitN(line, ":", 2)
				if len(parts) == 2 {
					b.WriteString(`<tr><td><code>` + template.HTMLEscapeString(strings.TrimSpace(parts[0])) + `</code></td><td>` + template.HTMLEscapeString(strings.TrimSpace(parts[1])) + `</td></tr>`)
				}
			}
			b.WriteString(`</table></div>`)
		} else {
			b.WriteString(`<pre><code>` + template.HTMLEscapeString(e.HeadersText) + `</code></pre>`)
		}
	}

	// 请求体
	if e.BodyText != "" {
		b.WriteString(`<h3>请求体</h3>`)
		b.WriteString(`<pre><code>` + template.HTMLEscapeString(e.BodyText) + `</code></pre>`)
	}

	// 响应示例
	if e.ResponseBody != "" {
		b.WriteString(`<h3>响应示例</h3>`)
		if e.ResponseStatusCode > 0 {
			b.WriteString(`<div class="ep-status">状态码: <code>` + http.StatusText(e.ResponseStatusCode) + `</code>`)
			if e.ResponseDuration > 0 {
				b.WriteString(` &nbsp;耗时: <code>`)
				if e.ResponseDuration >= 1000 {
					b.WriteString(strings.TrimRight(strings.TrimRight(
						fmt.Sprintf("%.2f", e.ResponseDuration/1000), "0"), "."))
					b.WriteString("s")
				} else {
					b.WriteString(strings.TrimRight(strings.TrimRight(
						fmt.Sprintf("%.0f", e.ResponseDuration), "0"), "."))
					b.WriteString("ms")
				}
				b.WriteString(`</code>`)
			}
			b.WriteString(`</div>`)
		}
		b.WriteString(`<pre><code>` + template.HTMLEscapeString(e.ResponseBody) + `</code></pre>`)
	}

	// 响应字段
	if e.ResponseFieldsJSON != "" && e.ResponseFieldsJSON != "[]" {
		type fieldInfo struct {
			FieldName   string `json:"fieldName"`
			FieldType   string `json:"fieldType"`
			Description string `json:"description"`
		}
		var fields []fieldInfo
		if json.Unmarshal([]byte(e.ResponseFieldsJSON), &fields) == nil && len(fields) > 0 {
			b.WriteString(`<h3>响应字段</h3>`)
			b.WriteString(`<div class="table-wrapper"><table>`)
			b.WriteString(`<tr><th>字段名</th><th>类型</th><th>说明</th></tr>`)
			for _, f := range fields {
				b.WriteString(`<tr>`)
				b.WriteString(`<td><code>` + template.HTMLEscapeString(f.FieldName) + `</code></td>`)
				b.WriteString(`<td>` + template.HTMLEscapeString(f.FieldType) + `</td>`)
				b.WriteString(`<td>` + template.HTMLEscapeString(f.Description) + `</td>`)
				b.WriteString(`</tr>`)
			}
			b.WriteString(`</table></div>`)
		}
	}

	return b.String()
}

func generateToken() string {
	b := make([]byte, 16)
	rand.Read(b)
	return hex.EncodeToString(b)
}


package main

import (
	"crypto/rand"
	"encoding/hex"
	"html/template"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"sync"

	"github.com/gomarkdown/markdown"
	"github.com/gomarkdown/markdown/html"
	"github.com/gomarkdown/markdown/parser"
)

type Handler struct {
	db        *DB
	cfg       *Config
	templates *template.Template
	sessions  sync.Map // token -> true
}

type Section struct {
	ID      string
	Name    string
	Method  string // GET, POST, PUT, DELETE 等
	Content template.HTML
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

	docs, err := h.db.FetchAllDocs()
	if err != nil {
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	data := map[string]interface{}{
		"Docs": docs,
	}
	h.templates.ExecuteTemplate(w, "index.html", data)
}

func (h *Handler) Doc(w http.ResponseWriter, r *http.Request) {
	projectID := strings.TrimPrefix(r.URL.Path, "/doc/")
	if projectID == "" {
		http.NotFound(w, r)
		return
	}

	doc, err := h.db.FetchDoc(projectID)
	if err != nil {
		http.NotFound(w, r)
		return
	}

	// 按 Markdown 源码中的 ## 标题拆分，每个 Section 单独渲染
	sections := splitAndRender(doc.HTMLContent)

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	data := map[string]interface{}{
		"Title":    doc.Title,
		"Sections": sections,
	}
	h.templates.ExecuteTemplate(w, "doc-detail.html", data)
}

func renderMarkdown(md string) string {
	extensions := parser.CommonExtensions | parser.AutoHeadingIDs
	p := parser.NewWithExtensions(extensions)

	htmlFlags := html.CommonFlags | html.HrefTargetBlank
	opts := html.RendererOptions{Flags: htmlFlags}
	renderer := html.NewRenderer(opts)

	htmlStr := string(markdown.ToHTML([]byte(md), p, renderer))
	htmlStr = strings.ReplaceAll(htmlStr, "<table>", `<div class="table-wrapper"><table>`)
	htmlStr = strings.ReplaceAll(htmlStr, "</table>", `</table></div>`)
	// 过滤 Markdown 内容中可能携带的完整 HTML 文档结构
	for _, tag := range []string{"<!DOCTYPE html>", "<!doctype html>", "<html>", "</html>", "<head>", "</head>", "<body>", "</body>"} {
		htmlStr = strings.ReplaceAll(htmlStr, tag, "")
	}
	return htmlStr
}

func splitAndRender(md string) []Section {
	methodRe := regexp.MustCompile(`(?i)^(GET|POST|PUT|DELETE|PATCH|OPTIONS|HEAD)\b`)

	// 方案1: 从 Markdown 源码按 ## 拆分
	mdRe := regexp.MustCompile(`(?m)^##[ \t]*(.+)$`)
	mdLocs := mdRe.FindAllStringIndex(md, -1)
	if len(mdLocs) > 0 {
		return buildSections(md, mdLocs, mdRe, methodRe, true)
	}

	// 方案2: 先渲染为 HTML，再从 HTML 中按 <h2> 拆分
	htmlContent := renderMarkdown(md)
	htmlRe := regexp.MustCompile(`(?s)<h2[^>]*>(.*?)</h2>`)
	htmlLocs := htmlRe.FindAllStringIndex(htmlContent, -1)
	if len(htmlLocs) > 0 {
		return buildSectionsFromHTML(htmlContent, htmlLocs, htmlRe, methodRe)
	}

	// 没有标题，整页作为一个 section
	return []Section{{ID: "section-0", Name: "", Content: template.HTML(htmlContent)}}
}

func buildSections(md string, locs [][]int, re *regexp.Regexp, methodRe *regexp.Regexp, render bool) []Section {
	var sections []Section

	if locs[0][0] > 0 {
		intro := strings.TrimSpace(md[:locs[0][0]])
		if intro != "" {
			content := template.HTML(intro)
			if render {
				content = template.HTML(renderMarkdown(intro))
			}
			sections = append(sections, Section{ID: "", Name: "", Content: content})
		}
	}

	for i, loc := range locs {
		start := loc[0]
		var end int
		if i+1 < len(locs) {
			end = locs[i+1][0]
		} else {
			end = len(md)
		}

		chunk := strings.TrimSpace(md[start:end])
		matches := re.FindStringSubmatch(chunk)
		name := ""
		method := ""
		if len(matches) > 1 {
			name = strings.TrimSpace(matches[1])
			if mm := methodRe.FindStringSubmatch(name); len(mm) > 1 {
				method = strings.ToUpper(mm[1])
			}
		}

		content := template.HTML(chunk)
		if render {
			content = template.HTML(renderMarkdown(chunk))
		}
		sections = append(sections, Section{ID: "section-" + strconv.Itoa(i), Name: name, Method: method, Content: content})
	}
	return sections
}

func buildSectionsFromHTML(htmlContent string, locs [][]int, re *regexp.Regexp, methodRe *regexp.Regexp) []Section {
	var sections []Section
	tagRe := regexp.MustCompile(`<[^>]+>`)

	if locs[0][0] > 0 {
		intro := strings.TrimSpace(htmlContent[:locs[0][0]])
		if intro != "" {
			sections = append(sections, Section{ID: "", Name: "", Content: template.HTML(intro)})
		}
	}

	for i, loc := range locs {
		start := loc[0]
		var end int
		if i+1 < len(locs) {
			end = locs[i+1][0]
		} else {
			end = len(htmlContent)
		}

		chunk := strings.TrimSpace(htmlContent[start:end])
		matches := re.FindStringSubmatch(chunk)
		name := ""
		method := ""
		if len(matches) > 1 {
			name = strings.TrimSpace(tagRe.ReplaceAllString(matches[1], ""))
			if mm := methodRe.FindStringSubmatch(name); len(mm) > 1 {
				method = strings.ToUpper(mm[1])
			}
		}
		sections = append(sections, Section{ID: "section-" + strconv.Itoa(i), Name: name, Method: method, Content: template.HTML(chunk)})
	}
	return sections
}

func generateToken() string {
	b := make([]byte, 16)
	rand.Read(b)
	return hex.EncodeToString(b)
}

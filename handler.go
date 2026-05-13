package main

import (
	"crypto/rand"
	"encoding/hex"
	"html/template"
	"net/http"
	"regexp"
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

type NavItem struct {
	ID   string
	Name string
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

	// 渲染 Markdown 为 HTML
	htmlContent := renderMarkdown(doc.HTMLContent)

	// 提取导航
	navItems := extractNav(doc.HTMLContent)

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	data := map[string]interface{}{
		"Title":   doc.Title,
		"Content": template.HTML(htmlContent),
		"Nav":     navItems,
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

func extractNav(md string) []NavItem {
	var items []NavItem
	re := regexp.MustCompile(`^##\s+(.+)$`)

	for _, line := range strings.Split(md, "\n") {
		matches := re.FindStringSubmatch(strings.TrimSpace(line))
		if len(matches) > 1 {
			name := matches[1]
			id := strings.ToLower(name)
			id = strings.ReplaceAll(id, " ", "-")
			id = regexp.MustCompile(`[^a-z0-9-]`).ReplaceAllString(id, "")
			items = append(items, NavItem{ID: id, Name: name})
		}
	}

	return items
}

func generateToken() string {
	b := make([]byte, 16)
	rand.Read(b)
	return hex.EncodeToString(b)
}

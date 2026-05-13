package main

import (
	"database/sql"
	"fmt"

	_ "github.com/go-sql-driver/mysql"
)

type DocRecord struct {
	ID        string
	ProjectID string
	Title     string
}

type Endpoint struct {
	ID                 string
	ProjectID          string
	Name               string
	Method             string
	URL                string
	Description        string
	QueryText          string
	HeadersText        string
	BodyText           string
	ResponseBody       string
	ResponseStatusCode int
	ResponseDuration   float64
}

type DB struct {
	conn *sql.DB
}

func NewDB(cfg *Config) (*DB, error) {
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%d)/%s?charset=utf8mb4&parseTime=true",
		cfg.Database.Username,
		cfg.Database.Password,
		cfg.Database.Host,
		cfg.Database.Port,
		cfg.Database.Database,
	)

	conn, err := sql.Open("mysql", dsn)
	if err != nil {
		return nil, err
	}

	if err := conn.Ping(); err != nil {
		return nil, err
	}

	return &DB{conn: conn}, nil
}

func (db *DB) Close() error {
	return db.conn.Close()
}

// FetchAllDocs 获取所有项目列表
func (db *DB) FetchAllDocs() ([]DocRecord, error) {
	rows, err := db.conn.Query("SELECT id, project_id, title FROM api_documents ORDER BY title")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var docs []DocRecord
	for rows.Next() {
		var doc DocRecord
		if err := rows.Scan(&doc.ID, &doc.ProjectID, &doc.Title); err != nil {
			return nil, err
		}
		docs = append(docs, doc)
	}
	return docs, nil
}

// FetchProjectName 获取项目名称（从 api_documents 表）
func (db *DB) FetchProjectName(projectID string) string {
	var title string
	err := db.conn.QueryRow("SELECT title FROM api_documents WHERE project_id = ? LIMIT 1", projectID).Scan(&title)
	if err != nil {
		return ""
	}
	return title
}

// FetchEndpoints 获取项目下所有接口列表
func (db *DB) FetchEndpoints(projectID string) ([]Endpoint, error) {
	rows, err := db.conn.Query(
		`SELECT id, project_id, name, method, url_string,
		 COALESCE(description,''), COALESCE(query_text,''), COALESCE(headers_text,''),
		 COALESCE(body_text,''), COALESCE(response_body,''),
		 COALESCE(response_status_code,0), COALESCE(response_duration,0)
		 FROM request_documents WHERE project_id = ? ORDER BY created_at`,
		projectID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var endpoints []Endpoint
	for rows.Next() {
		var e Endpoint
		if err := rows.Scan(
			&e.ID, &e.ProjectID, &e.Name, &e.Method, &e.URL,
			&e.Description, &e.QueryText, &e.HeadersText,
			&e.BodyText, &e.ResponseBody,
			&e.ResponseStatusCode, &e.ResponseDuration,
		); err != nil {
			return nil, err
		}
		endpoints = append(endpoints, e)
	}
	return endpoints, nil
}

// FetchEndpoint 获取单个接口详情
func (db *DB) FetchEndpoint(endpointID string) (*Endpoint, error) {
	var e Endpoint
	err := db.conn.QueryRow(
		`SELECT id, project_id, name, method, url_string,
		 COALESCE(description,''), COALESCE(query_text,''), COALESCE(headers_text,''),
		 COALESCE(body_text,''), COALESCE(response_body,''),
		 COALESCE(response_status_code,0), COALESCE(response_duration,0)
		 FROM request_documents WHERE id = ?`,
		endpointID,
	).Scan(
		&e.ID, &e.ProjectID, &e.Name, &e.Method, &e.URL,
		&e.Description, &e.QueryText, &e.HeadersText,
		&e.BodyText, &e.ResponseBody,
		&e.ResponseStatusCode, &e.ResponseDuration,
	)
	if err != nil {
		return nil, err
	}
	return &e, nil
}

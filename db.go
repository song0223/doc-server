package main

import (
	"database/sql"
	"fmt"

	_ "github.com/go-sql-driver/mysql"
)

type DocRecord struct {
	ID          string
	ProjectID   string
	Title       string
	HTMLContent string
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

func (db *DB) FetchAllDocs() ([]DocRecord, error) {
	rows, err := db.conn.Query("SELECT id, project_id, title, html_content FROM api_documents ORDER BY title")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var docs []DocRecord
	for rows.Next() {
		var doc DocRecord
		if err := rows.Scan(&doc.ID, &doc.ProjectID, &doc.Title, &doc.HTMLContent); err != nil {
			return nil, err
		}
		docs = append(docs, doc)
	}
	return docs, nil
}

func (db *DB) FetchDoc(projectID string) (*DocRecord, error) {
	var doc DocRecord
	err := db.conn.QueryRow(
		"SELECT id, project_id, title, html_content FROM api_documents WHERE project_id = ? LIMIT 1",
		projectID,
	).Scan(&doc.ID, &doc.ProjectID, &doc.Title, &doc.HTMLContent)
	if err != nil {
		return nil, err
	}
	return &doc, nil
}

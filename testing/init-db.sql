-- Seed data for the test servers. The official image runs this with psql against POSTGRES_DB
-- (app1), so \connect switches databases.

CREATE ROLE app_owner LOGIN PASSWORD 'ownerpassword';
CREATE DATABASE app2 OWNER app_owner;
CREATE DATABASE app3;
CREATE DATABASE "Mixed-Case";

-- app1: structure-only candidates plus regular data, and an extension.
\connect app1
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE cache_data (id INT PRIMARY KEY, data TEXT);
CREATE TABLE cache_pages (id INT PRIMARY KEY, page_data TEXT);
CREATE TABLE sessions (id INT PRIMARY KEY, session_data TEXT);
CREATE TABLE watchdog (id INT PRIMARY KEY, message TEXT);
CREATE TABLE users (id INT PRIMARY KEY, username VARCHAR(50), email VARCHAR(100), secret BYTEA);
INSERT INTO users VALUES
  (1, 'alice', 'alice@example.com', digest('alice', 'sha256')),
  (2, 'bob', 'bob@example.com', digest('bob', 'sha256'));
INSERT INTO cache_data VALUES (1, 'cached content 1'), (2, 'cached content 2');
INSERT INTO cache_pages VALUES (1, 'page 1');
INSERT INTO sessions VALUES (1, 'session abc'), (2, 'session xyz');
INSERT INTO watchdog VALUES (1, 'log line');

-- app2: owned by a non-superuser role, so restores prove globals and ownership.
\connect app2
SET ROLE app_owner;
CREATE TABLE temp_files (id INT PRIMARY KEY, filename VARCHAR(255));
CREATE TABLE cache (id INT PRIMARY KEY, data TEXT);
CREATE TABLE posts (id INT PRIMARY KEY, title VARCHAR(255), content TEXT);
INSERT INTO posts VALUES (1, 'Hello World', 'This is the first post'), (2, 'Second Post', 'Another post');
INSERT INTO temp_files VALUES (1, 'temp1.txt'), (2, 'temp2.txt');
INSERT INTO cache VALUES (1, 'cached');
RESET ROLE;

-- app3: plain data.
\connect app3
CREATE TABLE products (id INT PRIMARY KEY, name VARCHAR(100), price NUMERIC(10,2));
CREATE TABLE orders (id INT PRIMARY KEY, product_id INT, quantity INT);
INSERT INTO products VALUES (1, 'Widget', 19.99), (2, 'Gadget', 29.99);
INSERT INTO orders VALUES (1, 1, 5), (2, 2, 3);

-- "Mixed-Case": a name that needs quoting everywhere and normalizes to MIXED_CASE.
\connect "Mixed-Case"
CREATE TABLE notes (id INT PRIMARY KEY, body TEXT);
CREATE TABLE "Audit Log" (id INT PRIMARY KEY, entry TEXT);
INSERT INTO notes VALUES (1, 'note one');
INSERT INTO "Audit Log" VALUES (1, 'audit one');

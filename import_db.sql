PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS question_likes;
DROP TABLE IF EXISTS question_follows;
DROP TABLE IF EXISTS replies;
DROP TABLE IF EXISTS questions;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  fname TEXT NOT NULL,
  lname TEXT NOT NULL
);

CREATE TABLE questions (
  id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  author_id INTEGER NOT NULL,

  FOREIGN KEY (author_id) REFERENCES users(id)
);

CREATE TABLE question_follows (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL,
  question_id INTEGER NOT NULL
);

CREATE TABLE replies (
  id INTEGER PRIMARY KEY,
  body TEXT NOT NULL,
  question_id INTEGER NOT NULL,
  parent_reply INTEGER,
  author_id INTEGER NOT NULL,

  FOREIGN KEY (parent_reply) REFERENCES replies(id),
  FOREIGN KEY (question_id) REFERENCES questions(id),
  FOREIGN KEY (author_id) REFERENCES users(id)
);

CREATE TABLE question_likes (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL,
  question_id INTEGER NOT NULL,

  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (question_id) REFERENCES questions(id)
);

INSERT INTO
  users (fname, lname)
VALUES
  ('jay', 'choi'),
  ('cam', 'choi'),
  ('hane', 'choi'),
  ('mom', 'choi'),
  ('dad', 'choi');

INSERT INTO
  questions (title, body, author_id)
VALUES
  ('how is the weather?', 'i''d like to know for hiking this weekend', (SELECT id FROM users WHERE fname = 'jay')),
  ('endgame', 'what did you think?', (SELECT id FROM users WHERE fname = 'hane')),
  ('where are you going?', 'if you are going hiking, i''d like to go too', (SELECT id FROM users WHERE fname = 'cam')),
  ('where are you going?', 'if you are going to costco, i''d like to go too', (SELECT id FROM users WHERE fname = 'cam'));

INSERT INTO
  replies (body, question_id, parent_reply, author_id)
VALUES
  ('it is sunny', (SELECT id FROM questions WHERE title = 'how is the weather?'), NULL, (SELECT id FROM users WHERE fname = 'cam')),
  ('gig harbor', (SELECT id FROM questions WHERE title = 'where are you going?'), NULL, (SELECT id FROM users WHERE fname = 'jay'));

INSERT INTO
  replies (body, question_id, parent_reply, author_id)
VALUES
  ('let''s go on a picnic', (SELECT id FROM questions WHERE title = 'how is the weather?'), (SELECT id FROM replies WHERE body = 'it is sunny'), (SELECT id FROM users WHERE fname = 'jay'));

INSERT INTO
  replies (body, question_id, parent_reply, author_id)
VALUES
  ('sounds good!', (SELECT id FROM questions WHERE title = 'how is the weather?'), (SELECT id FROM replies WHERE body = 'let''s go on a picnic'), (SELECT id FROM users WHERE fname = 'cam'));

INSERT INTO
  question_follows (user_id, question_id)
VALUES
  (1, 1),
  (2, 1),
  (3, 1),
  (4, 2),
  (3, 2),
  (1, 3);

INSERT INTO
  question_likes (user_id, question_id)
VALUES
  (1, 1),
  (2, 1),
  (3, 1),
  (4, 2),
  (3, 2),
  (1, 3);

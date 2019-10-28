require 'sqlite3'
require 'singleton'
require 'active_support/inflector'

class QuestionDBConnection < SQLite3::Database
  include Singleton

  def initialize
    super('questions.db')
    self.type_translation = true
    self.results_as_hash = true
  end
end

class ModelBase
  def self.table
    self.to_s.tableize
  end

  def self.find_by_id(id)
    object = QuestionDBConnection.instance.execute(<<-SQL, id)
      SELECT
        *
      FROM
        #{table}
      WHERE
        id = ?
    SQL
    return nil unless object.length > 0

    self.new(object.first)
  end

  def self.all
    object = QuestionDBConnection.instance.execute("SELECT * FROM #{table}")
    object.map { |datum| self.new(datum) }
  end

  def save
    if self.id
      self.update
    else
      self.create
    end
  end

  def create
    raise "#{self} already in database" if @id

    instance_variables = self.instance_variables

    QuestionDBConnection.instance.execute(<<-SQL, @fname, @lname)
      INSERT INTO 
        #{table} (fname, lname)
      VALUES
        (?, ?)
    SQL
    @id = QuestionDBConnection.instance.last_insert_row_id
  end

  def update
    raise "#{self} not in database" unless @id
    QuestionDBConnection.instance.execute(<<-SQL, @fname, @lname, @id)
      UPDATE
        users 
      SET
        fname = ?, lname = ?
      WHERE
        id = ?
    SQL
  end

end

class User < ModelBase
  attr_accessor :id, :fname, :lname

  def initialize(options)
    @id = options['id']
    @fname = options['fname']
    @lname = options['lname']
  end

  def self.find_by_name(fname, lname)
    user = QuestionDBConnection.instance.execute(<<-SQL, fname, lname)
      SELECT
        *
      FROM
        users
      WHERE
        fname = ? AND lname = ?
    SQL
    return nil unless user.length > 0

    User.new(user.first)
  end

  def authored_questions
    raise "#{self} not found in DB" unless self.id
    questions = Question.find_by_author_id(self.id)
  end

  def authored_replies
    raise "#{self} not found in DB" unless self.id
    replies = Reply.find_by_author_id(self.id)
  end

  def followed_questions
    questions = QuestionFollow.followed_questions_for_user_id(self.id)
  end

  def liked_questions
    questions = QuestionLike.liked_questions_for_user_id(self.id)
  end

  def average_karma
    
    numbers = QuestionDBConnection.instance.execute(<<-SQL, self.id)
      SELECT
        CAST(COUNT(question_likes.id) AS FLOAT)/COUNT(DISTINCT(questions.id)) AS 'avg # of likes'
      FROM
        questions
      LEFT OUTER JOIN
        question_likes
      ON
        questions.id = question_likes.question_id
      WHERE
        author_id = ?
      GROUP BY
        author_id
    SQL
    return nil unless numbers.length > 0

    numbers.first.values.first  
  end

end

class Question < ModelBase
  attr_accessor :id, :title, :body, :author_id

  def initialize(options)
    @id = options['id']
    @title = options['title']
    @body = options['body']
    @author_id = options['author_id']
  end

  def save
    if self.id
      self.update
    else
      self.create
    end
  end

  def create
    raise "#{self} already in database" if @id
    QuestionDBConnection.instance.execute(<<-SQL, @title, @body, @author_id)
      INSERT INTO
        questions (title, body, author_id)
      VALUES
        (?, ?, ?)
    SQL
    @id = QuestionDBConnection.instance.last_insert_row_id
  end

  def update
    raise "#{self} not in database" unless @id
    QuestionDBConnection.instance.execute(<<-SQL, @title, @body, @author_id, @id)
      UPDATE
        questions
      SET
        title = ?, body = ?, author_id = ?
      WHERE
        id = ?
    SQL
  end

  def self.find_by_author_id(author_id)
    user = User.find_by_id(author_id)
    raise "Author ID ##{author_id} not found in DB" unless user

    questions = QuestionDBConnection.instance.execute(<<-SQL, author_id)
      SELECT 
        *
      FROM
        questions
      WHERE
        author_id = ?
    SQL

    questions.map { |question| Question.new(question) }
  end

  def author
    "#{self} not found in DB" unless self.id
    author = User.find_by_id(self.author_id)
  end

  def replies
    "#{self} not found in DB" unless self.id
    replies = Reply.find_by_question_id(self.id)
  end

  def followers
    followers = QuestionFollow.followers_for_question_id(self.id)
  end

  def self.most_followed(n)
    questions = QuestionFollow.most_followed_questions(n)
  end

  def likers
    users = QuestionLike.likers_for_question_id(self.id)
  end

  def num_likes
    number = QuestionLike.num_likes_for_question_id(self.id)
  end

  def self.most_liked(n)
    questions = QuestionLike.most_liked_questions(n)
  end
end

class QuestionFollow < ModelBase
  attr_accessor :id, :user_id, :question_id

  def initialize(options)
    @id = options['id']
    @user_id = options['user_id']
    @question_id = options['question_id']
  end

  def self.followers_for_question_id(question_id)
    followers = QuestionDBConnection.instance.execute(<<-SQL, question_id)
      SELECT
        *
      FROM
        users
      JOIN
        question_follows
      ON
        users.id = question_follows.user_id
      JOIN
        questions
      ON
        question_follows.question_id = questions.id
      WHERE
        question_id = ?
    SQL

    followers.map { |follower| User.new(follower) }
  end

  def self.followed_questions_for_user_id(user_id)
    questions = QuestionDBConnection.instance.execute(<<-SQL, user_id)
      SELECT
        *
      FROM
        questions
      JOIN
        question_follows
      ON
        question_follows.question_id = questions.id
      JOIN
        users
      ON
        users.id = question_follows.user_id
      WHERE
        question_follows.user_id = ?
    SQL

    questions.map { |question| Question.new(question) }
  end

  def self.most_followed_questions(n)
    questions = QuestionDBConnection.instance.execute(<<-SQL, n)
      SELECT
        *, COUNT(question_id)
      FROM
        questions
      JOIN
        question_follows
      ON
        question_follows.question_id = questions.id
      JOIN
        users
      ON
        users.id = question_follows.user_id
      GROUP BY
        question_id
      ORDER BY
        COUNT(question_id) DESC
      LIMIT
        ?
    SQL

    questions.map { |question| Question.new(question) }
  end

end

class Reply < ModelBase
  attr_accessor :id, :body, :question_id, :parent_reply, :author_id

  def initialize(options)
    @id = options['id']
    @body = options['body']
    @question_id = options['question_id']
    @parent_reply = options['parent_reply']
    @author_id = options['author_id']
  end

  def save
    if self.id
      self.update
    else
      self.create
    end
  end

  def create
    raise "#{self} already in database" if @id
    QuestionDBConnection.instance.execute(<<-SQL, @body, @question_id, @parent_reply, @author_id)
      INSERT INTO
        replies (body, question_id, parent_reply, author_id)
      VALUES
        (?, ?, ?, ?)
    SQL
    @id = QuestionDBConnection.instance.last_insert_row_id
  end

  def update
    raise "#{self} not in database" unless @id
    QuestionDBConnection.instance.execute(<<-SQL, @body, @question_id, @parent_reply, @author_id, @id)
      UPDATE  
        replies
      SET
        body = ?, question_id = ?, parent_reply = ?, author_id = ?
      WHERE 
        id = ?
    SQL
  end
  
  def self.find_by_author_id(author_id)
    user = User.find_by_id(author_id)
    raise "Author ID ##{author_id} not found in DB" unless user

    replies = QuestionDBConnection.instance.execute(<<-SQL, author_id)
      SELECT
        *
      FROM
        replies
      WHERE
        author_id = ?
    SQL

    replies.map { |reply| Reply.new(reply) }
  end

  def self.find_by_question_id(question_id)
    question = Question.find_by_id(question_id)
    raise "Question ID ##{question_id} not found in DB" unless question

    replies = QuestionDBConnection.instance.execute(<<-SQL, question_id)
      SELECT
        *
      FROM
        replies
      WHERE
        question_id = ?
    SQL
    
    replies.map { |reply| Reply.new(reply) }
  end

  def author
    raise "#{self} not found in DB" unless self.id
    author = User.find_by_id(self.author_id)
  end

  def question
    raise "#{self} not found in DB" unless self.id
    question = Question.find_by_id(self.question_id)
  end

  def parent_reply
    raise "#{self} not found in DB" unless self.id
    parent_reply = Reply.find_by_id(self.parent_reply) 
  end

  def child_replies
    raise "#{self} not found in DB" unless self.id
    child_replies = QuestionDBConnection.instance.execute(<<-SQL, self.id)
      SELECT
        *
      FROM
        replies
      WHERE
        parent_reply = ?
    SQL

    child_replies.map { |child_reply| Reply.new(child_reply)}
  end

end

class QuestionLike < ModelBase
  attr_accessor :id, :user_id, :question_id

  def initialize(options)
    @id = options['id']
    @user_id = options['user_id']
    @question_id = options['question_id']
  end

  def self.likers_for_question_id(question_id)
    question = Question.find_by_id(question_id)
    raise "Question ID ##{question_id} not found in DB" unless question

    users = QuestionDBConnection.instance.execute(<<-SQL, question_id)
      SELECT
        *
      FROM
        users
      JOIN
        question_likes
      ON
        users.id = question_likes.user_id
      JOIN
        questions
      ON
        question_likes.question_id = questions.id
      WHERE
        question_id = ?
    SQL

    users.map { |user| User.new(user) }
  end

  def self.num_likes_for_question_id(question_id)
    question = Question.find_by_id(question_id)
    raise "Question ID ##{question_id} not found in DB" unless question

    number = QuestionDBConnection.instance.execute(<<-SQL, question_id)
      SELECT
        COUNT(*)
      FROM
        users
      JOIN
        question_likes
      ON
        users.id = question_likes.user_id
      JOIN
        questions
      ON
        question_likes.question_id = questions.id
      WHERE
        question_id = ?
    SQL

    number.first.values.first
  end

  def self.liked_questions_for_user_id(user_id)
    user = User.find_by_id(user_id)
    raise "User ID ##{user_id} not found in DB" unless user

    questions = QuestionDBConnection.instance.execute(<<-SQL, user_id)
      SELECT
        *
      FROM
        users
      JOIN
        question_likes
      ON
        users.id = question_likes.user_id
      JOIN
        questions
      ON
        question_likes.question_id = questions.id
      WHERE
        user_id = ?
    SQL
    return nil unless questions.length > 0

    questions.map { |question| Question.new(question) }
  end

  def self.most_liked_questions(n)
    questions = QuestionDBConnection.instance.execute(<<-SQL, n)
      SELECT
        *, COUNT(question_id)
      FROM
        questions
      JOIN
        question_follows
      ON
        question_follows.question_id = questions.id
      JOIN
        users
      ON
        users.id = question_follows.user_id
      GROUP BY
        question_id
      ORDER BY
        COUNT(question_id) DESC
      LIMIT
        ?
    SQL

    questions.map { |question| Question.new(question) }
  end

end
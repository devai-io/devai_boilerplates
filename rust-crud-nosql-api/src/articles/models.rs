use mongodb::bson::DateTime;
use mongodb::bson::oid::ObjectId;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

use crate::environment::rfc3339;
use crate::error::ApiError;

/// One document per article; its comments are embedded in it.
#[derive(Serialize, Deserialize)]
pub struct Article {
    #[serde(rename = "_id")]
    pub id: ObjectId,
    pub title: String,
    pub url: String,
    #[serde(default)]
    pub content: String,
    pub tags: Vec<String>,
    pub in_home: bool,
    #[serde(default)]
    pub comments: Vec<Comment>,
    pub created_at: DateTime,
    pub updated_at: DateTime,
}

impl Article {
    /// An article in listings: everything but the content.
    pub fn summary_json(&self) -> Value {
        json!({
            "id": self.id.to_hex(),
            "title": self.title,
            "url": self.url,
            "tags": self.tags,
            "in_home": self.in_home,
            "created_at": rfc3339(self.created_at),
            "updated_at": rfc3339(self.updated_at),
        })
    }

    pub fn to_json(&self) -> Value {
        let mut article = self.summary_json();
        article["content"] = json!(self.content);
        article
    }
}

#[derive(Serialize, Deserialize)]
pub struct Comment {
    pub id: ObjectId,
    pub author: String,
    pub email: String,
    pub content: String,
    pub created_at: DateTime,
}

impl Comment {
    /// Comments are public, so the commenter's email is stored but never returned.
    pub fn to_json(&self, article_id: ObjectId) -> Value {
        json!({
            "id": self.id.to_hex(),
            "article_id": article_id.to_hex(),
            "author": self.author,
            "content": self.content,
            "created_at": rfc3339(self.created_at),
        })
    }
}

/// Body of `POST /api/articles`; `PUT` adds the `id`.
#[derive(Deserialize)]
pub struct ArticleFields {
    pub title: String,
    pub url: String,
    #[serde(default)]
    pub content: String,
    #[serde(default)]
    pub tags: Vec<String>,
    #[serde(default)]
    pub in_home: bool,
}

impl ArticleFields {
    pub fn validate(&self) -> Result<(), ApiError> {
        if self.title.trim().is_empty() {
            return Err(ApiError::bad_request("title is required"));
        }
        let url_ok = !self.url.is_empty()
            && self.url.len() <= 200
            && self
                .url
                .chars()
                .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '-');
        if !url_ok {
            return Err(ApiError::bad_request("url must be a slug: a-z, 0-9 and -"));
        }
        Ok(())
    }
}

#[derive(Deserialize)]
pub struct ArticleUpdate {
    pub id: ObjectId,
    #[serde(flatten)]
    pub fields: ArticleFields,
}

#[derive(Deserialize)]
pub struct NewComment {
    pub article_id: ObjectId,
    pub author: String,
    pub email: String,
    pub content: String,
}

impl NewComment {
    pub fn validate(&self) -> Result<(), ApiError> {
        if self.author.trim().is_empty() || self.content.trim().is_empty() {
            return Err(ApiError::bad_request("author and content are required"));
        }
        if !self.email.contains('@') {
            return Err(ApiError::bad_request("a valid email is required"));
        }
        Ok(())
    }
}

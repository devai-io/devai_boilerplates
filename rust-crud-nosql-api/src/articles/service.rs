use futures_util::TryStreamExt;
use mongodb::Collection;
use mongodb::bson::oid::ObjectId;
use mongodb::bson::{DateTime, doc, to_bson};
use mongodb::options::ReturnDocument;

use crate::articles::models::{Article, ArticleFields, Comment, NewComment};
use crate::error::{ApiError, conflict_on_duplicate};

const URL_TAKEN: &str = "an article with this url already exists";

pub async fn get_articles(
    articles: &Collection<Article>,
    home_only: bool,
) -> Result<Vec<Article>, ApiError> {
    let filter = if home_only {
        doc! { "in_home": true }
    } else {
        doc! {}
    };
    let cursor = articles
        .find(filter)
        .projection(doc! { "content": 0, "comments": 0 })
        .sort(doc! { "created_at": -1 })
        .await?;
    Ok(cursor.try_collect().await?)
}

pub async fn get_article_by_url(
    articles: &Collection<Article>,
    url: &str,
) -> Result<Option<Article>, ApiError> {
    Ok(articles.find_one(doc! { "url": url }).await?)
}

pub async fn create_article(
    articles: &Collection<Article>,
    fields: &ArticleFields,
) -> Result<Article, ApiError> {
    let now = DateTime::now();
    let article = Article {
        id: ObjectId::new(),
        title: fields.title.trim().to_string(),
        url: fields.url.clone(),
        content: fields.content.clone(),
        tags: fields.tags.clone(),
        in_home: fields.in_home,
        comments: Vec::new(),
        created_at: now,
        updated_at: now,
    };
    articles
        .insert_one(&article)
        .await
        .map_err(conflict_on_duplicate(URL_TAKEN))?;
    Ok(article)
}

pub async fn update_article(
    articles: &Collection<Article>,
    id: ObjectId,
    fields: &ArticleFields,
) -> Result<Option<Article>, ApiError> {
    let update = doc! { "$set": {
        "title": fields.title.trim(),
        "url": &fields.url,
        "content": &fields.content,
        "tags": fields.tags.clone(),
        "in_home": fields.in_home,
        "updated_at": DateTime::now(),
    }};
    articles
        .find_one_and_update(doc! { "_id": id }, update)
        .return_document(ReturnDocument::After)
        .await
        .map_err(conflict_on_duplicate(URL_TAKEN))
}

pub async fn delete_article(
    articles: &Collection<Article>,
    id: ObjectId,
) -> Result<bool, ApiError> {
    let result = articles.delete_one(doc! { "_id": id }).await?;
    Ok(result.deleted_count > 0)
}

/// Flips `in_home` inside MongoDB (an update pipeline), so concurrent toggles
/// cannot lose an update.
pub async fn toggle_home_view(
    articles: &Collection<Article>,
    id: ObjectId,
) -> Result<Option<Article>, ApiError> {
    let flip = vec![doc! { "$set": { "in_home": { "$not": "$in_home" }, "updated_at": "$$NOW" } }];
    Ok(articles
        .find_one_and_update(doc! { "_id": id }, flip)
        .return_document(ReturnDocument::After)
        .await?)
}

pub async fn get_comments(
    articles: &Collection<Article>,
    article_id: ObjectId,
) -> Result<Vec<Comment>, ApiError> {
    let article = articles.find_one(doc! { "_id": article_id }).await?;
    Ok(article.map(|a| a.comments).unwrap_or_default())
}

pub async fn create_comment(
    articles: &Collection<Article>,
    req: &NewComment,
) -> Result<Comment, ApiError> {
    let comment = Comment {
        id: ObjectId::new(),
        author: req.author.trim().to_string(),
        email: req.email.trim().to_string(),
        content: req.content.clone(),
        created_at: DateTime::now(),
    };
    let push = doc! { "$push": { "comments": to_bson(&comment).map_err(ApiError::internal)? } };
    let result = articles
        .update_one(doc! { "_id": req.article_id }, push)
        .await?;
    if result.matched_count == 0 {
        return Err(ApiError::not_found("article not found"));
    }
    Ok(comment)
}

pub async fn delete_comment(
    articles: &Collection<Article>,
    article_id: ObjectId,
    comment_id: ObjectId,
) -> Result<bool, ApiError> {
    let pull = doc! { "$pull": { "comments": { "id": comment_id } } };
    let result = articles
        .update_one(doc! { "_id": article_id }, pull)
        .await?;
    Ok(result.modified_count > 0)
}

use mongodb::bson::oid::ObjectId;
use warp::http::StatusCode;
use warp::{Rejection, Reply};

use crate::articles::models::{Article, ArticleFields, ArticleUpdate, NewComment};
use crate::articles::service;
use crate::auth::models::AuthUser;
use crate::environment::Environment;
use crate::error::ApiError;

fn article_not_found() -> ApiError {
    ApiError::not_found("article not found")
}

pub async fn get_articles_handler(env: Environment) -> Result<impl Reply, Rejection> {
    let articles = service::get_articles(&env.articles, false).await?;
    Ok(warp::reply::json(
        &articles
            .iter()
            .map(Article::summary_json)
            .collect::<Vec<_>>(),
    ))
}

pub async fn get_home_articles_handler(env: Environment) -> Result<impl Reply, Rejection> {
    let articles = service::get_articles(&env.articles, true).await?;
    Ok(warp::reply::json(
        &articles
            .iter()
            .map(Article::summary_json)
            .collect::<Vec<_>>(),
    ))
}

pub async fn get_article_by_url_handler(
    url: String,
    env: Environment,
) -> Result<impl Reply, Rejection> {
    let article = service::get_article_by_url(&env.articles, &url)
        .await?
        .ok_or_else(article_not_found)?;
    Ok(warp::reply::json(&article.to_json()))
}

pub async fn create_article_handler(
    _admin: AuthUser,
    req: ArticleFields,
    env: Environment,
) -> Result<impl Reply, Rejection> {
    req.validate()?;
    let article = service::create_article(&env.articles, &req).await?;
    Ok(warp::reply::with_status(
        warp::reply::json(&article.to_json()),
        StatusCode::CREATED,
    ))
}

pub async fn update_article_handler(
    _admin: AuthUser,
    req: ArticleUpdate,
    env: Environment,
) -> Result<impl Reply, Rejection> {
    req.fields.validate()?;
    let article = service::update_article(&env.articles, req.id, &req.fields)
        .await?
        .ok_or_else(article_not_found)?;
    Ok(warp::reply::json(&article.to_json()))
}

pub async fn delete_article_handler(
    id: ObjectId,
    _admin: AuthUser,
    env: Environment,
) -> Result<impl Reply, Rejection> {
    if !service::delete_article(&env.articles, id).await? {
        return Err(article_not_found().into());
    }
    Ok(StatusCode::NO_CONTENT)
}

pub async fn update_home_view_handler(
    id: ObjectId,
    _admin: AuthUser,
    env: Environment,
) -> Result<impl Reply, Rejection> {
    let article = service::toggle_home_view(&env.articles, id)
        .await?
        .ok_or_else(article_not_found)?;
    Ok(warp::reply::json(&article.to_json()))
}

pub async fn get_comments_handler(
    article_id: ObjectId,
    env: Environment,
) -> Result<impl Reply, Rejection> {
    let comments = service::get_comments(&env.articles, article_id).await?;
    Ok(warp::reply::json(
        &comments
            .iter()
            .map(|c| c.to_json(article_id))
            .collect::<Vec<_>>(),
    ))
}

pub async fn post_comment_handler(
    req: NewComment,
    env: Environment,
) -> Result<impl Reply, Rejection> {
    req.validate()?;
    let comment = service::create_comment(&env.articles, &req).await?;
    Ok(warp::reply::with_status(
        warp::reply::json(&comment.to_json(req.article_id)),
        StatusCode::CREATED,
    ))
}

pub async fn delete_comment_handler(
    article_id: ObjectId,
    comment_id: ObjectId,
    _admin: AuthUser,
    env: Environment,
) -> Result<impl Reply, Rejection> {
    if !service::delete_comment(&env.articles, article_id, comment_id).await? {
        return Err(ApiError::not_found("comment not found").into());
    }
    Ok(StatusCode::NO_CONTENT)
}

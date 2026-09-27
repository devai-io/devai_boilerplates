use futures_util::TryStreamExt;
use mongodb::Collection;
use mongodb::bson::oid::ObjectId;
use mongodb::bson::{DateTime, doc};
use mongodb::options::ReturnDocument;

use crate::auth::Role;
use crate::error::{ApiError, conflict_on_duplicate};
use crate::users::models::{User, UserCreateRequest, UserUpdateRequest};

const EMAIL_TAKEN: &str = "email already registered";

pub async fn get_users(users: &Collection<User>) -> Result<Vec<User>, ApiError> {
    let cursor = users.find(doc! {}).sort(doc! { "created_at": 1 }).await?;
    Ok(cursor.try_collect().await?)
}

pub async fn get_user_by_id(
    users: &Collection<User>,
    id: ObjectId,
) -> Result<Option<User>, ApiError> {
    Ok(users.find_one(doc! { "_id": id }).await?)
}

pub async fn get_user_by_email(
    users: &Collection<User>,
    email: &str,
) -> Result<Option<User>, ApiError> {
    Ok(users.find_one(doc! { "email": email }).await?)
}

pub async fn create_user(
    users: &Collection<User>,
    req: &UserCreateRequest,
    password_hash: String,
    role: Role,
) -> Result<User, ApiError> {
    let now = DateTime::now();
    let user = User {
        id: ObjectId::new(),
        email: req.email.clone(),
        name: req.name.clone(),
        password_hash,
        role,
        created_at: now,
        updated_at: now,
    };
    users
        .insert_one(&user)
        .await
        .map_err(conflict_on_duplicate(EMAIL_TAKEN))?;
    Ok(user)
}

pub async fn update_user(
    users: &Collection<User>,
    req: &UserUpdateRequest,
) -> Result<Option<User>, ApiError> {
    let update = doc! { "$set": {
        "email": &req.email,
        "name": &req.name,
        "role": req.role.as_str(),
        "updated_at": DateTime::now(),
    }};
    users
        .find_one_and_update(doc! { "_id": req.id }, update)
        .return_document(ReturnDocument::After)
        .await
        .map_err(conflict_on_duplicate(EMAIL_TAKEN))
}

pub async fn update_password(
    users: &Collection<User>,
    id: ObjectId,
    password_hash: &str,
) -> Result<(), ApiError> {
    let update = doc! { "$set": { "password_hash": password_hash, "updated_at": DateTime::now() } };
    users.update_one(doc! { "_id": id }, update).await?;
    Ok(())
}

pub async fn delete_user(users: &Collection<User>, id: ObjectId) -> Result<bool, ApiError> {
    let result = users.delete_one(doc! { "_id": id }).await?;
    Ok(result.deleted_count > 0)
}

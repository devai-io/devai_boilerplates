use mongodb::bson::DateTime;
use mongodb::bson::oid::ObjectId;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

use crate::auth::Role;
use crate::environment::rfc3339;
use crate::error::ApiError;

#[derive(Serialize, Deserialize)]
pub struct User {
    #[serde(rename = "_id")]
    pub id: ObjectId,
    pub email: String,
    pub name: String,
    pub password_hash: String,
    pub role: Role,
    pub created_at: DateTime,
    pub updated_at: DateTime,
}

impl User {
    /// What the API returns: never the password hash.
    pub fn to_json(&self) -> Value {
        json!({
            "id": self.id.to_hex(),
            "email": self.email,
            "name": self.name,
            "role": self.role,
            "created_at": rfc3339(self.created_at),
            "updated_at": rfc3339(self.updated_at),
        })
    }
}

#[derive(Deserialize)]
pub struct UserCreateRequest {
    pub email: String,
    pub name: String,
    pub password: String,
    pub role: Option<Role>,
}

impl UserCreateRequest {
    pub fn normalize(&mut self) {
        self.email = self.email.trim().to_lowercase();
        self.name = self.name.trim().to_string();
    }

    pub fn validate(&self) -> Result<(), ApiError> {
        validate_profile(&self.email, &self.name)?;
        validate_password(&self.password)
    }
}

#[derive(Deserialize)]
pub struct UserUpdateRequest {
    pub id: ObjectId,
    pub email: String,
    pub name: String,
    pub role: Role,
}

#[derive(Deserialize)]
pub struct PasswordUpdateRequest {
    pub id: ObjectId,
    pub current_password: Option<String>,
    pub new_password: String,
}

pub fn validate_profile(email: &str, name: &str) -> Result<(), ApiError> {
    if !email.contains('@') || email.len() > 254 {
        return Err(ApiError::bad_request("a valid email is required"));
    }
    if name.is_empty() || name.len() > 150 {
        return Err(ApiError::bad_request("name must be 1-150 characters"));
    }
    Ok(())
}

pub fn validate_password(password: &str) -> Result<(), ApiError> {
    if !(8..=128).contains(&password.len()) {
        return Err(ApiError::bad_request("password must be 8-128 characters"));
    }
    Ok(())
}

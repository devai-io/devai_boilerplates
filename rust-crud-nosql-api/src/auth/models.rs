use mongodb::bson::oid::ObjectId;
use serde::{Deserialize, Serialize};

use crate::auth::Role;
use crate::users::models::User;

/// The caller, as proven by a valid JWT. Injected into authenticated handlers.
#[derive(Clone, Copy, Debug)]
pub struct AuthUser {
    pub id: ObjectId,
    pub role: Role,
}

#[derive(Deserialize)]
pub struct LoginRequest {
    pub email: String,
    pub password: String,
}

#[derive(Serialize)]
pub struct LoginResponse {
    pub id: String,
    pub email: String,
    pub name: String,
    pub role: Role,
    pub access_token: String,
}

impl LoginResponse {
    pub fn new(user: User, access_token: String) -> Self {
        Self {
            id: user.id.to_hex(),
            email: user.email,
            name: user.name,
            role: user.role,
            access_token,
        }
    }
}

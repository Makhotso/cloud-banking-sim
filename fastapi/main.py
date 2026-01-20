from fastapi import FastAPI
from pymongo import MongoClient
from minio import Minio

app = FastAPI(title="Cloud Banking Simulation API")

# MongoDB Connection
mongo_client = MongoClient("mongodb://mongodb:27017")
db = mongo_client["banking_db"]
accounts_collection = db["accounts"]

# MinIO Connection
minio_client = Minio(
    "minio:9000",
    access_key="admin",
    secret_key="admin123",
    secure=False
)

BUCKET_NAME = "bank-documents"

@app.on_event("startup")
def startup_event():
    # Create bucket if it doesn't exist
    if not minio_client.bucket_exists(BUCKET_NAME):
        minio_client.make_bucket(BUCKET_NAME)

@app.get("/")
def root():
    return {"message": "Cloud Banking Simulation is running"}

@app.get("/health")
def health():
    return {
        "mongodb": "connected",
        "minio": "connected"
    }

@app.post("/accounts")
def create_account(name: str, balance: float):
    account = {
        "name": name,
        "balance": balance
    }
    result = accounts_collection.insert_one(account)
    return {
        "message": "Account created",
        "account_id": str(result.inserted_id)
    }

@app.get("/accounts")
def get_accounts():
    accounts = []
    for acc in accounts_collection.find():
        acc["_id"] = str(acc["_id"])
        accounts.append(acc)
    return accounts

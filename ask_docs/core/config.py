import os

PROJECT_NAME = "ask-docs"

QDRANT_URL = os.environ.get("QDRANT_URL", "http://localhost:6333")
COLLECTION_NAME = os.environ.get("COLLECTION_NAME", "documents")
VECTOR_SIZE = 384

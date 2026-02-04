import uuid
from qdrant_client import QdrantClient
from fastembed import TextEmbedding
from core.config import (
    QDRANT_URL,
    COLLECTION_NAME,
    VECTOR_SIZE,
)
def ingest_document(title, text):

    point_id = str(uuid.uuid4())
    client = QdrantClient(url=QDRANT_URL)
    model = TextEmbedding()

    # ---------- Create collection (if not exists) ----------
    if COLLECTION_NAME not in [c.name for c in client.get_collections().collections]:
        client.recreate_collection(
            collection_name=COLLECTION_NAME,
            vectors_config={
                "size": VECTOR_SIZE,
                "distance": "Cosine",
            },
        )

    # ---------- Chunk text ----------
    def chunk_text(text, chunk_size=500):
        return [
            text[i:i + chunk_size]
            for i in range(0, len(text), chunk_size)
        ]

    chunks = chunk_text(text)

    # ---------- Create vectors ----------
    vectors = list(model.embed(chunks))

    # ---------- Upload to Qdrant ----------
    points = []
    for chunk, vector in zip(chunks, vectors):
        id=str(uuid.uuid4())
        points.append({
            "id": point_id,
            "vector": vector.tolist(),
            "payload": {
                "text": chunk,
                "title": title
            }
        })

    client.upsert(
        collection_name=COLLECTION_NAME,
        points=points
    )
    return point_id
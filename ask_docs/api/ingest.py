from flask import Blueprint, request, jsonify
from services.vectore_store import ingest_document

ingest_bp = Blueprint('ingest', __name__)

@ingest_bp.route("/ingest", methods=["POST"])
def ingest():
    data = request.json  # Expect JSON body
    title = data.get("title")
    text = data.get("text")

    # Simple validation
    if not title or not text:
        return jsonify({"error": "Both title and text are required"}), 400

    id = ingest_document(title, text)

    return id

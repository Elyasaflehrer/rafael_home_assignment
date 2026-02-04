from flask import Blueprint, jsonify

health_bp = Blueprint('health', __name__)

@health_bp.route("/health", methods=["GET"])
def health():
    # TODO
    # Check if Qdrant and Ollama up
    return jsonify({"status": 200}), 200
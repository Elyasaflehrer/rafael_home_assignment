from flask import Blueprint, request, jsonify

query_bp = Blueprint('query', __name__)

@query_bp.route("/query", methods=["POST"])
def query():
    data = request.json  # Expect JSON body
    question = data.get("question")

    if not question:
        return jsonify({"error": "Question is required"}), 400

    # You can process the question here (e.g., search, AI model, etc.)
    print(f"Received question: {question}")  # For now, just print

    return jsonify({"status": "success"})


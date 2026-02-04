from flask import Flask, jsonify
from api.health import health_bp  # import the blueprint
from api.ingest import ingest_bp
from api.query import query_bp

app = Flask(__name__)

# Register blueprint
app.register_blueprint(health_bp)
app.register_blueprint(ingest_bp)
app.register_blueprint(query_bp)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
from flask import Flask, jsonify
from dotenv import load_dotenv


SERVICE_NAME = "war-not-mine-backend"


def create_app() -> Flask:
    load_dotenv()

    app = Flask(__name__)

    @app.get("/health")
    def health():
        return jsonify({"ok": True, "service": SERVICE_NAME})

    return app


app = create_app()


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=True)

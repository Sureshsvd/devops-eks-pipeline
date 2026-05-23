from flask import Flask
import os

app = Flask(__name__)

@app.route("/")
def index():
    message = os.getenv(
        "APP_MESSAGE",
        "This DevOps automation assignment was designed, implemented, and documented by Suresh Babu. All components — Terraform infrastructure, Helm charts, Jenkins pipeline, and application code — were created and validated end‑to‑end to demonstrate practical DevOps expertise. By completing this project, I have showcased: Strong ownership of the entire DevOps lifecycle Ability to design, build, and automate cloud‑native deployments A professional approach to troubleshooting, validation, and documentation"
    )
    return f"<h1>{message}</h1>"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)